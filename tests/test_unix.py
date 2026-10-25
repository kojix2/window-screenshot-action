"""Input and process-lifecycle regression tests; no desktop or third-party modules."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get('BASH_BINARY', '/bin/bash')


class Workspace(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='window screenshot tests ')
        self.addCleanup(self.tmp.cleanup)
        self.cwd = Path(self.tmp.name)
        self.env = dict(os.environ, APP_NAMES='app', OUTPUT_FILES='',
                        OUTPUT_PATTERN='{name}.png', REQUESTED_OS='ubuntu',
                        WINDOW_TIMEOUT='1', CAPTURE_DELAY='0', ACTION_PATH=str(ROOT))
        for name in ('app', 'second', 'upper.EXE', 'literal*', '$(touch_marker)', 'program.png', 'a&b'):
            self.executable(name, '#!/bin/sh\nexit 0\n')

    def executable(self, name, content):
        path = self.cwd / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        path.chmod(0o755)
        return path

    def inputs(self, **changes):
        env = dict(self.env, **changes)
        return subprocess.run([BASH, '-euo', 'pipefail', '-c',
                               'source "$ACTION_PATH/scripts/inputs.sh"; '
                               'printf "%s\\0" "${apps[@]}"; printf "%s\\0" "--outputs--"; '
                               'printf "%s\\0" "${outputs[@]}"'],
                              cwd=self.cwd, env=env, capture_output=True, timeout=10)

    def test_defaults(self):
        result = self.inputs()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(b'\0')[:-1], [b'app', b'--outputs--', b'app.png'])

    def test_whitespace_and_crlf(self):
        result = self.inputs(APP_NAMES=' app\t\r\nsecond\n', OUTPUT_FILES='one.png\r\ntwo.png\t')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(b'\0')[:-1],
                         [b'app', b'second', b'--outputs--', b'one.png', b'two.png'])

    def test_pattern(self):
        result = self.inputs(APP_NAMES='./upper.EXE', OUTPUT_PATTERN='shots/{name}-{os}.png')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'shots/upper-ubuntu.png\0', result.stdout)

    def test_ampersand_in_pattern_replacement(self):
        result = self.inputs(APP_NAMES='a&b')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'a&b.png\0', result.stdout)

    def test_explicit_overrides_pattern(self):
        result = self.inputs(OUTPUT_FILES='x.png', OUTPUT_PATTERN='ignored-{invalid}')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'x.png\0', result.stdout)

    def test_globs_and_shell_syntax_are_literal(self):
        result = self.inputs(APP_NAMES='literal* $(touch_marker)', OUTPUT_FILES='a.png b.png')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'literal*\0$(touch_marker)\0', result.stdout)
        self.assertFalse((self.cwd / 'touch_marker').exists())

    def test_normalizes_aliases(self):
        result = self.inputs(OUTPUT_FILES='./shots//./x.png')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'shots/x.png\0', result.stdout)

    def test_rejects_invalid_inputs(self):
        cases = [
            ({'APP_NAMES': ''}, 'app-names must'),
            ({'APP_NAMES': ' \n\t'}, 'app-names must'),
            ({'APP_NAMES': 'missing'}, 'Executable not'),
            ({'APP_NAMES': 'app second', 'OUTPUT_FILES': 'one.png'}, 'same length'),
            ({'APP_NAMES': 'app app'}, 'Duplicate output'),
            ({'APP_NAMES': 'app second', 'OUTPUT_FILES': 'x.png ./x.png'}, 'Duplicate output'),
            ({'OUTPUT_FILES': '/tmp/x.png'}, 'workspace-relative'),
            ({'OUTPUT_FILES': '../x.png'}, 'Invalid file path'),
            ({'OUTPUT_FILES': 'shots/../x.png'}, 'Invalid file path'),
            ({'OUTPUT_FILES': 'x.jpg'}, '.png extension'),
            ({'OUTPUT_PATTERN': ''}, 'workspace-relative'),
            ({'OUTPUT_PATTERN': '{unknown}.png'}, 'Unknown placeholder'),
            ({'OUTPUT_PATTERN': 'a\nb.png'}, 'control characters'),
            ({'APP_NAMES': 'program.png', 'OUTPUT_FILES': 'program.png'}, 'overwrite'),
            ({'WINDOW_TIMEOUT': '0'}, 'window-timeout'),
            ({'WINDOW_TIMEOUT': '301'}, 'window-timeout'),
            ({'WINDOW_TIMEOUT': '01'}, 'window-timeout'),
            ({'WINDOW_TIMEOUT': '99999999999999999999999999'}, 'window-timeout'),
            ({'CAPTURE_DELAY': '-1'}, 'capture-delay'),
            ({'CAPTURE_DELAY': '0.5'}, 'capture-delay'),
            ({'CAPTURE_DELAY': '61'}, 'capture-delay'),
        ]
        for changes, message in cases:
            with self.subTest(changes=changes):
                result = self.inputs(**changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message.encode(), result.stderr)

    def test_macos_case_collision(self):
        result = self.inputs(REQUESTED_OS='macos', APP_NAMES='app second', OUTPUT_FILES='x.png X.png')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'Duplicate output', result.stderr)

    def test_non_executable(self):
        (self.cwd / 'app').chmod(0o644)
        self.assertNotEqual(self.inputs().returncode, 0)

    def test_output_aliases_executable(self):
        (self.cwd / 'alias.png').symlink_to(self.cwd / 'app')
        result = self.inputs(OUTPUT_FILES='alias.png')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'aliases an executable', result.stderr)

    def test_output_is_directory(self):
        (self.cwd / 'app.png').mkdir()
        self.assertNotEqual(self.inputs().returncode, 0)

    def prepare_capture(self, mode='success', app=None):
        self.executable('app', app or '#!/bin/sh\necho $$ > app.pid\nexec sleep 30\n')
        self.executable('fakebin/wmctrl', '''#!/bin/sh
if [ "$1" = -lp ]; then
  if [ "$FAKE_MODE" = transient ] && [ ! -f wmctrl-retried ]; then
    touch wmctrl-retried
    exit 1
  fi
  if [ "$FAKE_MODE" != timeout ] && [ -f app.pid ]; then
    printf '0x123 0 %s host A window with spaces\n' "$(cat app.pid)"
  fi
fi
''')
        self.executable('fakebin/import', '''#!/bin/sh
if [ "$FAKE_MODE" = failure ]; then exit 9; fi
if [ "$FAKE_MODE" = empty ]; then exit 0; fi
for arg do last=$arg; done
printf 'fresh PNG fixture' > "${last#png:}"
''')
        self.env.update(PATH=str(self.cwd / 'fakebin') + os.pathsep + self.env['PATH'], FAKE_MODE=mode)

    def capture(self):
        return subprocess.run([BASH, str(ROOT / 'scripts/linux.sh'), 'app', 'shots/result.png'],
                              cwd=self.cwd, env=self.env, capture_output=True, timeout=12)

    def assert_stopped(self):
        pid = int((self.cwd / 'app.pid').read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        self.assertEqual(list((self.cwd / 'shots').glob('.window-screenshot.*')), [])

    def test_capture_and_cleanup(self):
        self.prepare_capture()
        result = self.capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'shots/result.png').read_text(), 'fresh PNG fixture')
        self.assert_stopped()

    def test_retries_transient_window_list_failure(self):
        self.prepare_capture('transient')
        result = self.capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cwd / 'wmctrl-retried').exists())
        self.assert_stopped()

    def test_failure_preserves_existing_image_and_cleans_up(self):
        for mode in ('failure', 'empty', 'timeout'):
            with self.subTest(mode=mode):
                self.prepare_capture(mode)
                (self.cwd / 'shots').mkdir(exist_ok=True)
                (self.cwd / 'shots/result.png').write_text('previous PNG')
                result = self.capture()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.cwd / 'shots/result.png').read_text(), 'previous PNG')
                self.assert_stopped()

    def test_exited_application(self):
        self.prepare_capture('timeout', '#!/bin/sh\necho $$ > app.pid\nexit 7\n')
        result = self.capture()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'No window found', result.stderr)
        self.assert_stopped()

    def test_term_resistant_application_is_killed(self):
        self.prepare_capture('success', '#!/bin/sh\ntrap "" TERM\necho $$ > app.pid\nexec sleep 30\n')
        result = self.capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_stopped()

    def test_unix_entrypoint_outputs_and_wm_cleanup(self):
        self.prepare_capture()
        for name in ('Xvfb', 'xauth'):
            self.executable('fakebin/' + name, '#!/bin/sh\nexit 0\n')
        self.executable('fakebin/xvfb-run', '#!/bin/sh\nshift 5\nexec "$@"\n')
        self.executable('fakebin/openbox', '#!/bin/sh\necho $$ > wm.pid\nexec sleep 30\n')
        self.env['GITHUB_OUTPUT'] = str(self.cwd / 'github-output')
        result = subprocess.run([BASH, str(ROOT / 'scripts/run-unix.sh')],
                                cwd=self.cwd, env=self.env, capture_output=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'app.png').read_text(), 'fresh PNG fixture')
        self.assertIn('count=1', (self.cwd / 'github-output').read_text())
        for name in ('app.pid', 'wm.pid'):
            with self.assertRaises(ProcessLookupError):
                os.kill(int((self.cwd / name).read_text()), 0)
        # Failure must not advertise complete outputs or leave the WM running.
        (self.cwd / 'github-output').unlink()
        self.env['FAKE_MODE'] = 'failure'
        result = subprocess.run([BASH, str(ROOT / 'scripts/run-unix.sh')],
                                cwd=self.cwd, env=self.env, capture_output=True, timeout=12)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.cwd / 'github-output').exists())
        for name in ('app.pid', 'wm.pid'):
            with self.assertRaises(ProcessLookupError):
                os.kill(int((self.cwd / name).read_text()), 0)

    def test_macos_shell_capture_and_failure_cleanup(self):
        # Exercise the orchestration only; CoreGraphics is tested on native CI.
        self.executable('app', '#!/bin/sh\necho $$ > app.pid\nexec sleep 30\n')
        helper = self.executable('window-helper', '#!/bin/sh\necho 123\n')
        self.executable('fakebin/screencapture', '#!/bin/sh\nfor arg do last=$arg; done\n[ "$FAKE_MODE" != failure ] || exit 9\nprintf "mac PNG fixture" > "$last"\n')
        self.env.update(PATH=str(self.cwd / 'fakebin') + os.pathsep + self.env['PATH'], FAKE_MODE='success')
        result = subprocess.run([BASH, str(ROOT / 'scripts/macos.sh'), 'app', 'shots/result.png', str(helper)],
                                cwd=self.cwd, env=self.env, capture_output=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'shots/result.png').read_text(), 'mac PNG fixture')
        self.assert_stopped()
        self.env['FAKE_MODE'] = 'failure'
        result = subprocess.run([BASH, str(ROOT / 'scripts/macos.sh'), 'app', 'shots/result.png', str(helper)],
                                cwd=self.cwd, env=self.env, capture_output=True, timeout=12)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.cwd / 'shots/result.png').read_text(), 'mac PNG fixture')
        self.assert_stopped()

    def test_outputs(self):
        output_file = self.cwd / 'github-output'
        env = dict(self.env, GITHUB_OUTPUT=str(output_file))
        result = subprocess.run([BASH, '-euo', 'pipefail', '-c',
                                 'source "$ACTION_PATH/scripts/inputs.sh"; '
                                 'source "$ACTION_PATH/scripts/common.sh"; publish_outputs "${outputs[@]}"'],
                                cwd=self.cwd, env=env, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output_file.read_text(),
                         'files<<WINDOW_SCREENSHOT_FILES\napp.png\nWINDOW_SCREENSHOT_FILES\ncount=1\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
