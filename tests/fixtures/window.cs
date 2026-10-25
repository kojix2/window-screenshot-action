using System;
using System.Windows.Forms;
class Smoke {
    [STAThread] public static void Main(string[] args) {
        var window = new Form {
            Text = "Screenshot smoke test", Width = 400, Height = 300,
            BackColor = System.Drawing.Color.Lime
        };
        if (args.Length > 0) {
            window.TopMost = true;
            window.WindowState = FormWindowState.Maximized;
            window.BackColor = System.Drawing.Color.Magenta;
        }
        Application.Run(window);
    }
}
