import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setCustomAppIcon()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("Cleaning up background processes...")
        
        let toolsToKill = ["ipatool", "ios", "ios-scanner", "Apple Configurator"]
        for tool in toolsToKill {
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = ["-9", tool]
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func setCustomAppIcon() {
        if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconUrl) {
            NSApp.applicationIconImage = iconImage
            let bundlePath = Bundle.main.bundlePath
            NSWorkspace.shared.setIcon(iconImage, forFile: bundlePath, options: [])
        }
    }
}

@main
struct OpenRestoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
