import Cocoa
import ApplicationServices

let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.configurator.ui")
guard let configApp = apps.first else {
    print("Apple Configurator is not running")
    exit(0)
}

let pid = configApp.processIdentifier
let appElem = AXUIElementCreateApplication(pid)

var windowsRef: CFTypeRef?
let res = AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsRef)
if res == .success, let windows = windowsRef as? [AXUIElement] {
    print("Found \(windows.count) windows via AXUIElement directly!")
    for w in windows {
        var titleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRef)
        print(" Window title:", titleRef as? String ?? "no title")
    }
} else {
    print("AXUIElement error:", res.rawValue)
}
