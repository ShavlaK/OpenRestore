import Foundation
import AppKit
import SQLite3

public final class StandaloneToolchain: @unchecked Sendable {
    public static let shared = StandaloneToolchain()

    public let appSupportDir: String
    public let binDir: String

    public var iosBinaryPath: String {
        bestBinaryPath(named: "ios")
    }

    public var ipatoolBinaryPath: String {
        bestBinaryPath(named: "ipatool")
    }

    public var iosScannerBinaryPath: String {
        bestBinaryPath(named: "ios-scanner")
    }

    public init() {
        let home = NSHomeDirectory()
        let newAppSupport = "\(home)/Library/Application Support/Open Store"
        let oldAppSupport = "\(home)/Library/Application Support/OpenRestore"
        if !FileManager.default.fileExists(atPath: newAppSupport) && FileManager.default.fileExists(atPath: oldAppSupport) {
            try? FileManager.default.moveItem(atPath: oldAppSupport, toPath: newAppSupport)
        }
        self.appSupportDir = FileManager.default.fileExists(atPath: newAppSupport) ? newAppSupport : (FileManager.default.fileExists(atPath: oldAppSupport) ? oldAppSupport : newAppSupport)
        self.binDir = "\(appSupportDir)/bin"
        ensureBinariesExist()
    }

    private func bestBinaryPath(named name: String) -> String {
        // 1. Prioritize binary bundled directly in the App Bundle Resources
        if let resPath = Bundle.main.resourcePath {
            let bundlePath = "\(resPath)/bin/\(name)"
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        let appContentsPath = "\(Bundle.main.bundlePath)/Contents/Resources/bin/\(name)"
        if FileManager.default.isExecutableFile(atPath: appContentsPath) {
            return appContentsPath
        }

        // 2. Fallback to Application Support bin directory
        let appSupportPath = "\(binDir)/\(name)"
        if FileManager.default.isExecutableFile(atPath: appSupportPath) {
            return appSupportPath
        }

        return appSupportPath
    }

    public func ensureBinariesExist() {
        try? FileManager.default.createDirectory(atPath: binDir, withIntermediateDirectories: true)

        let candidateDirs = [
            "\(Bundle.main.resourcePath ?? "")/bin",
            "\(Bundle.main.bundlePath)/Contents/Resources/bin"
        ]

        let binaries = ["ios", "ipatool", "ios-scanner"]

        for name in binaries {
            let destPath = "\(binDir)/\(name)"
            for dir in candidateDirs {
                let srcPath = "\(dir)/\(name)"
                if FileManager.default.fileExists(atPath: srcPath) {
                    let srcSize = (try? FileManager.default.attributesOfItem(atPath: srcPath)[.size] as? Int64) ?? 0
                    let destSize = (try? FileManager.default.attributesOfItem(atPath: destPath)[.size] as? Int64) ?? 0

                    if !FileManager.default.fileExists(atPath: destPath) || srcSize != destSize {
                        try? FileManager.default.removeItem(atPath: destPath)
                        try? FileManager.default.copyItem(atPath: srcPath, toPath: destPath)
                    }
                    break
                }
            }
            if FileManager.default.fileExists(atPath: destPath) {
                chmod(destPath, 0o755)
                // Clear any Gatekeeper quarantine attributes on extracted helper tools
                let xattrProc = Process()
                xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProc.arguments = ["-cr", destPath]
                try? xattrProc.run()
                xattrProc.waitUntilExit()
            }
        }
    }
}

public enum DeviceConnectionType: String, Codable, Sendable, CaseIterable {
    case usb = "USB"
    case wifi = "Wi-Fi"
    case offline = "Отключено"

    public var icon: String {
        switch self {
        case .usb: return "cable.connector.horizontal"
        case .wifi: return "wifi"
        case .offline: return "icloud.slash"
        }
    }
}

public struct DeviceInfo: Identifiable, Hashable, Sendable, Codable {
    public var id: String { udid.isEmpty ? (serialNumber.isEmpty ? name : serialNumber) : udid }
    public var name: String
    public var ownerName: String
    public var modelIdentifier: String
    public var marketingName: String
    public var iosVersion: String
    public var diskCapacity: String
    public var battery: String
    public var udid: String
    public var ecid: String
    public var serialNumber: String
    public var wifiAddress: String
    public var connectionType: DeviceConnectionType
    public var isOnline: Bool
    public var lastSeen: Date

    public init(
        name: String,
        ownerName: String = "",
        modelIdentifier: String,
        marketingName: String,
        iosVersion: String,
        diskCapacity: String = "",
        battery: String = "",
        udid: String = "",
        ecid: String = "",
        serialNumber: String = "",
        wifiAddress: String = "",
        connectionType: DeviceConnectionType = .usb,
        isOnline: Bool = true,
        lastSeen: Date = Date()
    ) {
        self.name = name
        self.ownerName = ownerName.isEmpty ? ConfiguratorEngine.extractOwnerName(from: name) : ownerName
        self.modelIdentifier = modelIdentifier
        self.marketingName = marketingName
        self.iosVersion = iosVersion
        self.diskCapacity = diskCapacity
        self.battery = battery
        self.udid = udid
        self.ecid = ecid
        self.serialNumber = serialNumber
        self.wifiAddress = wifiAddress
        self.connectionType = connectionType
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
}

public struct AppItem: Identifiable, Codable, Hashable {
    public var id: Int64 { adam_id }
    public let name: String
    public let bundle_id: String
    public let bundle_ids: [String]?
    public let adam_id: Int64
    public let category: String
    public let description: String
}

public struct PurchasedApp: Identifiable, Hashable, Sendable, Codable {
    public var id: Int64 { adamId }
    public let adamId: Int64
    public let name: String
    public let bundleId: String
    public let artworkUrl: String?
    public let versionId: Int64
    public let purchaseDate: Date?
    public let ownerDsid: String
}

public struct DeviceInstalledApp: Identifiable, Hashable, Sendable {
    public var id: String { bundleId }
    public let name: String
    public let displayName: String
    public let bundleId: String
    public let bundleVersion: String
    public var adamId: Int64?
    public var artworkUrl: String?
}

public struct IPAResult: Sendable {
    public let path: String
    public let appName: String
    public let bundleId: String
    public let version: String
    public let sha256: String
    public let size: Int64
    public let hasFairPlay: Bool
}

public struct AppUpdateInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let version: String
    public let title: String
    public let releaseNotes: String
    public let downloadUrl: String?
    public let publishedAt: String
    public let isNewer: Bool

    public init(id: String, version: String, title: String, releaseNotes: String, downloadUrl: String?, publishedAt: String, isNewer: Bool) {
        self.id = id
        self.version = version
        self.title = title
        self.releaseNotes = releaseNotes
        self.downloadUrl = downloadUrl
        self.publishedAt = publishedAt
        self.isNewer = isNewer
    }
}

// MARK: - Centralized Log Manager for Diagnostics & Debugging
public final class LogManager: ObservableObject, @unchecked Sendable {
    public static let shared = LogManager()

    @Published public var recentLogs: [String] = []

    private let queue = DispatchQueue(label: "com.openstore.logmanager", qos: .utility)
    private let maxMemoryLogs = 400

    public var logFilePath: String {
        let dir = ConfiguratorEngine.libraryDir
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        return "\(dir)/openstore.log"
    }

    public init() {
        writeSessionBanner()
    }

    private func writeSessionBanner() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        #if arch(arm64)
        let archName = "Apple Silicon (arm64)"
        #else
        let archName = "Intel (x86_64)"
        #endif
        let banner = "\n======================================================\n" +
                     "  Open Store Diagnostics Log — Session: \(df.string(from: Date()))\n" +
                     "  macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString) [\(archName)]\n" +
                     "======================================================\n"
        queue.async {
            self.appendToFile(banner)
        }
    }

    public func log(_ message: String, level: String = "INFO") {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = df.string(from: Date())

        let shortDf = DateFormatter()
        shortDf.dateFormat = "HH:mm:ss"
        let shortTime = shortDf.string(from: Date())

        let fileEntry = "[\(timestamp)] [\(level)] \(message)\n"
        let memoryEntry = "[\(shortTime)] \(message)"

        DispatchQueue.main.async {
            self.recentLogs.append(memoryEntry)
            if self.recentLogs.count > self.maxMemoryLogs {
                self.recentLogs.removeFirst(self.recentLogs.count - self.maxMemoryLogs)
            }
        }

        queue.async {
            self.appendToFile(fileEntry)
        }
    }

    private func appendToFile(_ text: String) {
        let path = self.logFilePath
        guard let data = text.data(using: .utf8) else { return }

        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    public func getFullLog() -> String {
        if let content = try? String(contentsOfFile: logFilePath, encoding: .utf8) {
            return content
        }
        return recentLogs.joined(separator: "\n")
    }

    public func clearLog() {
        DispatchQueue.main.async {
            self.recentLogs.removeAll()
        }
        queue.async {
            try? "".write(toFile: self.logFilePath, atomically: true, encoding: .utf8)
            self.writeSessionBanner()
        }
        log("Лог успешно очищен пользователем", level: "SYSTEM")
    }

    public func copyLogToClipboard() -> Bool {
        let full = getFullLog()
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(full, forType: .string)
    }
}

public final class ConfiguratorEngine: ObservableObject, @unchecked Sendable {
    public static let shared = ConfiguratorEngine()

    public static let defaultDBPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/com.apple.configurator.purchases.cache/store.sqlite"
    }()

    public static let cfgutilPath = "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil"
    public static let workDir = Bundle.main.resourcePath ?? "/tmp"
    public static let libraryDir: String = {
        let home = NSHomeDirectory()
        let newDir = "\(home)/Downloads/Open Store"
        let oldDir = "\(home)/Downloads/OpenRestore"
        if !FileManager.default.fileExists(atPath: newDir) && FileManager.default.fileExists(atPath: oldDir) {
            try? FileManager.default.moveItem(atPath: oldDir, toPath: newDir)
        }
        return FileManager.default.fileExists(atPath: newDir) ? newDir : (FileManager.default.fileExists(atPath: oldDir) ? oldDir : newDir)
    }()

    public static let userMappingsPath: String = {
        return "\(libraryDir)/adam_mappings.json"
    }()

    public static let purchasesCachePath: String = {
        return "\(libraryDir)/purchases_cache.json"
    }()

    // Known Russian/Delisted/Sanctioned apps removed from App Store
    public static let delistedAdamIds: Set<Int64> = [
        492224193,  // СберБанк (СБОЛ)
        468663497,  // Т-Банк (Тинькофф)
        369397980,  // Альфа-Банк
        413284506,  // ВТБ Онлайн
        646258329,  // Промсвязьбанк (ПСБ)
        501939103,  // Открытие
        4933992694, // Газпромбанк
        460307228,  // Райффайзенбанк
        564177498,  // ВКонтакте
        481627348,  // 2ГИС
        417281773,  // Авито
        1206364806, // Совкомбанк (Халва)
        6750455334, // Финграм (клиент Совкомбанк)
        1439243764, // Мегамаркет
        1629869891, // Ozon Банк
        1634422317, // Яндекс Пэй
        1467701468, // Au (Альфа)
        6778332772, // AirT (Т-Банк)
        594913976,  // Wildberries
        1447012971, // Самокат
        1154436683  // Золотое Яблоко
    ]

    public static func isDelistedFromAppStore(adamId: Int64, bundleId: String = "") -> Bool {
        if delistedAdamIds.contains(adamId) { return true }
        let b = bundleId.lowercased()
        if b.contains("sber") || b.contains("tcsbank") || b.contains("tinkoff") ||
           b.contains("alfabank") || b.contains("vtb") || b.contains("psbank") ||
           b.contains("sovcom") || b.contains("open.client") || b.contains("gazprom") ||
           b.contains("2gis") || b.contains("sbol") {
            return true
        }
        return false
    }

    public static let knownDevicesPath: String = {
        return "\(libraryDir)/known_devices.json"
    }()

    private let coreDataEpochDiff: Double = 978307200.0 // Seconds between 1970 and 2001

    @Published public var connectedDevices: [DeviceInfo] = []
    @Published public var knownDevices: [DeviceInfo] = []
    @Published public var selectedDeviceId: String = ""
    @Published public var userManuallySelectedDeviceId: String? = UserDefaults.standard.string(forKey: "userManuallySelectedDeviceId") {
        didSet {
            if let val = userManuallySelectedDeviceId {
                UserDefaults.standard.set(val, forKey: "userManuallySelectedDeviceId")
            } else {
                UserDefaults.standard.removeObject(forKey: "userManuallySelectedDeviceId")
            }
        }
    }

    public var activeDevice: DeviceInfo? {
        if !selectedDeviceId.isEmpty {
            if let d = connectedDevices.first(where: { $0.id == selectedDeviceId }) {
                return d
            }
            if let d = knownDevices.first(where: { $0.id == selectedDeviceId }) {
                return d
            }
        }
        return connectedDevices.first(where: { $0.connectionType == .usb }) ?? connectedDevices.first ?? knownDevices.first
    }

    @Published public var purchasedApps: [PurchasedApp] = []
    @Published public var isLoadingPurchasedApps: Bool = false
    @Published public var totalPurchasedAppsCount: Int = 0
    private var isRefreshingPurchasesInProgress = false
    private var isRefreshingDevicesInProgress = false
    @Published public var oldDeviceApps: [DeviceInstalledApp] = []
    @Published public var currentAccountDsid: String = ""
    @Published public var isRunning: Bool = false
    @Published public var isScanningApps: Bool = false
    @Published public var currentStatus: String = "Готов к работе"
    @Published public var progressLogs: [String] = []

    // Apple ID Account & Auto-Signing State
    @Published public var activeAppleIdEmail: String = ""
    @Published public var activeAppleIdName: String = ""
    @Published public var isAppleIdAuthenticated: Bool = false
    @Published public var isDirectAppleIdAuthenticated: Bool = false
    @Published public var autoSignWithAppleId: Bool = true

    // Permissions State
    @Published public var isAccessibilityGranted: Bool = false
    @Published public var isAutomationGranted: Bool = false

    // Update Checker & Self Updater State
    @Published public var latestUpdateInfo: AppUpdateInfo? = nil
    @Published public var isCheckingUpdates: Bool = false
    @Published public var updateCheckError: String? = nil
    @Published public var isUpdatingApp: Bool = false
    @Published public var updateDownloadProgress: Double = 0.0
    @Published public var updateStatusStage: String = ""

    // Live Progress Tracking
    @Published public var operationProgress: Double = 0.0
    @Published public var operationStage: String = ""
    @Published public var downloadedSizeMB: Double = 0.0

    private var devicePollTimer: Timer?

