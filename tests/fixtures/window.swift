import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "Screenshot smoke test"
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
