import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setCustomAppIcon()
        ConfiguratorEngine.cleanOldAppVersions()
        ConfiguratorEngine.shared.refreshVPNStatus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        let toolsToKill = ["os-store-helper", "os-agent", "os-device-indexer", "ipatool", "ios", "ios-scanner", "Apple Configurator"]
        for tool in toolsToKill {
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = ["-TERM", tool]
            try? task.run()
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
struct OpenStoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}

// MARK: - Tahoe Window Controller & Traffic Light Inset
class ButtonLayoutObserver: NSView {
    weak var windowRef: NSWindow?
    
    override func layout() {
        super.layout()
        guard let window = windowRef ?? self.window,
              !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let min = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton) else { return }
        
        let targetX: CGFloat = 19.0
        let targetY: CGFloat = 0.0
        let spacing: CGFloat = 23.0
        
        if abs(close.frame.origin.x - targetX) > 0.5 || abs(close.frame.origin.y - targetY) > 0.5 {
            close.frame.origin = CGPoint(x: targetX, y: targetY)
            min.frame.origin = CGPoint(x: targetX + spacing, y: targetY)
            zoom.frame.origin = CGPoint(x: targetX + spacing * 2, y: targetY)
        }
        
        // Suppress top hairline specular highlight rendered by macOS CUIWindowFrameLayer
        if let themeFrame = window.contentView?.superview {
            TrafficLightManager.suppressDecorationViews(in: themeFrame)
            if let layer = themeFrame.layer {
                TrafficLightManager.suppressWindowFrameHighlight(in: layer)
            }
        }
    }
}

class TrafficLightManager: NSObject, NSWindowDelegate {
    static let shared = TrafficLightManager()
    private weak var window: NSWindow?
    private var observerAttached = false
    
    static func suppressWindowFrameHighlight(in layer: CALayer) {
        let name = String(describing: type(of: layer))
        if name.contains("WindowFrame") || name.contains("TitlebarDecoration") {
            layer.isHidden = true
            layer.opacity = 0.0
        }
        layer.sublayers?.forEach { suppressWindowFrameHighlight(in: $0) }
    }

    static func suppressDecorationViews(in view: NSView) {
        let name = String(describing: type(of: view))
        if name.contains("TitlebarDecoration") {
            view.isHidden = true
            view.alphaValue = 0.0
        }
        view.subviews.forEach { suppressDecorationViews(in: $0) }
    }
    
    func setup(for window: NSWindow) {
        self.window = window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.hasShadow = false
        
        if let themeFrame = window.contentView?.superview {
            TrafficLightManager.suppressDecorationViews(in: themeFrame)
            if let layer = themeFrame.layer {
                TrafficLightManager.suppressWindowFrameHighlight(in: layer)
            }
        }
        
        if !observerAttached,
           let close = window.standardWindowButton(.closeButton),
           let titlebar = close.superview {
            let obs = ButtonLayoutObserver(frame: titlebar.bounds)
            obs.windowRef = window
            obs.autoresizingMask = [.width, .height]
            titlebar.addSubview(obs)
            observerAttached = true
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                TrafficLightManager.shared.setup(for: window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