    public init() {
        LogManager.shared.log("Open Store Engine инициализирован. Библиотека: \(Self.libraryDir)", level: "INIT")
        cleanAllRestoreRequests()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshAppleIdStatus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.refreshDevices()
            self.startDevicePolling()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.refreshPurchasedApps()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            let autoCheck = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true
            if autoCheck {
                Task {
                    _ = await self.checkForUpdates()
                }
            }
        }
    }

    deinit {
        devicePollTimer?.invalidate()
    }

    public func startDevicePolling() {
        DispatchQueue.main.async {
            self.devicePollTimer?.invalidate()
            self.devicePollTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.refreshDevices()
            }
        }
    }

    public func appendLog(_ message: String, level: String = "INFO") {
        LogManager.shared.log(message, level: level)
        DispatchQueue.main.async {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            let timeStr = df.string(from: Date())
            self.progressLogs.append("[\(timeStr)] \(message)")
            self.currentStatus = message
        }
    }

    public func checkAllPermissions() {
        // --- Accessibility (AX) ---
        // AXIsProcessTrustedWithOptions is reliable and fast. It reflects the
        // CURRENT binary's trust status in TCC immediately.
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let axGranted = AXIsProcessTrustedWithOptions(options)

        // --- Automation ---
        // Strategy: check UserDefaults cache first (persists across rebuilds by bundle ID key).
        // Only run NSAppleScript if the cache says NOT granted.
        // Once granted and cached, don't re-check to avoid spamming Apple Events.
        let cacheKey = "automationGrantedV2"
        var autoGranted = UserDefaults.standard.bool(forKey: cacheKey)

        if !autoGranted {
            // Try a quick Apple Events probe. This will trigger the system prompt
            // if first time, or return an error if denied.
            let script = NSAppleScript(source: "tell application \"System Events\" to get name")
            var errInfo: NSDictionary?
            let result = script?.executeAndReturnError(&errInfo)

            if result != nil {
                // Success — automation is granted
                autoGranted = true
                UserDefaults.standard.set(true, forKey: cacheKey)
            } else if let err = errInfo,
                      let code = err[NSAppleScript.errorNumber] as? Int {
                if code == -1743 {
                    // Explicitly denied — stay false
                    autoGranted = false
                } else {
                    // Other error (e.g. timeout, app not running) — treat as granted
                    // so we don't block the UI for unrelated scripting errors
                    autoGranted = true
                    UserDefaults.standard.set(true, forKey: cacheKey)
                }
            } else {
                // No error info — script ran OK
                autoGranted = true
                UserDefaults.standard.set(true, forKey: cacheKey)
            }
        }

        DispatchQueue.main.async {
            self.isAccessibilityGranted = axGranted
            self.isAutomationGranted = autoGranted
        }
    }

    /// Force-reset the cached automation permission state (e.g. when user wants to re-check)
    public func resetAutomationCache() {
        UserDefaults.standard.removeObject(forKey: "automationGrantedV2")
        checkAllPermissions()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestAccessibilityPrompt() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func requestAutomationPrompt() {
        let script = NSAppleScript(source: """
        tell application "System Events" to get name
        """)
        var errInfo: NSDictionary?
        _ = script?.executeAndReturnError(&errInfo)
        checkAllPermissions()
    }

    public static func extractOwnerName(from deviceName: String, appleIdName: String = "", email: String = "") -> String {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let apostropheRange = trimmed.range(of: "’s ", options: .caseInsensitive) ?? trimmed.range(of: "'s ", options: .caseInsensitive) {
            let namePart = String(trimmed[..<apostropheRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !namePart.isEmpty { return namePart }
        }
        if let start = trimmed.range(of: "("), let end = trimmed.range(of: ")", range: start.upperBound..<trimmed.endIndex) {
            let inside = String(trimmed[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !inside.isEmpty && !inside.lowercased().contains("gb") && !inside.lowercased().contains("гб") {
                return inside
            }
        }
        if let otRange = trimmed.range(of: " от ", options: .caseInsensitive) {
            let namePart = String(trimmed[otRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !namePart.isEmpty { return namePart }
        }
        if let otRange = trimmed.range(of: " пользователя ", options: .caseInsensitive) {
            let namePart = String(trimmed[otRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !namePart.isEmpty { return namePart }
        }
        if !appleIdName.isEmpty { return appleIdName }
        if !email.isEmpty {
            let prefix = email.components(separatedBy: "@").first ?? ""
            if !prefix.isEmpty { return prefix }
        }
        return "Пользователь"
    }

    public func loadKnownDevices() -> [DeviceInfo] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.knownDevicesPath)),
              let list = try? JSONDecoder().decode([DeviceInfo].self, from: data) else {
            return []
        }
        return list
    }

    public func saveKnownDevices() {
        try? FileManager.default.createDirectory(atPath: Self.libraryDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self.knownDevices) {
            try? data.write(to: URL(fileURLWithPath: Self.knownDevicesPath))
        }
    }

    public func forgetDevice(id: String) {
        let devToForget = knownDevices.first(where: { $0.id == id }) ?? connectedDevices.first(where: { $0.id == id })
        let udid = devToForget?.udid ?? id

        knownDevices.removeAll(where: { $0.id == id || (!udid.isEmpty && $0.udid == udid) })
        connectedDevices.removeAll(where: { $0.id == id || (!udid.isEmpty && $0.udid == udid) })

        if selectedDeviceId == id || selectedDeviceId == udid {
            selectedDeviceId = connectedDevices.first?.id ?? knownDevices.first?.id ?? ""
        }

        saveKnownDevices()

        DispatchQueue.global(qos: .userInitiated).async {
            let coreScript = "\(Self.workDir)/ios_core.py"
            if FileManager.default.isExecutableFile(atPath: coreScript) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: coreScript)
                proc.arguments = ["unpair", udid]
                try? proc.run()
                proc.waitUntilExit()
            }
        }

        appendLog("Связь с устройством «\(devToForget?.name ?? id)» удалена. Сопряжение сброшено.", level: "DEVICE")
    }

    public func selectDevice(id: String) {
        let previousId = self.selectedDeviceId
        self.userManuallySelectedDeviceId = id
        self.selectedDeviceId = id
        let connName = activeDevice?.connectionType == .usb ? "USB (Кабель)" : (activeDevice?.connectionType == .wifi ? "Wi-Fi (Сеть)" : "Офлайн")
        appendLog("Выбрано единственное активное устройство: «\(activeDevice?.name ?? id)» [\(connName)]", level: "DEVICE")

        // If active device changed, automatically scan installed apps on the newly selected device
        if previousId != id {
            self.scanInstalledAppsFromDevice()
        }
    }

    public func updateOwnerName(id: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let idx = knownDevices.firstIndex(where: { $0.id == id }) {
            knownDevices[idx].ownerName = trimmed
        }
        if let idx = connectedDevices.firstIndex(where: { $0.id == id }) {
            connectedDevices[idx].ownerName = trimmed
        }
        saveKnownDevices()
    }

    public func refreshDevices() {
        let currentKnown = self.knownDevices
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.isRefreshingDevicesInProgress { return }
            self.isRefreshingDevicesInProgress = true
            defer { self.isRefreshingDevicesInProgress = false }
            
            let onlineDevs = self.getConnectedDevicesDetails(currentKnown: currentKnown)

            DispatchQueue.main.async {
                // Priority sorting: USB (Cable) takes top priority over Wi-Fi
                let sortedOnline = onlineDevs.sorted { d1, d2 in
                    if d1.connectionType == .usb && d2.connectionType != .usb { return true }
                    if d1.connectionType != .usb && d2.connectionType == .usb { return false }
                    return d1.name < d2.name
                }
                DispatchQueue.main.async { self.connectedDevices = sortedOnline }

                var updatedKnown = self.knownDevices
                if updatedKnown.isEmpty {
                    updatedKnown = self.loadKnownDevices()
                }

                for online in sortedOnline {
                    if let idx = updatedKnown.firstIndex(where: { $0.id == online.id || (!online.udid.isEmpty && $0.udid == online.udid) }) {
                        var existing = updatedKnown[idx]
                        existing.name = online.name
                        if existing.ownerName.isEmpty || existing.ownerName == "Пользователь" {
                            existing.ownerName = online.ownerName
                        }
                        existing.modelIdentifier = online.modelIdentifier
                        existing.marketingName = online.marketingName
                        existing.iosVersion = online.iosVersion
                        if !online.diskCapacity.isEmpty { existing.diskCapacity = online.diskCapacity }
                        if !online.battery.isEmpty { existing.battery = online.battery }
                        if !online.serialNumber.isEmpty { existing.serialNumber = online.serialNumber }
                        if !online.wifiAddress.isEmpty { existing.wifiAddress = online.wifiAddress }
                        existing.connectionType = online.connectionType
                        existing.isOnline = true
                        existing.lastSeen = Date()
                        updatedKnown[idx] = existing
                    } else {
                        updatedKnown.insert(online, at: 0)
                    }
                }

                for i in 0..<updatedKnown.count {
                    let k = updatedKnown[i]
                    if !sortedOnline.contains(where: { $0.id == k.id || (!k.udid.isEmpty && $0.udid == k.udid) }) {
                        updatedKnown[i].isOnline = false
                        updatedKnown[i].connectionType = .offline
                    }
                }

                DispatchQueue.main.async { self.knownDevices = updatedKnown }
                self.saveKnownDevices()

                // Selection Logic:
                // 1. If user manually chose a device and it is still online, preserve user choice!
                if let manualId = self.userManuallySelectedDeviceId,
                   let matching = sortedOnline.first(where: { $0.id == manualId || (!manualId.isEmpty && $0.udid == manualId) }) {
                    self.selectedDeviceId = matching.id
                } else {
                    // 2. Automatic selection: USB cable takes precedence over Wi-Fi
                    if let usbDev = sortedOnline.first(where: { $0.connectionType == .usb }) {
                        self.selectedDeviceId = usbDev.id
                    } else if let wifiDev = sortedOnline.first {
                        self.selectedDeviceId = wifiDev.id
                    } else if self.selectedDeviceId.isEmpty || !updatedKnown.contains(where: { $0.id == self.selectedDeviceId }) {
                        self.selectedDeviceId = updatedKnown.first?.id ?? ""
                    }
                }

                if self.oldDeviceApps.isEmpty && !sortedOnline.isEmpty {
                    self.scanInstalledAppsFromDevice()
                }
            }
        }
    }

    public func loadCachedPurchases() -> [PurchasedApp] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.purchasesCachePath)),
              let apps = try? JSONDecoder().decode([PurchasedApp].self, from: data) else {
            return []
        }
        return apps
    }

    public func saveCachedPurchases(_ apps: [PurchasedApp]) {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        try? FileManager.default.createDirectory(atPath: Self.libraryDir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: Self.purchasesCachePath))
    }

    public func refreshPurchasedApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.isRefreshingPurchasesInProgress { return }
            self.isRefreshingPurchasesInProgress = true
            defer { self.isRefreshingPurchasesInProgress = false }
            
            let isDirect = UserDefaults.standard.bool(forKey: "isDirectAppleIdAuthenticated")
            
            if isDirect {
                // Immediately show cached apps if available
                if self.purchasedApps.isEmpty {
                    let cached = self.loadCachedPurchases()
                    if !cached.isEmpty {
                        DispatchQueue.main.async {
                            DispatchQueue.main.async { self.purchasedApps = cached }
                            DispatchQueue.main.async { self.totalPurchasedAppsCount = cached.count }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    DispatchQueue.main.async { self.isLoadingPurchasedApps = true }
                }
                
                let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
                if FileManager.default.isExecutableFile(atPath: ipatoolBin) {
                    struct IpatoolListResponse: Codable {
                        struct AppItem: Codable {
                            let id: Int64
                            let bundleID: String
                            let name: String
                        }
                        let count: Int?
                        let totalCount: Int?
                        let page: Int?
                        let apps: [AppItem]?
                    }
                    
                    var currentPage = 1
                    var totalCount = 0
                    var finalApps: [PurchasedApp] = []
                    var seenIds = Set<Int64>()
                    
                    while true {
                        let (status, data) = Self.runProcessWithSafeOutput(
                            executable: ipatoolBin,
                            arguments: ["list-purchases", "--format", "json", "--non-interactive", "--keychain-passphrase", Self.ipatoolPassphrase, "-l", "100", "-p", "\(currentPage)"],
                            timeout: 30.0
                        )
                        
                        guard status == 0, let rawOut = String(data: data, encoding: .utf8), !rawOut.contains("failed to list purchases") else {
                            break
                        }
                        
                        guard let dict = try? JSONDecoder().decode(IpatoolListResponse.self, from: data),
                              let appsList = dict.apps, !appsList.isEmpty else {
                            break
                        }
                        
                        if let tc = dict.totalCount {
                            totalCount = tc
                        }
                        
                        for appItem in appsList {
                            if !seenIds.contains(appItem.id) {
                                seenIds.insert(appItem.id)
                                finalApps.append(PurchasedApp(
                                    adamId: appItem.id,
                                    name: appItem.name,
                                    bundleId: appItem.bundleID,
                                    artworkUrl: nil,
                                    versionId: 0,
                                    purchaseDate: nil,
                                    ownerDsid: self.currentAccountDsid
                                ))
                            }
                        }
                        
                        let currentBatch = finalApps
                        let currentTotal = totalCount
                        DispatchQueue.main.async {
                            DispatchQueue.main.async { self.purchasedApps = currentBatch }
                            DispatchQueue.main.async { self.totalPurchasedAppsCount = currentTotal > 0 ? currentTotal : currentBatch.count }
                            
                            // Automatically enrich any scanned oldDeviceApps that were missing adamId
                            for i in 0..<self.oldDeviceApps.count {
                                if self.oldDeviceApps[i].adamId == nil {
                                    let bId = self.oldDeviceApps[i].bundleId
                                    if let p = currentBatch.first(where: { $0.bundleId == bId }) {
                                        self.oldDeviceApps[i].adamId = p.adamId
                                    }
                                }
                            }
                        }
                        
                        if totalCount > 0 && finalApps.count >= totalCount {
                            break
                        }
                        
                        if appsList.count < 100 {
                            break
                        }
                        
                        currentPage += 1
                        if currentPage > 50 {
                            break
                        }
                    }
                    
                    if !finalApps.isEmpty {
                        self.saveCachedPurchases(finalApps)
                    }
                }
                
                DispatchQueue.main.async {
                    DispatchQueue.main.async { self.isLoadingPurchasedApps = false }
                }
            } else {
                let finalApps = self.loadPurchasedAppsFromDB()
                let finalDsid = self.getOwnerDsid() ?? ""
                
                DispatchQueue.main.async {
                    DispatchQueue.main.async { self.purchasedApps = finalApps }
                    DispatchQueue.main.async { self.totalPurchasedAppsCount = finalApps.count }
                    if !finalDsid.isEmpty { 
                        DispatchQueue.main.async { self.currentAccountDsid = finalDsid  }
                    }

                    // Automatically enrich any scanned oldDeviceApps that were missing adamId
                    for i in 0..<self.oldDeviceApps.count {
                        if self.oldDeviceApps[i].adamId == nil {
                            let bId = self.oldDeviceApps[i].bundleId
                            if let p = finalApps.first(where: { $0.bundleId == bId }) {
                                self.oldDeviceApps[i].adamId = p.adamId
                            }
                        }
                    }
                }
            }
        }
    }

    public func loadUserMappings() -> [String: Int64] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.userMappingsPath)),
              let dict = try? JSONDecoder().decode([String: Int64].self, from: data) else {
            return [:]
        }
        return dict
    }

    public func saveUserMapping(bundleId: String, adamId: Int64) {
        var mappings = loadUserMappings()
        mappings[bundleId] = adamId
        try? FileManager.default.createDirectory(atPath: Self.libraryDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(mappings) {
            try? data.write(to: URL(fileURLWithPath: Self.userMappingsPath))
        }

        DispatchQueue.main.async {
            if let idx = self.oldDeviceApps.firstIndex(where: { $0.bundleId == bundleId }) {
                self.oldDeviceApps[idx].adamId = adamId
            }
        }
    }

    public static func mapMarketingName(_ identifier: String, modelNumber: String = "") -> String {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let mNum = modelNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let map: [String: String] = [
            // iPhone 17 Series (2025/2026)
            "iPhone18,1": "iPhone 17 Pro",
            "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,3": "iPhone Air",
            "iPhone18,4": "iPhone 17",
            "iPhone18,5": "iPhone 17 Plus",

            // iPhone 16 Series (2024)
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,5": "iPhone 16e",

            // iPhone 15 Series (2023)
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",

            // iPhone 14 Series (2022)
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",

            // iPhone 13 Series (2021)
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",

            // iPhone 12 Series (2020)
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",

            // iPhone SE
            "iPhone8,4": "iPhone SE (1-го поколения)",
            "iPhone12,8": "iPhone SE (2-го поколения)",
            "iPhone14,6": "iPhone SE (3-го поколения)",

            // iPhone 11 Series (2019)
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",

            // iPhone X, XS, XR, 8, 7, 6s, 6
            "iPhone11,8": "iPhone XR",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X",
            "iPhone10,1": "iPhone 8",
            "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus",
            "iPhone10,5": "iPhone 8 Plus",
            "iPhone9,1": "iPhone 7",
            "iPhone9,3": "iPhone 7",
            "iPhone9,2": "iPhone 7 Plus",
            "iPhone9,4": "iPhone 7 Plus",
            "iPhone8,1": "iPhone 6s",
            "iPhone8,2": "iPhone 6s Plus",
            "iPhone7,2": "iPhone 6",
            "iPhone7,1": "iPhone 6 Plus",
            "iPhone6,1": "iPhone 5s",
            "iPhone6,2": "iPhone 5s",
            "iPhone5,3": "iPhone 5c",
            "iPhone5,4": "iPhone 5c",
            "iPhone5,1": "iPhone 5",
            "iPhone5,2": "iPhone 5",

            // iPad Pro
            "iPad16,3": "iPad Pro 11″ (M4)",
            "iPad16,4": "iPad Pro 11″ (M4)",
            "iPad16,5": "iPad Pro 13″ (M4)",
            "iPad16,6": "iPad Pro 13″ (M4)",
            "iPad14,3": "iPad Pro 11″ (4-го пок. M2)",
            "iPad14,4": "iPad Pro 11″ (4-го пок. M2)",
            "iPad14,5": "iPad Pro 12.9″ (6-го пок. M2)",
            "iPad14,6": "iPad Pro 12.9″ (6-го пок. M2)",
            "iPad13,4": "iPad Pro 11″ (3-го пок. M1)",
            "iPad13,5": "iPad Pro 11″ (3-го пок. M1)",
            "iPad13,6": "iPad Pro 11″ (3-го пок. M1)",
            "iPad13,7": "iPad Pro 11″ (3-го пок. M1)",
            "iPad13,8": "iPad Pro 12.9″ (5-го пок. M1)",
            "iPad13,9": "iPad Pro 12.9″ (5-го пок. M1)",
            "iPad13,10": "iPad Pro 12.9″ (5-го пок. M1)",
            "iPad13,11": "iPad Pro 12.9″ (5-го пок. M1)",
            "iPad8,1": "iPad Pro 11″ (1-го пок.)",
            "iPad8,2": "iPad Pro 11″ (1-го пок.)",
            "iPad8,3": "iPad Pro 11″ (1-го пок.)",
            "iPad8,4": "iPad Pro 11″ (1-го пок.)",
            "iPad8,5": "iPad Pro 12.9″ (3-го пок.)",
            "iPad8,6": "iPad Pro 12.9″ (3-го пок.)",
            "iPad8,7": "iPad Pro 12.9″ (3-го пок.)",
            "iPad8,8": "iPad Pro 12.9″ (3-го пок.)",
            "iPad8,9": "iPad Pro 11″ (2-го пок.)",
            "iPad8,10": "iPad Pro 11″ (2-го пок.)",
            "iPad8,11": "iPad Pro 12.9″ (4-го пок.)",
            "iPad8,12": "iPad Pro 12.9″ (4-го пок.)",

            // iPad Air
            "iPad14,8": "iPad Air 11″ (M2)",
            "iPad14,9": "iPad Air 11″ (M2)",
            "iPad14,10": "iPad Air 13″ (M2)",
            "iPad14,11": "iPad Air 13″ (M2)",
            "iPad13,16": "iPad Air (5-го пок. M1)",
            "iPad13,17": "iPad Air (5-го пок. M1)",
            "iPad13,1": "iPad Air (4-го пок.)",
            "iPad13,2": "iPad Air (4-го пок.)",
            "iPad11,3": "iPad Air (3-го пок.)",
            "iPad11,4": "iPad Air (3-го пок.)",

            // iPad mini
            "iPad16,1": "iPad mini (A17 Pro)",
            "iPad16,2": "iPad mini (A17 Pro)",
            "iPad14,1": "iPad mini (6-го пок.)",
            "iPad14,2": "iPad mini (6-го пок.)",
            "iPad11,1": "iPad mini (5-го пок.)",
            "iPad11,2": "iPad mini (5-го пок.)",

            // iPad (Базовый)
            "iPad13,18": "iPad (10-го пок.)",
            "iPad13,19": "iPad (10-го пок.)",
            "iPad12,1": "iPad (9-го пок.)",
            "iPad12,2": "iPad (9-го пок.)",
            "iPad11,6": "iPad (8-го пок.)",
            "iPad11,7": "iPad (8-го пок.)",
            "iPad7,11": "iPad (7-го пок.)",
            "iPad7,12": "iPad (7-го пок.)"
        ]

        if let name = map[id] { return name }

        let modelMap: [String: String] = [
            "A3296": "iPhone 16 Pro Max", "A3297": "iPhone 16 Pro Max", "A3295": "iPhone 16 Pro Max", "A3084": "iPhone 16 Pro Max",
            "A3293": "iPhone 16 Pro", "A3294": "iPhone 16 Pro", "A3292": "iPhone 16 Pro", "A3083": "iPhone 16 Pro",
            "A3290": "iPhone 16 Plus", "A3291": "iPhone 16 Plus", "A3289": "iPhone 16 Plus", "A3082": "iPhone 16 Plus",
            "A3287": "iPhone 16", "A3288": "iPhone 16", "A3286": "iPhone 16", "A3081": "iPhone 16",
            "A3106": "iPhone 15 Pro Max", "A3108": "iPhone 15 Pro Max", "A2849": "iPhone 15 Pro Max", "A3105": "iPhone 15 Pro Max",
            "A3102": "iPhone 15 Pro", "A3104": "iPhone 15 Pro", "A2848": "iPhone 15 Pro", "A3101": "iPhone 15 Pro",
            "A3094": "iPhone 15 Plus", "A3096": "iPhone 15 Plus", "A2847": "iPhone 15 Plus", "A3093": "iPhone 15 Plus",
            "A3090": "iPhone 15", "A3092": "iPhone 15", "A2846": "iPhone 15", "A3089": "iPhone 15",
            "A2894": "iPhone 14 Pro Max", "A2896": "iPhone 14 Pro Max", "A2651": "iPhone 14 Pro Max",
            "A2890": "iPhone 14 Pro", "A2892": "iPhone 14 Pro", "A2650": "iPhone 14 Pro",
            "A2886": "iPhone 14 Plus", "A2888": "iPhone 14 Plus", "A2632": "iPhone 14 Plus",
            "A2882": "iPhone 14", "A2884": "iPhone 14", "A2649": "iPhone 14",
            "A2643": "iPhone 13 Pro Max", "A2644": "iPhone 13 Pro Max", "A2484": "iPhone 13 Pro Max",
            "A2638": "iPhone 13 Pro", "A2639": "iPhone 13 Pro", "A2483": "iPhone 13 Pro",
            "A2633": "iPhone 13", "A2634": "iPhone 13", "A2482": "iPhone 13",
            "A2628": "iPhone 13 mini", "A2629": "iPhone 13 mini", "A2481": "iPhone 13 mini",
            "A2411": "iPhone 12 Pro Max", "A2412": "iPhone 12 Pro Max", "A2342": "iPhone 12 Pro Max",
            "A2407": "iPhone 12 Pro", "A2408": "iPhone 12 Pro", "A2341": "iPhone 12 Pro",
            "A2403": "iPhone 12", "A2404": "iPhone 12", "A2172": "iPhone 12",
            "A2399": "iPhone 12 mini", "A2400": "iPhone 12 mini", "A2176": "iPhone 12 mini",
            "A2218": "iPhone 11 Pro Max", "A2220": "iPhone 11 Pro Max", "A2161": "iPhone 11 Pro Max",
            "A2215": "iPhone 11 Pro", "A2217": "iPhone 11 Pro", "A2160": "iPhone 11 Pro",
            "A2221": "iPhone 11", "A2223": "iPhone 11", "A2111": "iPhone 11",
            "A2783": "iPhone SE (3-го пок.)", "A2784": "iPhone SE (3-го пок.)", "A2595": "iPhone SE (3-го пок.)",
            "A2275": "iPhone SE (2-го пок.)", "A2296": "iPhone SE (2-го пок.)", "A2298": "iPhone SE (2-го пок.)"
        ]

        if !mNum.isEmpty, let mName = modelMap[mNum] { return mName }

        return id.isEmpty ? "iPhone" : id
    }

    
    public static func runProcessWithLiveOutput(executable: String, arguments: [String], timeout: TimeInterval = 1200.0, env: [String: String]? = nil, onOutput: @escaping (String) -> Void) -> (status: Int32, finalData: Data) {
        let proc = Process()
        if let e = env {
            var pEnv = ProcessInfo.processInfo.environment
            for (k, v) in e { pEnv[k] = v }
            proc.environment = pEnv
        }
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        if #available(macOS 10.10, *) {
            proc.qualityOfService = .utility
        }
        
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        
        var outputData = Data()
        let lock = NSLock()
        
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty {
                pipe.fileHandleForReading.readabilityHandler = nil
            } else {
                if let str = String(data: data, encoding: .utf8) {
                    onOutput(str)
                }
                lock.lock()
                outputData.append(data)
                lock.unlock()
            }
        }
        
        do {
            try proc.run()
            
            // Timeout logic
            var isTimedOut = false
            let dispatchWorkItem = DispatchWorkItem {
                if proc.isRunning {
                    isTimedOut = true
                    proc.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: dispatchWorkItem)
            
            proc.waitUntilExit()
            dispatchWorkItem.cancel()
            
            // Force final read
            pipe.fileHandleForReading.readabilityHandler = nil
            let finalD = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            outputData.append(finalD)
            let resultData = outputData
            lock.unlock()
            
            return (isTimedOut ? -1 : proc.terminationStatus, resultData)
            
        } catch {
            return (-1, Data())
        }
    }

public static func runProcessWithSafeOutput(executable: String, arguments: [String], timeout: TimeInterval = 25.0, env: [String: String]? = nil) -> (status: Int32, data: Data) {
        let proc = Process()
        if let e = env {
            var pEnv = ProcessInfo.processInfo.environment
            for (k, v) in e { pEnv[k] = v }
            proc.environment = pEnv
        }
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = arguments
        if #available(macOS 10.10, *) {
            proc.qualityOfService = .utility
        }

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var outputData = Data()
        let group = DispatchGroup()
        group.enter()

        // Read pipe concurrently in background queue to completely avoid kernel pipe buffer deadlocks on large outputs (>64KB)
        DispatchQueue.global(qos: .userInitiated).async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        do {
            try proc.run()
        } catch {
            return (-1, Data())
        }

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + timeout) {
            if proc.isRunning { proc.terminate() }
        }

        proc.waitUntilExit()
        _ = group.wait(timeout: .now() + 3.0)

        return (proc.terminationStatus, outputData)
    }

    public func getConnectedDevicesDetails(currentKnown: [DeviceInfo] = []) -> [DeviceInfo] {
        let iosBin = StandaloneToolchain.shared.iosBinaryPath
        var discoveredMap: [String: DeviceInfo] = [:]

        // LAYER 1: ios list --details (fast go-ios lockdown query)
        if FileManager.default.isExecutableFile(atPath: iosBin) {
            let (status, data) = Self.runProcessWithSafeOutput(executable: iosBin, arguments: ["list", "--details"], timeout: 6.0)
            if status == 0 && !data.isEmpty {
                var jsonDict: [String: Any]? = nil
                if let directDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    jsonDict = directDict
                } else if let rawString = String(data: data, encoding: .utf8),
                          let startIdx = rawString.firstIndex(of: "{"),
                          let endIdx = rawString.lastIndex(of: "}") {
                    let sub = String(rawString[startIdx...endIdx])
                    if let subData = sub.data(using: .utf8) {
                        jsonDict = try? JSONSerialization.jsonObject(with: subData) as? [String: Any]
                    }
                }

                if let deviceList = jsonDict?["deviceList"] as? [[String: Any]], !deviceList.isEmpty {
                    for d in deviceList {
                        let udid = (d["Udid"] as? String) ?? ""
                        guard !udid.isEmpty else { continue }

                        let productType = (d["ProductType"] as? String) ?? ""
                        let productVer = (d["ProductVersion"] as? String) ?? ""
                        let rawConn = (d["ConnectionType"] as? String) ?? "USB"
                        let connType: DeviceConnectionType = (rawConn.lowercased().contains("net") || rawConn.lowercased().contains("wi")) ? .wifi : .usb

                        let marketingName = Self.mapMarketingName(productType, modelNumber: "")
                        let fallbackName = marketingName.isEmpty ? "iPhone" : marketingName

                        var devName = fallbackName
                        if let known = currentKnown.first(where: { $0.udid == udid }), !known.name.isEmpty, known.name != "iPhone" {
                            devName = known.name
                        }

                        let iosVersion = productVer.isEmpty ? "iOS" : (productVer.starts(with: "iOS") ? productVer : "iOS \(productVer)")

                        let newDev = DeviceInfo(
                            name: devName,
                            ownerName: Self.extractOwnerName(from: devName),
                            modelIdentifier: productType,
                            marketingName: marketingName.isEmpty ? "iPhone" : marketingName,
                            iosVersion: iosVersion,
                            diskCapacity: "",
                            battery: "",
                            udid: udid,
                            ecid: "",
                            serialNumber: "",
                            wifiAddress: "",
                            connectionType: connType,
                            isOnline: true,
                            lastSeen: Date()
                        )

                        if let existing = discoveredMap[udid] {
                            if existing.connectionType != .usb && connType == .usb {
                                discoveredMap[udid] = newDev
                            }
                        } else {
                            discoveredMap[udid] = newDev
                        }
                    }
                }
            }
        }

        // LAYER 2: Fallback to simple `ios list` (returns raw list of UDIDs) if Layer 1 was empty
        if discoveredMap.isEmpty && FileManager.default.isExecutableFile(atPath: iosBin) {
            let (status, data) = Self.runProcessWithSafeOutput(executable: iosBin, arguments: ["list"], timeout: 4.0)
            if status == 0 && !data.isEmpty {
                var udidList: [String] = []
                if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let list = dict["deviceList"] as? [String] {
                    udidList = list
                } else if let arr = (try? JSONSerialization.jsonObject(with: data)) as? [String] {
                    udidList = arr
                }

                for udid in udidList where !udid.isEmpty {
                    var devName = "iPhone"
                    var mName = "iPhone"
                    var mId = "iPhone"
                    var iVer = "iOS"
                    if let known = currentKnown.first(where: { $0.udid == udid }) {
                        devName = known.name
                        mName = known.marketingName
                        mId = known.modelIdentifier
                        iVer = known.iosVersion
                    }

                    discoveredMap[udid] = DeviceInfo(
                        name: devName,
                        ownerName: Self.extractOwnerName(from: devName),
                        modelIdentifier: mId,
                        marketingName: mName,
                        iosVersion: iVer,
                        udid: udid,
                        connectionType: .usb,
                        isOnline: true,
                        lastSeen: Date()
                    )
                }
            }
        }

        // LAYER 3: Native macOS ioreg fallback for physical USB-connected iOS devices
        if discoveredMap.isEmpty {
            let (ioregStatus, ioregData) = Self.runProcessWithSafeOutput(executable: "/usr/sbin/ioreg", arguments: ["-p", "IOUSB", "-l", "-w", "0"], timeout: 3.0)
            if ioregStatus == 0, let ioregStr = String(data: ioregData, encoding: .utf8) {
                let lines = ioregStr.components(separatedBy: "\n")
                var currentProd = ""
                for line in lines {
                    if line.contains("\"kUSBProductString\"") {
                        if line.contains("iPhone") { currentProd = "iPhone" }
                        else if line.contains("iPad") { currentProd = "iPad" }
                        else { currentProd = "" }
                    }
                    if !currentProd.isEmpty && line.contains("\"kUSBSerialNumberString\"") {
                        let parts = line.components(separatedBy: "=")
                        if parts.count > 1 {
                            let rawSerial = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"\r\n\t"))
                            if !rawSerial.isEmpty && rawSerial.count >= 16 {
                                var formattedUdid = rawSerial
                                if formattedUdid.count == 24 && !formattedUdid.contains("-") {
                                    let prefix = String(formattedUdid.prefix(8))
                                    let suffix = String(formattedUdid.suffix(16))
                                    formattedUdid = "\(prefix)-\(suffix)"
                                }

                                var devName = currentProd
                                var mName = currentProd
                                if let known = currentKnown.first(where: { $0.udid == formattedUdid || $0.udid == rawSerial }) {
                                    devName = known.name
                                    mName = known.marketingName
                                }

                                discoveredMap[formattedUdid] = DeviceInfo(
                                    name: devName,
                                    ownerName: Self.extractOwnerName(from: devName),
                                    modelIdentifier: currentProd,
                                    marketingName: mName,
                                    iosVersion: "iOS",
                                    udid: formattedUdid,
                                    connectionType: .usb,
                                    isOnline: true,
                                    lastSeen: Date()
                                )
                            }
                        }
                        currentProd = ""
                    }
                }
            }
        }

        // Asynchronously enrich friendly device names for devices that just say "iPhone" or "iPad"
        let devicesToEnrich = Array(discoveredMap.values)
        if FileManager.default.isExecutableFile(atPath: iosBin) {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                for dev in devicesToEnrich where dev.name == "iPhone" || dev.name == "iPad" {
                    let (nameStatus, nameData) = Self.runProcessWithSafeOutput(executable: iosBin, arguments: ["devicename", "--udid=\(dev.udid)"], timeout: 4.0)
                    if nameStatus == 0,
                       let nameJson = (try? JSONSerialization.jsonObject(with: nameData)) as? [String: Any],
                       let fetched = nameJson["devicename"] as? String, !fetched.isEmpty, fetched != "iPhone" && fetched != "iPad" {
                        DispatchQueue.main.async {
                            if let idx = self.connectedDevices.firstIndex(where: { $0.udid == dev.udid }) {
                                self.connectedDevices[idx].name = fetched
                                self.connectedDevices[idx].ownerName = Self.extractOwnerName(from: fetched)
                            }
                            if let kIdx = self.knownDevices.firstIndex(where: { $0.udid == dev.udid }) {
                                self.knownDevices[kIdx].name = fetched
                                self.knownDevices[kIdx].ownerName = Self.extractOwnerName(from: fetched)
                                self.saveKnownDevices()
                            }
                        }
                    }
                }
            }
        }

        return Array(discoveredMap.values)
    }

    public var catalogCache: [AppItem] = []

    public func scanInstalledAppsFromDevice(ecid: String? = nil, catalog: [AppItem] = []) {
        if !catalog.isEmpty {
            self.catalogCache = catalog
        }
        let activeCatalog = !catalog.isEmpty ? catalog : self.catalogCache

        DispatchQueue.main.async { self.isScanningApps = true }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let scannerBin = StandaloneToolchain.shared.iosScannerBinaryPath
            let iosBin = StandaloneToolchain.shared.iosBinaryPath
            var discovered: [DeviceInstalledApp] = []
            let userMappings = self.loadUserMappings()

            var targetUdid = self.activeDevice?.udid ?? ""
            if targetUdid.isEmpty {
                targetUdid = self.connectedDevices.first(where: { $0.connectionType == .usb })?.udid
                    ?? self.connectedDevices.first?.udid ?? ""
            }
            if targetUdid.isEmpty && FileManager.default.isExecutableFile(atPath: iosBin) {
                let online = self.getConnectedDevicesDetails()
                targetUdid = online.first(where: { $0.connectionType == .usb })?.udid ?? online.first?.udid ?? ""
            }

            if FileManager.default.isExecutableFile(atPath: scannerBin) {
                var args: [String] = []
                if !targetUdid.isEmpty {
                    args.append("--udid=\(targetUdid)")
                }

                let (status, data) = Self.runProcessWithSafeOutput(executable: scannerBin, arguments: args, timeout: 25.0)
                if status == 0 && !data.isEmpty {
                    var appsArray: [[String: Any]] = []

                    if let directList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        appsArray = directList
                    } else if let rawString = String(data: data, encoding: .utf8),
                              let startIdx = rawString.firstIndex(of: "["),
                              let endIdx = rawString.lastIndex(of: "]") {
                        let jsonSub = String(rawString[startIdx...endIdx])
                        if let subData = jsonSub.data(using: .utf8),
                           let list = try? JSONSerialization.jsonObject(with: subData) as? [[String: Any]] {
                            appsArray = list
                        }
                    }

                    for a in appsArray {
                        let dispName = (a["displayName"] as? String) ?? (a["name"] as? String) ?? ""
                        let bId = (a["bundleId"] as? String) ?? ""
                        let bVer = (a["version"] as? String) ?? ""
                        guard !bId.isEmpty else { continue }

                        var adamId: Int64? = nil
                        if let aid = a["adamId"] as? Int64, aid > 0 {
                            adamId = aid
                        } else if let aidNum = a["adamId"] as? NSNumber, aidNum.int64Value > 0 {
                            adamId = aidNum.int64Value
                        }

                        var artworkUrl: String? = nil

                        if let custom = userMappings[bId] { adamId = custom }

                        if adamId == nil {
                            for cat in activeCatalog {
                                if cat.bundle_id == bId || (cat.bundle_ids?.contains(bId) == true) {
                                    adamId = cat.adam_id
                                    break
                                }
                            }
                        }

                        if adamId == nil {
                            if let p = self.purchasedApps.first(where: { $0.bundleId == bId }) {
                                adamId = p.adamId
                                if artworkUrl == nil { artworkUrl = p.artworkUrl }
                            }
                        }

                        discovered.append(DeviceInstalledApp(
                            name: dispName.isEmpty ? bId : dispName,
                            displayName: dispName.isEmpty ? bId : dispName,
                            bundleId: bId,
                            bundleVersion: bVer,
                            adamId: adamId,
                            artworkUrl: artworkUrl
                        ))
                    }
                }
            }

            if discovered.isEmpty && FileManager.default.isExecutableFile(atPath: iosBin) {
                var args = ["apps"]
                if !targetUdid.isEmpty {
                    args.append("--udid=\(targetUdid)")
                }

                let (status, data) = Self.runProcessWithSafeOutput(executable: iosBin, arguments: args, timeout: 30.0, env: ["ENABLE_GO_IOS_AGENT": "user"])
                if status == 0 && !data.isEmpty {
                    var appsArray: [[String: Any]] = []

                    if let directList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        appsArray = directList
                    } else if let rawString = String(data: data, encoding: .utf8),
                              let startIdx = rawString.firstIndex(of: "["),
                              let endIdx = rawString.lastIndex(of: "]") {
                        let jsonSub = String(rawString[startIdx...endIdx])
                        if let subData = jsonSub.data(using: .utf8),
                           let list = try? JSONSerialization.jsonObject(with: subData) as? [[String: Any]] {
                            appsArray = list
                        }
                    }

                    for a in appsArray {
                        let dispName = (a["CFBundleDisplayName"] as? String) ?? (a["CFBundleName"] as? String) ?? ""
                        let bId = (a["CFBundleIdentifier"] as? String) ?? ""
                        let bVer = (a["CFBundleShortVersionString"] as? String) ?? (a["CFBundleVersion"] as? String) ?? ""
                        guard !bId.isEmpty else { continue }

                        var adamId: Int64? = nil
                        var artworkUrl: String? = nil

                        if let custom = userMappings[bId] { adamId = custom }

                        if adamId == nil {
                            for cat in activeCatalog {
                                if cat.bundle_id == bId || (cat.bundle_ids?.contains(bId) == true) {
                                    adamId = cat.adam_id
                                    break
                                }
                            }
                        }

                        if adamId == nil {
                            if let p = self.purchasedApps.first(where: { $0.bundleId == bId }) {
                                adamId = p.adamId
                                if artworkUrl == nil { artworkUrl = p.artworkUrl }
                            }
                        }

                        discovered.append(DeviceInstalledApp(
                            name: dispName.isEmpty ? bId : dispName,
                            displayName: dispName.isEmpty ? bId : dispName,
                            bundleId: bId,
                            bundleVersion: bVer,
                            adamId: adamId,
                            artworkUrl: artworkUrl
                        ))
                    }
                }
            }

            let coreScript = "\(Self.workDir)/ios_core.py"
            if discovered.isEmpty && FileManager.default.isExecutableFile(atPath: coreScript) {
                let (coreStatus, coreData) = Self.runProcessWithSafeOutput(executable: coreScript, arguments: ["apps"], timeout: 20.0)
                if coreStatus == 0 && !coreData.isEmpty {
                    if let list = try? JSONSerialization.jsonObject(with: coreData) as? [[String: Any]] {
                        for a in list {
                            let name = (a["name"] as? String) ?? ""
                            let bId = (a["bundleId"] as? String) ?? ""
                            let bVer = (a["version"] as? String) ?? ""
                            var adamId: Int64? = a["adamId"] as? Int64
                            var artworkUrl: String? = a["artworkUrl"] as? String

                            if let custom = userMappings[bId] { adamId = custom }
                            if adamId == nil {
                                for cat in catalog {
                                    if cat.bundle_id == bId || (cat.bundle_ids?.contains(bId) == true) {
                                        adamId = cat.adam_id
                                        break
                                    }
                                }
                            }
                            if adamId == nil {
                                if let p = self.purchasedApps.first(where: { $0.bundleId == bId }) {
                                    adamId = p.adamId
                                    if artworkUrl == nil { artworkUrl = p.artworkUrl }
                                }
                            }

                            discovered.append(DeviceInstalledApp(
                                name: name,
                                displayName: name,
                                bundleId: bId,
                                bundleVersion: bVer,
                                adamId: adamId,
                                artworkUrl: artworkUrl
                            ))
                        }
                    }
                }
            }

            // Fallback to cfgutil if core script returned empty
            if discovered.isEmpty && FileManager.default.isExecutableFile(atPath: Self.cfgutilPath) {
                var args = ["--format", "json"]
                if let e = ecid, !e.isEmpty { args.append(contentsOf: ["-e", e]) }
                args.append(contentsOf: ["get", "installedApps"])

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: Self.cfgutilPath)
                proc.arguments = args
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe

                if (try? proc.run()) != nil {
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let output = json["Output"] as? [String: Any] {
                        for (key, devData) in output {
                            guard key != "Errors" else { continue }
                            if let dict = devData as? [String: Any],
                               let apps = dict["installedApps"] as? [[String: Any]] {
                                for a in apps {
                                    let dispName = (a["displayName"] as? String) ?? (a["itunesName"] as? String) ?? ""
                                    let bId = (a["bundleIdentifier"] as? String) ?? ""
                                    let bVer = (a["bundleVersion"] as? String) ?? ""
                                    guard !bId.isEmpty else { continue }

                                    var adamId: Int64? = userMappings[bId]
                                    var artworkUrl: String? = nil
                                    if adamId == nil {
                                        for cat in catalog {
                                            if cat.bundle_id == bId || (cat.bundle_ids?.contains(bId) == true) {
                                                adamId = cat.adam_id
                                                break
                                            }
                                        }
                                    }
                                    if adamId == nil {
                                        if let p = self.purchasedApps.first(where: { $0.bundleId == bId }) {
                                            adamId = p.adamId
                                            artworkUrl = p.artworkUrl
                                        }
                                    }

                                    discovered.append(DeviceInstalledApp(
                                        name: dispName,
                                        displayName: dispName,
                                        bundleId: bId,
                                        bundleVersion: bVer,
                                        adamId: adamId,
                                        artworkUrl: artworkUrl
                                    ))
                                }
                            }
                        }
                    }
                }
            }

            let sorted = discovered.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
            DispatchQueue.main.async {
                self.oldDeviceApps = sorted
                self.isScanningApps = false
                self.fetchArtworksForApps()
            }

            for app in sorted where app.adamId == nil {
                let bId = app.bundleId
                let aName = app.name
                Task {
                    let (resolvedId, resolvedArt) = await self.resolveOnlineAdamId(bundleId: bId, name: aName)
                    if let aid = resolvedId {
                        DispatchQueue.main.async {
                            if let idx = self.oldDeviceApps.firstIndex(where: { $0.bundleId == bId }) {
                                self.oldDeviceApps[idx].adamId = aid
                                if let art = resolvedArt {
                                    self.oldDeviceApps[idx].artworkUrl = art
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func fetchArtworksForApps() {
        let appsNeedingArt = self.oldDeviceApps.filter { ($0.artworkUrl == nil || $0.artworkUrl?.isEmpty == true) && ($0.adamId != nil && $0.adamId! > 0) }
        guard !appsNeedingArt.isEmpty else { return }

        Task {
            let idChunks = stride(from: 0, to: appsNeedingArt.count, by: 50).map {
                Array(appsNeedingArt[$0..<min($0 + 50, appsNeedingArt.count)])
            }

            for chunk in idChunks {
                let idList = chunk.compactMap { $0.adamId }.map { String($0) }.joined(separator: ",")
                for country in ["ru", "us"] {
                    guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(idList)&country=\(country)") else { continue }
                    var req = URLRequest(url: url, timeoutInterval: 5.0)
                    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    if let (data, _) = try? await URLSession.shared.data(for: req),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        DispatchQueue.main.async {
                            for res in results {
                                if let trackId = res["trackId"] as? Int64,
                                   let art = (res["artworkUrl100"] as? String) ?? (res["artworkUrl60"] as? String) ?? (res["artworkUrl512"] as? String) {
                                    if let idx = self.oldDeviceApps.firstIndex(where: { $0.adamId == trackId }) {
                                        self.oldDeviceApps[idx].artworkUrl = art
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func resolveOnlineAdamId(bundleId: String, name: String) async -> (Int64?, String?) {
        let countries = ["ru", "us"]
        for country in countries {
            if let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=\(country)") {
                var req = URLRequest(url: url, timeoutInterval: 4.0)
                req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
                if let (data, _) = try? await URLSession.shared.data(for: req),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first,
                   let trackId = first["trackId"] as? Int64 {
                    let art = first["artworkUrl100"] as? String
                    return (trackId, art)
                }
            }
        }

        if !name.isEmpty, let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let searchURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&country=ru&entity=software&limit=5") {
            var req = URLRequest(url: searchURL, timeoutInterval: 4.0)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                for item in results {
                    if let b = item["bundleId"] as? String, b == bundleId,
                       let trackId = item["trackId"] as? Int64 {
                        let art = item["artworkUrl100"] as? String
                        return (trackId, art)
                    }
                }
            }
        }

        return (nil, nil)
    }

    public func isConfiguratorRunning() -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.configurator.ui")
        return !apps.isEmpty
    }

    public func quitConfigurator(timeout: TimeInterval = 10.0) {
        guard isConfiguratorRunning() else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", "tell application id \"com.apple.configurator.ui\" to quit"]
        try? proc.run()
        proc.waitUntilExit()

        let start = Date()
        while isConfiguratorRunning() && Date().timeIntervalSince(start) < timeout {
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    public func openConfigurator() {
        let appURL = URL(fileURLWithPath: "/Applications/Apple Configurator.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    public func getOwnerDsid() -> String? {
        guard FileManager.default.fileExists(atPath: Self.defaultDBPath) else { return nil }
        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = "SELECT ZREDOWNLOADBUYPARAMS FROM ZMOBILEAPP WHERE ZREDOWNLOADBUYPARAMS LIKE '%ownerDsid=%' ORDER BY Z_PK DESC LIMIT 1;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    let params = String(cString: cStr)
                    for part in params.components(separatedBy: "&") {
                        if part.hasPrefix("ownerDsid=") {
                            return String(part.dropFirst("ownerDsid=".count))
                        }
                    }
                }
            }
        }
        return nil
    }

    public func loadPurchasedAppsFromDB() -> [PurchasedApp] {
        guard FileManager.default.fileExists(atPath: Self.defaultDBPath) else { return [] }
        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            return []
        }
        defer { sqlite3_close(db) }

        let query = """
        SELECT ZADAMID, ZNAME, ZITEMNAME, ZBUNDLEID, ZARTWORKURL, ZSOFTWAREVERSIONEXTERNALID, ZPURCHASEDATE, ZREDOWNLOADBUYPARAMS
        FROM ZMOBILEAPP
        WHERE ZNAME NOT LIKE 'Restore request%'
        ORDER BY ZPURCHASEDATE DESC;
        """

        var list: [PurchasedApp] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let adamId = sqlite3_column_int64(stmt, 0)
                let name = (sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }) ??
                           (sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }) ?? "App"
                let bundleId = (sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }) ?? ""
                let artworkUrl = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
                let versionId = sqlite3_column_int64(stmt, 5)
                let pdateCD = sqlite3_column_double(stmt, 6)
                let purchaseDate = pdateCD > 0 ? Date(timeIntervalSince1970: pdateCD + coreDataEpochDiff) : nil

                var dsid = "Current"
                if let pStr = sqlite3_column_text(stmt, 7).flatMap({ String(cString: $0) }) {
                    for part in pStr.components(separatedBy: "&") {
                        if part.hasPrefix("ownerDsid=") {
                            dsid = String(part.dropFirst("ownerDsid=".count))
                        }
                    }
                }

                list.append(PurchasedApp(
                    adamId: adamId,
                    name: name,
                    bundleId: bundleId,
                    artworkUrl: artworkUrl,
                    versionId: versionId,
                    purchaseDate: purchaseDate,
                    ownerDsid: dsid
                ))
            }
        }
        return list
    }

    public func cleanAllRestoreRequests() {
        guard FileManager.default.fileExists(atPath: Self.defaultDBPath) else { return }
        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK { return }
        defer { sqlite3_close(db) }

        let deleteSQL = "DELETE FROM ZMOBILEAPP WHERE ZNAME LIKE 'Restore request%' OR ZITEMNAME LIKE 'Restore request%';"
        let fixPkSQL = "UPDATE Z_PRIMARYKEY SET Z_MAX = (SELECT COALESCE(MAX(Z_PK), 0) FROM ZMOBILEAPP) WHERE Z_NAME = 'MobileApp';"

        sqlite3_exec(db, deleteSQL, nil, nil, nil)
        sqlite3_exec(db, fixPkSQL, nil, nil, nil)
    }

    public func injectRestoreRequest(adamId: Int64, extVersion: Int64 = 0) throws {
        cleanAllRestoreRequests()
        guard let dsid = getOwnerDsid() else {
            throw NSError(domain: "OpenStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не найден Apple ID в Apple Configurator. Войдите в аккаунт в Configurator."])
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            throw NSError(domain: "OpenStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть базу Apple Configurator."])
        }
        defer { sqlite3_close(db) }

        var buyParams = "productType=C&price=0&salableAdamId=\(adamId)&pricingParameters=STDRDL&pg=default&ownerDsid=\(dsid)"
        if extVersion > 0 {
            buyParams += "&appExtVrsId=\(extVersion)"
        }

        let nowCD = Date().timeIntervalSince1970 - coreDataEpochDiff
        let reqName = "Restore request \(adamId)"

        let updateSQL = "UPDATE Z_PRIMARYKEY SET Z_MAX = Z_MAX + 1 WHERE Z_NAME = 'MobileApp';"
        sqlite3_exec(db, updateSQL, nil, nil, nil)

        let insertSQL = """
        INSERT INTO ZMOBILEAPP (
            Z_PK, Z_ENT, Z_OPT, ZADAMID, ZSOFTWAREVERSIONEXTERNALID,
            ZIPHONECOMPATIBLE, ZIPODTOUCHCOMPATIBLE, ZIPADCOMPATIBLE,
            ZNAME, ZITEMNAME, ZKIND, ZLASTUPDATED, ZPURCHASEDATE,
            ZREDOWNLOADBUYPARAMS
        )
        SELECT
            Z_MAX, Z_ENT, 1, ?, ?,
            1, 1, 1,
            ?, ?, 'software', ?, ?,
            ?
        FROM Z_PRIMARYKEY WHERE Z_NAME = 'MobileApp';
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, adamId)
            sqlite3_bind_int64(stmt, 2, extVersion)
            sqlite3_bind_text(stmt, 3, (reqName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (reqName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 5, nowCD)
            sqlite3_bind_double(stmt, 6, nowCD)
            sqlite3_bind_text(stmt, 7, (buyParams as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                throw NSError(domain: "OpenStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ошибка вставки записи в SQLite базу."])
            }
        }
    }

    public func removeRestoreRequest(adamId: Int64) {
        guard FileManager.default.fileExists(atPath: Self.defaultDBPath) else { return }
        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK { return }
        defer { sqlite3_close(db) }

        let deleteSQL = "DELETE FROM ZMOBILEAPP WHERE ZADAMID = \(adamId) AND ZNAME LIKE 'Restore request \(adamId)%';"
        let fixPkSQL = "UPDATE Z_PRIMARYKEY SET Z_MAX = (SELECT COALESCE(MAX(Z_PK), 0) FROM ZMOBILEAPP) WHERE Z_NAME = 'MobileApp';"

        sqlite3_exec(db, deleteSQL, nil, nil, nil)
        sqlite3_exec(db, fixPkSQL, nil, nil, nil)
    }

    public func executeConfiguratorAutomation(adamId: Int64, appName: String = "") {
        if !isAccessibilityGranted {
            LogManager.shared.log("⚠️ Внимание: Для автоматических кликов требуется выдать доступ в «Системные настройки → Конфиденциальность → Универсальный доступ» для Open Store.", level: "AUTO")
            return // Skip AppleScript execution to avoid errors
        }
        
        let targetTag = "Restore request \(adamId)"
        LogManager.shared.log("🚀 Запуск автоматизации Apple Configurator для «\(appName)» [Тег: \(targetTag)]...", level: "AUTO")

        let scriptSource = """
        set trace to ""
        
        tell application "Apple Configurator"
            activate
            reopen
        end tell
        set trace to trace & "[AUTO] Apple Configurator активирован" & linefeed
        
        -- Ожидание появления главного окна
        set winFound to false
        repeat with wLoop from 1 to 20
            delay 0.25
            tell application "System Events"
                tell process "Apple Configurator"
                    if exists window 1 then
                        set winFound to true
                        exit repeat
                    end if
                end tell
            end tell
        end repeat
        
        if not winFound then
            return trace & "[AUTO] ❌ Главное окно Apple Configurator не появилось"
        end if
        set trace to trace & "[AUTO] Главное окно Configurator обнаружено" & linefeed
        
        tell application "System Events"
            tell process "Apple Configurator"
                set frontmost to true
                
                -- Закрываем старые модальные окна при наличии
                try
                    if exists (sheet 1 of window 1) then
                        if exists (button "Cancel" of sheet 1 of window 1) then
                            click (button "Cancel" of sheet 1 of window 1)
                        else if exists (button "Отменить" of sheet 1 of window 1) then
                            click (button "Отменить" of sheet 1 of window 1)
                        end if
                        set trace to trace & "[AUTO] Закрыто устаревшее модальное окно" & linefeed
                    end if
                end try
                
                delay 0.3
                
                -- Шаг 1 & 2: Ожидание готовности устройства и активации меню «Actions -> Add -> Apps…»
                set menuSuccess to false
                repeat with dLoop from 1 to 30
                    delay 0.35
                    try
                        if exists (UI element 1 of scroll area 1 of window 1) then
                            set value of attribute "AXFocused" of (UI element 1 of scroll area 1 of window 1) to true
                            keystroke "a" using command down
                        else if exists (scroll area 1 of window 1) then
                            set value of attribute "AXFocused" of (scroll area 1 of window 1) to true
                            keystroke "a" using command down
                        end if
                        
                        if (exists menu item "Apps…" of menu 1 of menu item "Add" of menu "Actions" of menu bar 1) and (enabled of menu item "Apps…" of menu 1 of menu item "Add" of menu "Actions" of menu bar 1) then
                            click menu item "Apps…" of menu 1 of menu item "Add" of menu "Actions" of menu bar 1
                            set menuSuccess to true
                            set trace to trace & "[AUTO] ✅ Нажат пункт меню: Actions -> Add -> Apps…" & linefeed
                            exit repeat
                        else if (exists menu item "Приложения…" of menu 1 of menu item "Добавить" of menu "Действия" of menu bar 1) and (enabled of menu item "Приложения…" of menu 1 of menu item "Добавить" of menu "Действия" of menu bar 1) then
                            click menu item "Приложения…" of menu 1 of menu item "Добавить" of menu "Действия" of menu bar 1
                            set menuSuccess to true
                            set trace to trace & "[AUTO] ✅ Нажат пункт меню: Действия -> Добавить -> Приложения…" & linefeed
                            exit repeat
                        end if
                    end try
                end repeat
                
                if not menuSuccess then
                    -- Fallback через тулбар
                    try
                        set addBtn to (first button of toolbar 1 of window 1 whose description contains "Добавить" or title contains "Добавить" or description contains "Add" or title contains "Add")
                        click addBtn
                        delay 0.3
                        try
                            click menu item "Apps…" of menu 1 of addBtn
                            set menuSuccess to true
                            set trace to trace & "[AUTO] ✅ Меню Apps вызвано через панель инструментов" & linefeed
                        on error
                            click menu item "Приложения…" of menu 1 of addBtn
                            set menuSuccess to true
                            set trace to trace & "[AUTO] ✅ Меню Приложения вызвано через панель инструментов" & linefeed
                        end try
                    on error errMsg
                        set trace to trace & "[AUTO] ⚠️ Меню Add Apps не было активно: " & errMsg & linefeed
                    end try
                end if
                
                -- Шаг 3: Ожидание появления листа добавления приложений (до 6 секунд)
                set sheetFound to false
                repeat with sLoop from 1 to 25
                    delay 0.25
                    if exists (sheet 1 of window 1) then
                        set sheetFound to true
                        exit repeat
                    end if
                end repeat
                
                if not sheetFound then
                    return trace & "[AUTO] ❌ Панель выбора приложений не появилась"
                end if
                set trace to trace & "[AUTO] ✅ Панель выбора приложений открыта" & linefeed
                
                -- Шаг 4: Ожидание поля поиска и ввод запроса «Restore request <AdamID>»
                set searchDone to false
                repeat with sfLoop from 1 to 20
                    delay 0.25
                    try
                        if exists (text field 1 of sheet 1 of window 1) then
                            set sField to text field 1 of sheet 1 of window 1
                            set value of sField to "\(targetTag)"
                            delay 0.1
                            keystroke return
                            set searchDone to true
                            set trace to trace & "[AUTO] ✅ Введен запрос в поиск: \(targetTag)" & linefeed
                            exit repeat
                        end if
                    end try
                end repeat
                
                if not searchDone then
                    set trace to trace & "[AUTO] ⚠️ Поле поиска не обнаружено" & linefeed
                end if
                
                -- Шаг 5 & 6: Ожидание загрузки покупок в сетке и активации кнопки «Добавить» / «Add» (до 25 секунд)
                set addClicked to false
                repeat with aLoop from 1 to 50
                    delay 0.5
                    try
                        -- Фокус и выделение отфильтрованного приложения
                        if exists (UI element 1 of scroll area 1 of sheet 1 of window 1) then
                            set value of attribute "AXFocused" of (UI element 1 of scroll area 1 of sheet 1 of window 1) to true
                            keystroke "a" using command down
                        else if exists (scroll area 1 of sheet 1 of window 1) then
                            set value of attribute "AXFocused" of (scroll area 1 of sheet 1 of window 1) to true
                            keystroke "a" using command down
                        end if
                        
                        -- Проверка активности кнопки Add / Добавить
                        if (exists button "Add" of sheet 1 of window 1) and (enabled of button "Add" of sheet 1 of window 1) then
                            click (button "Add" of sheet 1 of window 1)
                            key code 36
                            set addClicked to true
                            exit repeat
                        else if (exists button "Добавить" of sheet 1 of window 1) and (enabled of button "Добавить" of sheet 1 of window 1) then
                            click (button "Добавить" of sheet 1 of window 1)
                            key code 36
                            set addClicked to true
                            exit repeat
                        else
                            repeat with btn in (buttons of sheet 1 of window 1)
                                if (name of btn is "Add" or name of btn is "Добавить") and (enabled of btn) then
                                    click btn
                                    key code 36
                                    set addClicked to true
                                    exit repeat
                                end if
                            end repeat
                            if addClicked then exit repeat
                        end if
                    end try
                end repeat
                
                if addClicked then
                    set trace to trace & "[AUTO] 🎉 Кнопка «Добавить» успешно нажата! Загрузка началась." & linefeed
                    -- Ожидание закрытия листа (до 5 секунд)
                    repeat with cLoop from 1 to 20
                        delay 0.25
                        if not (exists sheet 1 of window 1) then exit repeat
                    end repeat
                else
                    set trace to trace & "[AUTO] ⚠️ Кнопка «Добавить» не стала активной за 25 секунд" & linefeed
                end if
            end tell
        end tell
        
        return trace
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var errorInfo: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                let resultDesc = script.executeAndReturnError(&errorInfo)
                if let err = errorInfo {
                    let msg = (err[NSAppleScript.errorMessage] as? String) ?? "\(err)"
                    LogManager.shared.log("❌ Ошибка AppleScript: \(msg)", level: "AUTO")
                    self?.appendLog("Автоматизация: \(msg)")
                } else {
                    let trace = resultDesc.stringValue ?? "Завершено"
                    for line in trace.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        LogManager.shared.log(line, level: "AUTO")
                        if line.contains("✅") || line.contains("🎉") || line.contains("❌") {
                            self?.appendLog(line)
                        }
                    }
                }
            }
        }
    }

    /// Automatically dismisses popup alert modals in Apple Configurator (e.g. "already exists" -> clicks Skip App / Stop)
    public func dismissConfiguratorModals() {
        let script = """
        tell application "Apple Configurator" to activate
        tell application "System Events"
            tell process "Apple Configurator"
                try
                    if exists (sheet 1 of window 1) then
                        if exists (button "Skip App" of sheet 1 of window 1) then
                            click (button "Skip App" of sheet 1 of window 1)
                        else if exists (button "Пропустить" of sheet 1 of window 1) then
                            click (button "Пропустить" of sheet 1 of window 1)
                        else if exists (button "Stop" of sheet 1 of window 1) then
                            click (button "Stop" of sheet 1 of window 1)
                        else if exists (button "Остановить" of sheet 1 of window 1) then
                            click (button "Остановить" of sheet 1 of window 1)
                        else if exists (button "Cancel" of sheet 1 of window 1) then
                            click (button "Cancel" of sheet 1 of window 1)
                        else if exists (button "Отменить" of sheet 1 of window 1) then
                            click (button "Отменить" of sheet 1 of window 1)
                        end if
                    end if
                end try
                try
                    if exists (sheet 1 of sheet 1 of window 1) then
                        if exists (button "Skip App" of sheet 1 of sheet 1 of window 1) then
                            click (button "Skip App" of sheet 1 of sheet 1 of window 1)
                        else if exists (button "Пропустить" of sheet 1 of sheet 1 of window 1) then
                            click (button "Пропустить" of sheet 1 of sheet 1 of window 1)
                        else if exists (button "Stop" of sheet 1 of sheet 1 of window 1) then
                            click (button "Stop" of sheet 1 of sheet 1 of window 1)
                        else if exists (button "Cancel" of sheet 1 of sheet 1 of window 1) then
                            click (button "Cancel" of sheet 1 of sheet 1 of window 1)
                        end if
                    end if
                end try
            end tell
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&err)
            }
        }
    }

    /// Parses binary or XML property lists safely via PropertyListSerialization
    private func parsePlist(atPath path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private func extractItemId(from meta: [String: Any]) -> Int64? {
        if let v = meta["itemId"] as? Int64 { return v }
        if let v = meta["itemId"] as? Int { return Int64(v) }
        if let v = meta["itemId"] as? String, let n = Int64(v) { return n }
        if let v = meta["softwareVersionExternalIdentifier"] as? Int64 { return v }
        if let v = meta["softwareVersionExternalIdentifier"] as? Int { return Int64(v) }
        if let v = meta["softwareVersionExternalIdentifier"] as? String, let n = Int64(v) { return n }
        return nil
    }

    /// Recursively searches `rootDir` for a folder containing `iTunesMetadata.plist`
    /// whose `itemId` (or folder name) matches `adamId`. Returns the folder path or nil.
    private func findIPAFolder(inRoot rootDir: String, adamId: Int64, maxDepth: Int = 5) -> String? {
        guard FileManager.default.fileExists(atPath: rootDir) else { return nil }
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: rootDir),
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let adamStr = String(adamId)

        for case let fileURL as URL in enumerator {
            guard enumerator.level <= maxDepth else { enumerator.skipDescendants(); continue }
            let fileName = fileURL.lastPathComponent

            // 1. Direct directory name match (e.g. .../MobileApps/1467701468)
            if fileName == adamStr || fileName.contains(adamStr) {
                let dir = fileURL.path
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
                    if FileManager.default.fileExists(atPath: dir + "/iTunesMetadata.plist") ||
                       FileManager.default.fileExists(atPath: dir + "/Payload") {
                        LogManager.shared.log("Обнаружена целевая папка по ID: \(dir)", level: "MATCH")
                        return dir
                    }
                }
            }

            // 2. iTunesMetadata.plist file match
            if fileName == "iTunesMetadata.plist" {
                if let meta = parsePlist(atPath: fileURL.path) {
                    let itemId = extractItemId(from: meta)
                    let bundleId = (meta["softwareVersionBundleId"] as? String) ?? ""
                    let appName = (meta["bundleDisplayName"] as? String) ?? (meta["itemName"] as? String) ?? ""

                    if itemId == adamId || (itemId != nil && itemId! > 0 && String(itemId!) == adamStr) {
                        let targetDir = fileURL.deletingLastPathComponent().path
                        LogManager.shared.log("Найдено совпадение в plist: «\(appName)» (\(bundleId), ID: \(itemId ?? 0)) в \(targetDir)", level: "MATCH")
                        return targetDir
                    }
                }
            }
        }
        return nil
    }

    /// Finds any complete IPA file in candidate directory matching adamId.
    private func findIPAInDownloads(downloadsDir: String, adamId: Int64) -> String? {
        guard FileManager.default.fileExists(atPath: downloadsDir) else { return nil }
        guard let enumerator = FileManager.default.enumerator(atPath: downloadsDir) else { return nil }
        let adamStr = String(adamId)

        while let f = enumerator.nextObject() as? String {
            if f.hasSuffix(".ipa") {
                let full = "\(downloadsDir)/\(f)"
                // 1. Quick filename match
                if f.contains(adamStr) {
                    LogManager.shared.log("Найден готовый IPA по имени файла: \(full)", level: "MATCH")
                    return full
                }

                // 2. Unzip check
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                task.arguments = ["-p", full, "iTunesMetadata.plist"]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()
                if (try? task.run()) != nil {
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if !data.isEmpty,
                       let meta = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                        if let itemId = extractItemId(from: meta), itemId == adamId {
                            LogManager.shared.log("Найден готовый IPA по содержимому архива: \(full)", level: "MATCH")
                            return full
                        }
                    }
                }
            }
        }
        return nil
    }

    public func watchAndCapture(adamId: Int64, knownName: String = "", timeout: TimeInterval = 600.0) async throws -> IPAResult {
        let home = NSHomeDirectory()
        let configuratorBase = "\(home)/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches"
        let tempItemsDir = "\(configuratorBase)/Assets/TemporaryItems"
        let downloadsDir = "\(configuratorBase)/Downloads"
        let mobileAppsDir = "\(tempItemsDir)/MobileApps"
        let systemTemp = NSTemporaryDirectory()
        let outputDir = Self.libraryDir
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(atPath: mobileAppsDir, withIntermediateDirectories: true, attributes: nil)

        appendLog("🔍 Запуск мониторинга кэшей Configurator (Adam ID: \(adamId))...")
        LogManager.shared.log("Пути поиска:\n  - TemporaryItems: \(tempItemsDir)\n  - MobileApps: \(mobileAppsDir)\n  - Downloads: \(downloadsDir)\n  - SystemTemp: \(systemTemp)", level: "WATCH")

        // Clean any stale folders in MobileApps before watching
        if let stale = try? FileManager.default.contentsOfDirectory(atPath: mobileAppsDir) {
            for s in stale {
                if !s.hasPrefix(".") {
                    try? FileManager.default.removeItem(atPath: "\(mobileAppsDir)/\(s)")
                }
            }
        }

        DispatchQueue.main.async {
            self.operationProgress = 0.15
            self.operationStage = "Ожидание загрузки от серверов Apple (сканирую Configurator)..."
            self.downloadedSizeMB = 0.0
        }

        let start = Date()
        var foundFolder: String? = nil
        var foundReadyIPA: String? = nil
        var lastDiagnosticLogTime: Date = Date()

        // --- Phase 1: Scan for matching folder or pre-packaged IPA ---
        while Date().timeIntervalSince(start) < timeout {
            let elapsed = Int(Date().timeIntervalSince(start))

            // 1a. Any active download session folder (UUID or ID) appearing in MobileApps/
            if let mobileAppsItems = try? FileManager.default.contentsOfDirectory(atPath: mobileAppsDir),
               !mobileAppsItems.isEmpty {
                for item in mobileAppsItems {
                    if item.hasPrefix(".") { continue }
                    let itemPath = "\(mobileAppsDir)/\(item)"
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                        foundFolder = itemPath
                        LogManager.shared.log("⚡ Обнаружена активная сессия загрузки Configurator в MobileApps: \(itemPath)", level: "FOUND")
                        break
                    }
                }
                if foundFolder != nil { break }
            }

            // 1b. Scan all of TemporaryItems recursively
            if let found = findIPAFolder(inRoot: tempItemsDir, adamId: adamId) {
                foundFolder = found
                break
            }

            // 1c. Scan system temp directory
            if let found = findIPAFolder(inRoot: systemTemp, adamId: adamId, maxDepth: 3) {
                foundFolder = found
                break
            }

            // 1d. Check Downloads cache
            if let readyIPA = findIPAInDownloads(downloadsDir: downloadsDir, adamId: adamId) {
                foundReadyIPA = readyIPA
                break
            }

            // Diagnostic logging every 3 seconds
            if Date().timeIntervalSince(lastDiagnosticLogTime) >= 3.0 {
                lastDiagnosticLogTime = Date()
                let tempContents = (try? FileManager.default.contentsOfDirectory(atPath: tempItemsDir)) ?? []
                let mobileAppsContents = (try? FileManager.default.contentsOfDirectory(atPath: mobileAppsDir)) ?? []
                let dlContents = (try? FileManager.default.contentsOfDirectory(atPath: downloadsDir)) ?? []

                LogManager.shared.log("⏳ [Мониторинг \(elapsed)с] TemporaryItems: \(tempContents.count) об., MobileApps: \(mobileAppsContents.count) об. (\(mobileAppsContents.joined(separator: ", "))), Downloads: \(dlContents.count) об. (\(dlContents.joined(separator: ", ")))", level: "SCAN")

                DispatchQueue.main.async {
                    self.operationStage = "Ожидание загрузки Apple Configurator (\(elapsed)с)..."
                }
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
        }

        // --- If we found a ready IPA in Downloads, copy it directly ---
        if let readyIPA = foundReadyIPA {
            appendLog("✅ Найден готовый IPA в кэше Configurator: \(readyIPA)")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            task.arguments = ["-p", readyIPA, "iTunesMetadata.plist"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try? task.run(); task.waitUntilExit()
            let metaData = pipe.fileHandleForReading.readDataToEndOfFile()
            let metaDict = (try? PropertyListSerialization.propertyList(from: metaData, format: nil) as? [String: Any]) ?? [:]
            var appName = (metaDict["bundleDisplayName"] as? String) ?? (metaDict["itemName"] as? String) ?? knownName
            if appName.isEmpty { appName = "App_\(adamId)" }
            let bundleId = (metaDict["softwareVersionBundleId"] as? String) ?? "app"
            let version = (metaDict["bundleShortVersionString"] as? String) ?? "1.0"
            let sanitizedName = appName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
            let outPath = "\(outputDir)/\(adamId)-\(sanitizedName).ipa"
            try? FileManager.default.copyItem(atPath: readyIPA, toPath: outPath)
            let size = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
            DispatchQueue.main.async {
                self.operationProgress = 1.0
                self.operationStage = "IPA успешно сохранён в библиотеку!"
            }
            return IPAResult(path: outPath, appName: appName, bundleId: bundleId, version: version, sha256: "", size: size, hasFairPlay: true)
        }

        guard let targetFolder = foundFolder else {
            let errMsg = "Превышено время ожидания загрузки (ID: \(adamId)). Логи записаны в журнал отладки."
            LogManager.shared.log("❌ Ошибка тайм-аута. Ни в одном каталоге не обнаружено скачанных файлов для ID \(adamId)", level: "TIMEOUT")
            throw NSError(domain: "OpenRestore", code: 4, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }

        appendLog("📦 Зафиксирован активный каталог загрузки: \(targetFolder)")
        LogManager.shared.log("Начало отслеживания завершения загрузки в \(targetFolder)", level: "DOWNLOAD")

        // --- Phase 2: Wait for download to stabilize (size stops growing) ---
        var lastSize: Int64 = 0
        var stableCycles = 0

        for cycle in 0..<240 { // max 240 × 0.5s = 2 minutes
            var currentFolderSize: Int64 = 0
            if let subEnum = FileManager.default.enumerator(atPath: targetFolder) {
                while let file = subEnum.nextObject() as? String {
                    let fPath = "\(targetFolder)/\(file)"
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fPath),
                       let sz = attrs[.size] as? Int64 {
                        currentFolderSize += sz
                    }
                }
            }

            let mb = Double(currentFolderSize) / (1024.0 * 1024.0)
            DispatchQueue.main.async {
                self.downloadedSizeMB = mb
                self.operationProgress = min(0.88, 0.2 + (mb / 150.0) * 0.65)
                self.operationStage = String(format: "Загрузка с серверов Apple: %.1f МБ", mb)
            }

            if cycle % 6 == 0 {
                LogManager.shared.log("Размер загрузки: \(String(format: "%.2f", mb)) МБ (стабильных циклов: \(stableCycles))", level: "PROGRESS")
            }

            if currentFolderSize > 0 && currentFolderSize == lastSize {
                stableCycles += 1
                if stableCycles >= 3 {
                    LogManager.shared.log("Загрузка стабилизировалась. Итоговый размер: \(String(format: "%.2f", mb)) МБ", level: "STABLE")
                    self.dismissConfiguratorModals()
                    break
                }
            } else {
                stableCycles = 0
                lastSize = currentFolderSize
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        DispatchQueue.main.async {
            self.operationProgress = 0.90
            self.operationStage = "Упаковка официального IPA (FairPlay DRM)..."
        }

        // --- Phase 3: Package into IPA ---
        let fm = FileManager.default
        var foundIPAs: [String] = []
        var foundPayloads: [String] = []
        var foundAppBundles: [String] = []
        var foundMetaPlists: [String] = []

        if let enumerator = fm.enumerator(atPath: targetFolder) {
            while let item = enumerator.nextObject() as? String {
                if item.hasPrefix("._") || item.contains("/._") { continue }
                let fullPath = "\(targetFolder)/\(item)"
                if item.hasSuffix(".ipa") {
                    foundIPAs.append(fullPath)
                } else if item == "Payload" || item.hasSuffix("/Payload") {
                    foundPayloads.append(fullPath)
                } else if item.hasSuffix(".app") && !item.contains("/Payload/") {
                    foundAppBundles.append(fullPath)
                } else if item == "iTunesMetadata.plist" || item.hasSuffix("/iTunesMetadata.plist") {
                    foundMetaPlists.append(fullPath)
                }
            }
        }

        let targetItems = (try? fm.contentsOfDirectory(atPath: targetFolder)) ?? []
        LogManager.shared.log("Структура каталога \(targetFolder): \(targetItems.joined(separator: ", ")) (найдено IPAs: \(foundIPAs.count), Payloads: \(foundPayloads.count), Apps: \(foundAppBundles.count))", level: "PACKAGE")

        let metaPath = foundMetaPlists.first ?? "\(targetFolder)/iTunesMetadata.plist"
        let metaDict = parsePlist(atPath: metaPath) ?? [:]

        var appName = (metaDict["bundleDisplayName"] as? String) ?? (metaDict["itemName"] as? String) ?? ""
        var bundleId = (metaDict["softwareVersionBundleId"] as? String) ?? ""
        var version = (metaDict["bundleShortVersionString"] as? String) ?? ""

        // Fallback to Payload/*.app/Info.plist if iTunesMetadata.plist is missing or incomplete
        if appName.isEmpty || bundleId.isEmpty {
            for payloadDir in foundPayloads {
                if let appFiles = try? fm.contentsOfDirectory(atPath: payloadDir) {
                    if let appBundle = appFiles.first(where: { $0.hasSuffix(".app") && !$0.hasPrefix("._") }) {
                        let infoPlistPath = "\(payloadDir)/\(appBundle)/Info.plist"
                        if let infoDict = parsePlist(atPath: infoPlistPath) {
                            if appName.isEmpty {
                                appName = (infoDict["CFBundleDisplayName"] as? String) ?? (infoDict["CFBundleName"] as? String) ?? appBundle.replacingOccurrences(of: ".app", with: "")
                            }
                            if bundleId.isEmpty {
                                bundleId = (infoDict["CFBundleIdentifier"] as? String) ?? ""
                            }
                            if version.isEmpty {
                                version = (infoDict["CFBundleShortVersionString"] as? String) ?? (infoDict["CFBundleVersion"] as? String) ?? "1.0"
                            }
                        }
                    }
                }
            }
        }

        // Fallback to any found *.app bundle
        if appName.isEmpty || bundleId.isEmpty {
            for appPath in foundAppBundles {
                let infoPlistPath = "\(appPath)/Info.plist"
                if let infoDict = parsePlist(atPath: infoPlistPath) {
                    if appName.isEmpty {
                        appName = (infoDict["CFBundleDisplayName"] as? String) ?? (infoDict["CFBundleName"] as? String) ?? URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
                    }
                    if bundleId.isEmpty {
                        bundleId = (infoDict["CFBundleIdentifier"] as? String) ?? ""
                    }
                    if version.isEmpty {
                        version = (infoDict["CFBundleShortVersionString"] as? String) ?? (infoDict["CFBundleVersion"] as? String) ?? "1.0"
                    }
                }
            }
        }

        if (appName.isEmpty || appName.hasPrefix("App_")) && !knownName.isEmpty {
            appName = knownName
        }
        if appName.isEmpty { appName = "App_\(adamId)" }
        if bundleId.isEmpty { bundleId = "com.apple.app.\(adamId)" }
        if version.isEmpty { version = "1.0" }

        let sanitizedName = appName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        let outPath = "\(outputDir)/\(adamId)-\(sanitizedName).ipa"

        LogManager.shared.log("Упаковка IPA: «\(appName)» (\(bundleId) v\(version)) -> \(outPath)", level: "PACKAGE")

        // 1. Direct .ipa file found anywhere in directory tree
        if let directIPA = foundIPAs.first {
            try? fm.removeItem(atPath: outPath)
            try? fm.copyItem(atPath: directIPA, toPath: outPath)
            LogManager.shared.log("Скопирован официальный IPA: \(directIPA)", level: "PACKAGE")
        }
        // 2. Payload folder exists
        else if let payloadDir = foundPayloads.first {
            let parentDir = URL(fileURLWithPath: payloadDir).deletingLastPathComponent().path
            try? fm.removeItem(atPath: outPath)
            let dittoProc = Process()
            dittoProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            dittoProc.arguments = ["-c", "-k", "--keepParent", "Payload", outPath]
            dittoProc.currentDirectoryURL = URL(fileURLWithPath: parentDir)
            try? dittoProc.run()
            dittoProc.waitUntilExit()

            let metaInParent = "\(parentDir)/iTunesMetadata.plist"
            if fm.fileExists(atPath: metaInParent) {
                let zipProc = Process()
                zipProc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                zipProc.arguments = ["-q", "-u", outPath, "iTunesMetadata.plist"]
                zipProc.currentDirectoryURL = URL(fileURLWithPath: parentDir)
                try? zipProc.run()
                zipProc.waitUntilExit()
            }
        }
        // 3. *.app bundle found (no Payload parent)
        else if let appPath = foundAppBundles.first {
            let stageDir = "\(NSTemporaryDirectory())OpenRestore_Stage_\(UUID().uuidString)"
            let payloadDir = "\(stageDir)/Payload"
            let appNameOnly = URL(fileURLWithPath: appPath).lastPathComponent
            try? fm.createDirectory(atPath: payloadDir, withIntermediateDirectories: true, attributes: nil)
            try? fm.copyItem(atPath: appPath, toPath: "\(payloadDir)/\(appNameOnly)")
            if fm.fileExists(atPath: metaPath) {
                try? fm.copyItem(atPath: metaPath, toPath: "\(stageDir)/iTunesMetadata.plist")
            }

            try? fm.removeItem(atPath: outPath)
            let dittoProc = Process()
            dittoProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            dittoProc.arguments = ["-c", "-k", "--keepParent", "Payload", outPath]
            dittoProc.currentDirectoryURL = URL(fileURLWithPath: stageDir)
            try? dittoProc.run()
            dittoProc.waitUntilExit()

            if fm.fileExists(atPath: "\(stageDir)/iTunesMetadata.plist") {
                let zipProc = Process()
                zipProc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                zipProc.arguments = ["-q", "-u", outPath, "iTunesMetadata.plist"]
                zipProc.currentDirectoryURL = URL(fileURLWithPath: stageDir)
                try? zipProc.run()
                zipProc.waitUntilExit()
            }
            try? fm.removeItem(atPath: stageDir)
        }
        // 4. Fallback: Archive entire directory
        else {
            try? fm.removeItem(atPath: outPath)
            let dittoProc = Process()
            dittoProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            dittoProc.arguments = ["-c", "-k", targetFolder, outPath]
            try? dittoProc.run()
            dittoProc.waitUntilExit()
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int64) ?? 0
        LogManager.shared.log("🎉 IPA собран! Размер: \(size) байт (\(String(format: "%.1f", Double(size)/(1024*1024))) МБ). Путь: \(outPath)", level: "SUCCESS")

        DispatchQueue.main.async {
            self.operationProgress = 1.0
            self.operationStage = "IPA успешно сохранён в библиотеку!"
        }

        self.dismissConfiguratorModals()

        return IPAResult(
            path: outPath,
            appName: appName,
            bundleId: bundleId,
            version: version,
            sha256: "",
            size: size,
            hasFairPlay: true
        )
    }


    public func installApp(ipaPath: String, bundleId: String = "", udid: String = "") async -> (Bool, String) {
        let appFilename = URL(fileURLWithPath: ipaPath).lastPathComponent
        LogManager.shared.log("🚀 Начало автономной установки «\(appFilename)»...", level: "INSTALL")
        appendLog("🚀 Установка «\(appFilename)» на устройство...")

        DispatchQueue.main.async {
            self.operationProgress = 0.2
            self.operationStage = "Проверка пакета «\(appFilename)»..."
        }

        let iosBin = StandaloneToolchain.shared.iosBinaryPath
        let targetUdid = !udid.isEmpty ? udid : (activeDevice?.udid ?? "")

        if FileManager.default.isExecutableFile(atPath: iosBin) {
            DispatchQueue.main.async {
                self.operationProgress = 0.6
                self.operationStage = "Прямая установка через go-ios (installation_proxy)..."
            }
            appendLog("📲 Передача приложения в системный сервис iOS...")

            var args = ["install", "--path=\(ipaPath)"]
            if !targetUdid.isEmpty {
                args.append("--udid=\(targetUdid)")
            }
            
            let onProgress: (String) -> Void = { str in
                if let pStr = str.components(separatedBy: "%").first?.components(separatedBy: " ").last {
                    let cleanPStr = pStr.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    if let pct = Double(cleanPStr) {
                        DispatchQueue.main.async {
                            // Installation maps from 0.7 to 1.0 progress
                            self.operationProgress = 0.7 + (pct / 100.0) * 0.3
                            self.operationStage = "Установка... \(Int(pct))%"
                        }
                    }
                }
            }

            let (status, data) = Self.runProcessWithLiveOutput(executable: iosBin, arguments: args, timeout: 600.0, onOutput: onProgress)
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            do {
                let procTerminationStatus = status

                DispatchQueue.main.async {
                    self.operationProgress = 1.0
                    self.operationStage = procTerminationStatus == 0 ? "Установка завершена успешно!" : "Ошибка установки"
                }

                if procTerminationStatus == 0 {
                    LogManager.shared.log("🎉 «\(appFilename)» успешно установлено через go-ios!", level: "INSTALL")
                    appendLog("🎉 «\(appFilename)» успешно установлено на iPhone!")
                    return (true, "Приложение успешно установлено на iPhone!")
                } else {
                    LogManager.shared.log("❌ Ошибка установки go-ios: \(output)", level: "INSTALL")
                    appendLog("❌ Ошибка: \(output)")
                    return (false, output.isEmpty ? "Ошибка установки" : output)
                }
            } catch {
                LogManager.shared.log("❌ Ошибка запуска go-ios: \(error.localizedDescription)", level: "INSTALL")
                appendLog("❌ Ошибка: \(error.localizedDescription)")
                return (false, error.localizedDescription)
            }
        }

        let coreScript = "\(Self.workDir)/ios_core.py"
        if FileManager.default.isExecutableFile(atPath: coreScript) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: coreScript)
            proc.arguments = ["install", ipaPath]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            if (try? proc.run()) != nil {
                DispatchQueue.main.async {
                    self.operationProgress = 0.85
                    self.operationStage = "Установка и регистрация приложения на iOS..."
                }
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = dict["success"] as? Bool {
                    let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? ""
                    DispatchQueue.main.async {
                        self.operationProgress = 1.0
                        self.operationStage = success ? "Установка завершена успешно!" : "Ошибка установки"
                    }
                    if success {
                        LogManager.shared.log("🎉 «\(appFilename)» успешно установлено на iPhone!", level: "INSTALL")
                        appendLog("🎉 «\(appFilename)» успешно установлено на iPhone!")
                        return (true, "Приложение успешно установлено на iPhone!")
                    } else {
                        LogManager.shared.log("❌ Ошибка установки «\(appFilename)»: \(msg)", level: "INSTALL")
                        appendLog("❌ Ошибка: \(msg)")
                        return (false, msg.isEmpty ? "Ошибка установки" : msg)
                    }
                }
            }
        }

        return (false, "Утилита установки не найдена")
    }

    public func uninstallApp(bundleId: String) async -> (Bool, String) {
        let iosBin = StandaloneToolchain.shared.iosBinaryPath
        let targetUdid = activeDevice?.udid ?? ""

        if FileManager.default.isExecutableFile(atPath: iosBin) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: iosBin)
            var args = ["uninstall", bundleId]
            if !targetUdid.isEmpty {
                args.append("--udid=\(targetUdid)")
            }
            proc.arguments = args
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                return (proc.terminationStatus == 0, "Приложение удалено")
            }
        }

        let coreScript = Self.workDir + "/ios_core.py"
        guard FileManager.default.fileExists(atPath: coreScript) else { return (false, "ios_core.py не найден") }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["uninstall", bundleId]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        guard (try? proc.run()) != nil else { return (false, "Не удалось запустить удаление") }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = dict["success"] as? Bool {
            let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? ""
            return (success, msg)
        }
        return (proc.terminationStatus == 0, "Приложение удалено с устройства")
    }

    public static let ipatoolPassphrase = "openrestore_passphrase_v1"

    public func downloadDirectAppStore(adamId: Int64, name: String) async -> (Bool, String, String?) {
        let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
        let outputDir = Self.libraryDir
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)

        DispatchQueue.main.async {
            self.operationProgress = 0.3
            self.operationStage = "Прямая загрузка «\(name)» с серверов Apple..."
        }

        guard FileManager.default.isExecutableFile(atPath: ipatoolBin) else {
            return (false, "Инструмент загрузки ipatool не найден", nil)
        }

        let onProgress: (String) -> Void = { str in
            if let p = str.components(separatedBy: "%").first?.components(separatedBy: " ").last, let pct = Double(p) {
                DispatchQueue.main.async {
                    self.operationProgress = 0.3 + (pct / 100.0) * 0.4
                    self.operationStage = "Загрузка... \(Int(pct))%"
                }
            }
        }

        // Try download directly (works for purchased/delisted apps)
        var args = ["download", "--app-id", "\(adamId)", "-o", outputDir, "--format", "json", "--keychain-passphrase", Self.ipatoolPassphrase]
        var (status, data) = Self.runProcessWithLiveOutput(executable: ipatoolBin, arguments: args, timeout: 1200.0, onOutput: onProgress)
        var rawOut = String(data: data, encoding: .utf8) ?? ""

        if status != 0 && (rawOut.contains("license") || rawOut.contains("purchase") || rawOut.contains("buy") || rawOut.contains("failed to get license") || rawOut.contains("purchased\":false")) {
            args = ["download", "--app-id", "\(adamId)", "--purchase", "-o", outputDir, "--format", "json", "--keychain-passphrase", Self.ipatoolPassphrase]
            (status, data) = Self.runProcessWithLiveOutput(executable: ipatoolBin, arguments: args, timeout: 1200.0, onOutput: onProgress)
            rawOut = String(data: data, encoding: .utf8) ?? ""
        }

        if status == 0 {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: outputDir)) ?? []
            let ipaFiles = files.filter { $0.hasSuffix(".ipa") }

            var matchedFile: String? = ipaFiles.first { $0.contains(String(adamId)) }

            if matchedFile == nil {
                for line in rawOut.components(separatedBy: "\n") {
                    if line.contains(".ipa") {
                        for word in line.components(separatedBy: " ") {
                            let cleanWord = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\r\n[]"))
                            if cleanWord.hasSuffix(".ipa") && FileManager.default.fileExists(atPath: cleanWord) {
                                matchedFile = cleanWord
                                break
                            }
                        }
                    }
                }
            }

            if matchedFile == nil {
                let sortedIPAs = ipaFiles.compactMap { f -> (String, Date)? in
                    let p = "\(outputDir)/\(f)"
                    guard let attr = try? FileManager.default.attributesOfItem(atPath: p),
                          let mod = attr[.modificationDate] as? Date else { return nil }
                    return (p, mod)
                }.sorted { $0.1 > $1.1 }

                if let newest = sortedIPAs.first, newest.1.timeIntervalSinceNow > -300 {
                    matchedFile = newest.0
                }
            }

            if let m = matchedFile {
                let initialPath = m.hasPrefix("/") ? m : "\(outputDir)/\(m)"
                let safeName = name.replacingOccurrences(of: "/", with: "_").trimmingCharacters(in: .whitespaces)
                let standardizedTarget = "\(outputDir)/\(adamId)-\(safeName).ipa"

                var finalPath = initialPath
                if initialPath != standardizedTarget {
                    try? FileManager.default.removeItem(atPath: standardizedTarget)
                    if (try? FileManager.default.moveItem(atPath: initialPath, toPath: standardizedTarget)) != nil {
                        finalPath = standardizedTarget
                    }
                }

                DispatchQueue.main.async {
                    self.operationProgress = 1.0
                    self.operationStage = "Загрузка «\(name)» завершена!"
                }
                return (true, "Загружено успешно", finalPath)
            }
            return (true, "Загружено", nil)
        }

        var userFriendlyErr = rawOut
        let lower = rawOut.lowercased()
        if lower.contains("auth code is required") || lower.contains("auth code") || lower.contains("auth-code") || lower.contains("2fa") || lower.contains("verification") || lower.contains("keyring") || lower.contains("account") || lower.contains("unauthorized") || lower.contains("sign in") || lower.contains("login") {
            return (false, "AUTH_REQUIRED: Требуется вход в Apple ID (код подтверждения 2FA). Нажмите на профиль Apple ID в меню слева и выполните вход.", nil)
        } else if lower.contains("failed to purchase") || lower.contains("license") {
            userFriendlyErr = "Приложение не найдено в покупках данного Apple ID или недоступно в этом регионе."
        } else if lower.contains("item is unavailable") || lower.contains("temporarily unavailable") {
            userFriendlyErr = "Приложение временно недоступно на серверах Apple"
        }

        return (false, userFriendlyErr.isEmpty ? "Ошибка прямой загрузки App Store" : userFriendlyErr, nil)
    }

    public func refreshAppleIdStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
            var isDirectAuth = false
            var directEmail = ""
            var directName = ""
            var directDsid = ""

            if FileManager.default.isExecutableFile(atPath: ipatoolBin) {
                let (status, data) = Self.runProcessWithSafeOutput(executable: ipatoolBin, arguments: ["auth", "info", "--format", "json", "--non-interactive", "--keychain-passphrase", Self.ipatoolPassphrase], timeout: 12.0)
                let rawOut = String(data: data, encoding: .utf8) ?? ""
                if status == 0 && !rawOut.contains("failed to get account") && !rawOut.contains("could not be found"),
                   let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    let email = (dict["email"] as? String) ?? (dict["apple_id"] as? String) ?? ""
                    let name = (dict["name"] as? String) ?? email.components(separatedBy: "@").first ?? ""
                    let dsidNum = dict["dsid"]
                    let dsidStr = dsidNum != nil ? "\(dsidNum!)" : ""

                    if !email.isEmpty {
                        isDirectAuth = true
                        directEmail = email
                        directName = name
                        directDsid = dsidStr
                    }
                }
            }


            DispatchQueue.main.async {
                DispatchQueue.main.async { self.isDirectAppleIdAuthenticated = isDirectAuth }
                if isDirectAuth {
                    DispatchQueue.main.async { self.activeAppleIdEmail = directEmail }
                    DispatchQueue.main.async { self.activeAppleIdName = directName }
                    DispatchQueue.main.async { self.currentAccountDsid = directDsid }
                    DispatchQueue.main.async { self.isAppleIdAuthenticated = true }
                    UserDefaults.standard.set(true, forKey: "isDirectAppleIdAuthenticated")
                    UserDefaults.standard.set(directEmail, forKey: "savedAppleIdEmail")
                    UserDefaults.standard.set(directName, forKey: "savedAppleIdName")
                    UserDefaults.standard.set(directDsid, forKey: "savedAppleIdDsid")
                } else {
                    DispatchQueue.main.async { self.isDirectAppleIdAuthenticated = false }
                    DispatchQueue.main.async { self.isAppleIdAuthenticated = false }
                    DispatchQueue.main.async { self.activeAppleIdEmail = "" }
                    DispatchQueue.main.async { self.activeAppleIdName = "" }
                    UserDefaults.standard.set(false, forKey: "isDirectAppleIdAuthenticated")
                    UserDefaults.standard.removeObject(forKey: "savedAppleIdEmail")
                    UserDefaults.standard.removeObject(forKey: "savedAppleIdName")
                    UserDefaults.standard.removeObject(forKey: "savedAppleIdDsid")
                }
            }
        }
    }

    public func openConfiguratorAccountDialog() {
        openConfigurator()
    }

    public func loginAppleId(email: String, password: String, code: String? = nil) async -> (Bool, Bool, String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            return (false, false, "Введите email и пароль Apple ID")
        }

        let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
        guard FileManager.default.isExecutableFile(atPath: ipatoolBin) else {
            return (false, false, "Бинарник ipatool не найден: \(ipatoolBin)")
        }

        var args = ["auth", "login", "--email", trimmedEmail, "--password", password, "--non-interactive", "--keychain-passphrase", Self.ipatoolPassphrase]
        if let c = code, !c.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(contentsOf: ["--auth-code", c.trimmingCharacters(in: .whitespaces)])
        }

        // GrandSlam / Anisette initialization + 2FA challenge may take up to 45-60s on slower networks
        let (loginStatus, data) = Self.runProcessWithSafeOutput(executable: ipatoolBin, arguments: args, timeout: 90.0)
        let outStr = String(data: data, encoding: .utf8) ?? ""
        let lower = outStr.lowercased()

        // 1. Verify if user is truly logged in via ipatool auth info
        let (infoStatus, infoData) = Self.runProcessWithSafeOutput(executable: ipatoolBin, arguments: ["auth", "info", "--format", "json", "--non-interactive", "--keychain-passphrase", Self.ipatoolPassphrase], timeout: 12.0)
        var isReallyAuth = false
        var directName = ""
        var directDsid = ""

        if infoStatus == 0,
           let dict = (try? JSONSerialization.jsonObject(with: infoData)) as? [String: Any] {
            let authEmail = (dict["email"] as? String) ?? (dict["apple_id"] as? String) ?? ""
            if !authEmail.isEmpty {
                isReallyAuth = true
                directName = (dict["name"] as? String) ?? authEmail.components(separatedBy: "@").first ?? ""
                let dsidNum = dict["dsid"]
                directDsid = dsidNum != nil ? "\(dsidNum!)" : ""
            }
        }

        if isReallyAuth && loginStatus == 0 {
            DispatchQueue.main.async {
                DispatchQueue.main.async { self.isDirectAppleIdAuthenticated = true }
                DispatchQueue.main.async { self.isAppleIdAuthenticated = true }
                DispatchQueue.main.async { self.activeAppleIdEmail = trimmedEmail }
                DispatchQueue.main.async { self.activeAppleIdName = directName }
                DispatchQueue.main.async { self.currentAccountDsid = directDsid }
                UserDefaults.standard.set(true, forKey: "isDirectAppleIdAuthenticated")
                UserDefaults.standard.set(trimmedEmail, forKey: "savedAppleIdEmail")
                UserDefaults.standard.set(directName, forKey: "savedAppleIdName")
                UserDefaults.standard.set(directDsid, forKey: "savedAppleIdDsid")
            }
            self.refreshPurchasedApps()
            return (true, false, "Вход выполнен успешно!")
        }

        // 2. Check for Wrong Password / Invalid Account / Disabled Account (Do NOT show 2FA input!)
        if lower.contains("account is disabled") || lower.contains("invalid credentials") ||
           lower.contains("password is incorrect") || lower.contains("bad credentials") ||
           lower.contains("authentication failed") || lower.contains("bad login") ||
           lower.contains("passwordexpired") || lower.contains("unauthorized") {
            return (false, false, "Неверный логин или пароль Apple ID. Проверьте правильность и повторите попытку.")
        }

        // 3. Check for 2FA Code Required or 2FA Error
        let is2FARequiredMatch = lower.contains("2fa") || lower.contains("code") || lower.contains("verification") ||
                                 lower.contains("auth-code") || lower.contains("auth_code") || lower.contains("challenge") ||
                                 lower.contains("second factor") || lower.contains("second-factor") ||
                                 lower.contains("two-factor") || lower.contains("two_factor") ||
                                 lower.contains("security code") || lower.contains("passcode") ||
                                 lower.contains("trusted device") || lower.contains("enter code") || lower.contains("sms")

        if is2FARequiredMatch {
            if code != nil && !code!.trimmingCharacters(in: .whitespaces).isEmpty {
                return (false, true, "Неверный проверочный код 2FA. Нажмите «Запросить новый код», если код устарел.")
            }
            return (false, true, "Код подтверждения отправлен на ваши устройства Apple. Введите 6-значный код 2FA.")
        }

        let cleanErr = outStr.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return (false, false, cleanErr.isEmpty ? "Ошибка входа в Apple ID. Проверьте правильность введенных данных." : cleanErr)
    }

    public func logoutAppleId() async -> Bool {
        let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
        if FileManager.default.isExecutableFile(atPath: ipatoolBin) {
            _ = Self.runProcessWithSafeOutput(executable: ipatoolBin, arguments: ["auth", "revoke", "--non-interactive", "--keychain-passphrase", Self.ipatoolPassphrase], timeout: 12.0)
        }
        try? FileManager.default.removeItem(atPath: Self.purchasesCachePath)
        DispatchQueue.main.async {
            DispatchQueue.main.async { self.isAppleIdAuthenticated = false }
            DispatchQueue.main.async { self.isDirectAppleIdAuthenticated = false }
            DispatchQueue.main.async { self.activeAppleIdEmail = "" }
            DispatchQueue.main.async { self.activeAppleIdName = "" }
            DispatchQueue.main.async { self.currentAccountDsid = "" }
            DispatchQueue.main.async { self.purchasedApps = [] }
            DispatchQueue.main.async { self.totalPurchasedAppsCount = 0 }
            UserDefaults.standard.removeObject(forKey: "isDirectAppleIdAuthenticated")
            UserDefaults.standard.removeObject(forKey: "savedAppleIdEmail")
            UserDefaults.standard.removeObject(forKey: "savedAppleIdName")
            UserDefaults.standard.removeObject(forKey: "savedAppleIdDsid")
        }
        return true
    }

    public func purchaseAppLicense(bundleId: String) async -> (Bool, String) {
        let ipatoolBin = StandaloneToolchain.shared.ipatoolBinaryPath
        if FileManager.default.isExecutableFile(atPath: ipatoolBin) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ipatoolBin)
            proc.arguments = ["purchase", "-b", bundleId]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    return (true, "Лицензия успешно получена")
                } else if !out.isEmpty {
                    return (false, out)
                }
            }
        }

        let coreScript = Self.workDir + "/ios_core.py"
        if FileManager.default.fileExists(atPath: coreScript) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: coreScript)
            proc.arguments = ["purchase", bundleId]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = dict["success"] as? Bool {
                    let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? ""
                    return (success, msg)
                }
            }
        }

        return (false, "Не удалось получить лицензию")
    }

    // MARK: - Smart Analytics & Install Tracking

    public func recordAppInstallation(adamId: Int64, bundleId: String = "", name: String = "") {
        guard adamId > 0 else { return }
        var counts = UserDefaults.standard.dictionary(forKey: "app_install_counts") as? [String: Int] ?? [:]
        let key = String(adamId)
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: "app_install_counts")

        if !name.isEmpty {
            var names = UserDefaults.standard.dictionary(forKey: "app_install_names") as? [String: String] ?? [:]
            names[key] = name
            UserDefaults.standard.set(names, forKey: "app_install_names")
        }
        LogManager.shared.log("📊 Зафиксирована установка «\(name)» (Adam ID: \(adamId)). Всего установок: \(counts[key] ?? 1)", level: "ANALYTICS")
    }

    public func getInstallCount(adamId: Int64) -> Int {
        guard adamId > 0 else { return 0 }
        let counts = UserDefaults.standard.dictionary(forKey: "app_install_counts") as? [String: Int] ?? [:]
        return counts[String(adamId)] ?? 0
    }

    // MARK: - Software Updates Engine

    @MainActor
    public func checkForUpdates(currentVersion: String? = nil) async -> (AppUpdateInfo?, String?) {
        let actualVersion = currentVersion ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.1")
        self.isCheckingUpdates = true
        self.updateCheckError = nil

        defer {
            self.isCheckingUpdates = false
        }

        guard let url = URL(string: "https://api.github.com/repos/ShavlaK/OpenRestore/releases/latest") else {
            return (nil, "Неверный URL обновлений")
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (nil, "Ошибка сети при проверке обновлений")
            }

            if httpResponse.statusCode == 404 {
                let info = AppUpdateInfo(
                    id: "v1.6.1",
                    version: "v1.6.1",
                    title: "Open Store v1.6.1",
                    releaseNotes: "У вас установлена самая свежая версия программы.",
                    downloadUrl: nil,
                    publishedAt: "",
                    isNewer: false
                )
                self.latestUpdateInfo = info
                return (info, nil)
            }

            guard httpResponse.statusCode == 200 else {
                let err = "Ошибка сервера GitHub (\(httpResponse.statusCode))"
                self.updateCheckError = err
                return (nil, err)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                let err = "Не удалось разобрать данные релиза"
                self.updateCheckError = err
                return (nil, err)
            }

            let releaseName = (json["name"] as? String) ?? tagName
            let body = (json["body"] as? String) ?? ""
            let pubDate = (json["published_at"] as? String) ?? ""

            #if arch(arm64)
            let isArm64 = true
            #else
            let isArm64 = false
            #endif

            var archZipUrl: String? = nil
            var universalZipUrl: String? = nil
            var generalZipUrl: String? = nil
            var dmgUrl: String? = nil

            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let aName = asset["name"] as? String, let dUrl = asset["browser_download_url"] as? String {
                        let lower = aName.lowercased()
                        if lower.hasSuffix(".zip") {
                            if isArm64 && (lower.contains("applesilicon") || lower.contains("arm64")) {
                                archZipUrl = dUrl
                            } else if !isArm64 && (lower.contains("intel") || lower.contains("x86_64")) {
                                archZipUrl = dUrl
                            } else if lower.contains("macos") || lower.contains("universal") || lower.contains(".app.zip") {
                                if universalZipUrl == nil { universalZipUrl = dUrl }
                            } else if generalZipUrl == nil && !lower.contains("windows") {
                                generalZipUrl = dUrl
                            }
                        } else if lower.hasSuffix(".dmg") && dmgUrl == nil {
                            if isArm64 && (lower.contains("applesilicon") || lower.contains("arm64")) {
                                dmgUrl = dUrl
                            } else if !isArm64 && (lower.contains("intel") || lower.contains("x86_64")) {
                                dmgUrl = dUrl
                            } else if dmgUrl == nil {
                                dmgUrl = dUrl
                            }
                        }
                    }
                }
            }

            // Prefer architecture-specific zip, then universal zip, then generic zip, then dmg
            let finalDownloadUrl = archZipUrl ?? universalZipUrl ?? generalZipUrl ?? dmgUrl ?? (json["html_url"] as? String)

            let cleanTag = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let cleanCurrent = actualVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

            let isNewer = cleanTag.compare(cleanCurrent, options: .numeric) == .orderedDescending

            let updateInfo = AppUpdateInfo(
                id: tagName,
                version: tagName,
                title: releaseName,
                releaseNotes: body,
                downloadUrl: finalDownloadUrl,
                publishedAt: pubDate,
                isNewer: isNewer
            )

            self.latestUpdateInfo = updateInfo
            #if arch(arm64)
            let currentArch = "Apple Silicon"
            #else
            let currentArch = "Intel"
            #endif
            LogManager.shared.log("🔍 Проверка обновлений (\(currentArch)): текущая v\(actualVersion), на сервере \(tagName) (новее: \(isNewer))", level: "UPDATE")
            return (updateInfo, nil)
        } catch {
            let errMsg = error.localizedDescription
            self.updateCheckError = errMsg
            return (nil, errMsg)
        }
    }

    @MainActor
    public func performSelfUpdate(updateInfo: AppUpdateInfo) async -> (Bool, String) {
        guard let downloadUrlStr = updateInfo.downloadUrl, let url = URL(string: downloadUrlStr) else {
            return (false, "Ссылка на скачивание обновления недоступна")
        }

        self.isUpdatingApp = true
        self.updateDownloadProgress = 0.05
        self.updateStatusStage = "Подготовка к скачиванию..."
        LogManager.shared.log("🚀 Запуск процесса самообновления Open Store до \(updateInfo.version)...", level: "UPDATE")

        let tempDir = NSTemporaryDirectory()
        let updateZipPath = "\(tempDir)OpenStore_update.zip"
        let extractDir = "\(tempDir)OpenStore_extracted"

        try? FileManager.default.removeItem(atPath: updateZipPath)
        try? FileManager.default.removeItem(atPath: extractDir)
        try? FileManager.default.createDirectory(atPath: extractDir, withIntermediateDirectories: true)

        do {
            self.updateStatusStage = "Скачивание новой версии..."
            self.updateDownloadProgress = 0.15

            var req = URLRequest(url: url)
            req.timeoutInterval = 300

            let (tempLocalUrl, response) = try await URLSession.shared.download(for: req)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                self.isUpdatingApp = false
                return (false, "Ошибка сервера при скачивании архива")
            }

            self.updateDownloadProgress = 0.65
            self.updateStatusStage = "Распаковка обновления..."

            try? FileManager.default.removeItem(atPath: updateZipPath)
            try FileManager.default.moveItem(at: tempLocalUrl, to: URL(fileURLWithPath: updateZipPath))

            // Unzip archive via ditto
            let unzipProc = Process()
            unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProc.arguments = ["-x", "-k", updateZipPath, extractDir]
            try unzipProc.run()
            unzipProc.waitUntilExit()

            // Find .app inside extractDir
            var foundAppPath: String? = nil
            let fileManager = FileManager.default
            let subEntries = (try? fileManager.contentsOfDirectory(atPath: extractDir)) ?? []
            for item in subEntries {
                let fullPath = "\(extractDir)/\(item)"
                if item.hasSuffix(".app") {
                    foundAppPath = fullPath
                    break
                }
                // Check one level deep
                let nested = (try? fileManager.contentsOfDirectory(atPath: fullPath)) ?? []
                for n in nested {
                    if n.hasSuffix(".app") {
                        foundAppPath = "\(fullPath)/\(n)"
                        break
                    }
                }
                if foundAppPath != nil { break }
            }

            guard let newAppPath = foundAppPath, fileManager.fileExists(atPath: newAppPath) else {
                self.isUpdatingApp = false
                return (false, "Не удалось обнаружить приложение в скачанном архиве")
            }

            self.updateDownloadProgress = 0.85
            self.updateStatusStage = "Установка новой версии..."

            // Determine target path
            let currentBundlePath = Bundle.main.bundlePath
            let targetDestPath: String
            if currentBundlePath.hasSuffix(".app") {
                targetDestPath = currentBundlePath
            } else {
                targetDestPath = "/Applications/Open Store.app"
            }

            // Create detached updater script
            let updaterScriptPath = "\(tempDir)openstore_updater.sh"
            let scriptContent = """
            #!/bin/bash
            OLD_PID=$1
            SRC_APP="$2"
            DEST_APP="$3"

            # Wait for previous application process to terminate
            while kill -0 "$OLD_PID" 2>/dev/null; do
                sleep 0.2
            done

            sleep 0.5

            DEST_DIR="$(dirname "$DEST_APP")"
            APP_BASENAME="$(basename "$SRC_APP")"
            FINAL_DEST="$DEST_DIR/$APP_BASENAME"

            # Replace bundle
            rm -rf "$DEST_APP"
            rm -rf "$FINAL_DEST"
            cp -R "$SRC_APP" "$FINAL_DEST"
            xattr -cr "$FINAL_DEST" 2>/dev/null || true

            # Cleanup
            rm -rf "$SRC_APP" "$(dirname "$SRC_APP")" "/tmp/OpenRestore_update.zip" "/tmp/OpenStore_update.zip" 2>/dev/null || true

            # Launch updated app
            open "$FINAL_DEST"
            """

            try scriptContent.write(toFile: updaterScriptPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: updaterScriptPath)

            self.updateDownloadProgress = 1.0
            self.updateStatusStage = "Перезапуск Open Store..."

            let currentPid = ProcessInfo.processInfo.processIdentifier

            let updaterProc = Process()
            updaterProc.executableURL = URL(fileURLWithPath: "/bin/bash")
            updaterProc.arguments = [updaterScriptPath, "\(currentPid)", newAppPath, targetDestPath]
            try updaterProc.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NSApplication.shared.terminate(nil)
            }

            return (true, "Обновление установлено. Выполняется перезапуск...")
        } catch {
            self.isUpdatingApp = false
            let msg = "Ошибка установки обновления: \(error.localizedDescription)"
            LogManager.shared.log("❌ \(msg)", level: "UPDATE")
            return (false, msg)
        }
    }
}
