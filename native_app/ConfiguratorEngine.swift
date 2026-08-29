import Foundation
import AppKit
import SQLite3

public struct DeviceInfo: Identifiable, Hashable, Sendable {
    public var id: String { udid.isEmpty ? ecid : udid }
    public let name: String
    public let modelIdentifier: String
    public let marketingName: String
    public let iosVersion: String
    public let diskCapacity: String
    public let battery: String
    public let udid: String
    public let ecid: String
    public let serialNumber: String
    public let wifiAddress: String
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

public struct PurchasedApp: Identifiable, Hashable {
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

public struct IPAResult {
    public let path: String
    public let appName: String
    public let bundleId: String
    public let version: String
    public let sha256: String
    public let size: Int64
    public let hasFairPlay: Bool
}

public struct AppUpdateInfo: Identifiable, Equatable {
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
public class LogManager: ObservableObject {
    public static let shared = LogManager()

    @Published public var recentLogs: [String] = []

    private let queue = DispatchQueue(label: "com.openrestore.logmanager", qos: .utility)
    private let maxMemoryLogs = 400

    public var logFilePath: String {
        let dir = ConfiguratorEngine.libraryDir
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        return "\(dir)/openrestore.log"
    }

    public init() {
        writeSessionBanner()
    }

    private func writeSessionBanner() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let banner = "\n======================================================\n" +
                     "  OpenRestore Diagnostics Log — Session: \(df.string(from: Date()))\n" +
                     "  macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)\n" +
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

public class ConfiguratorEngine: ObservableObject {
    public static let shared = ConfiguratorEngine()

    public static let defaultDBPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/com.apple.configurator.purchases.cache/store.sqlite"
    }()

    public static let cfgutilPath = "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil"
    public static let workDir = "/Users/shavlak_1/Desktop/Рабочий стол/BMRNG or Analog"
    public static let libraryDir: String = {
        let home = NSHomeDirectory()
        return "\(home)/Downloads/OpenRestore"
    }()

    public static let userMappingsPath: String = {
        return "\(libraryDir)/adam_mappings.json"
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

    private let coreDataEpochDiff: Double = 978307200.0 // Seconds between 1970 and 2001

    @Published public var connectedDevices: [DeviceInfo] = []
    @Published public var purchasedApps: [PurchasedApp] = []
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
    @Published public var autoSignWithAppleId: Bool = true

    // Permissions State
    @Published public var isAccessibilityGranted: Bool = false
    @Published public var isAutomationGranted: Bool = false

    // Update Checker State
    @Published public var latestUpdateInfo: AppUpdateInfo? = nil
    @Published public var isCheckingUpdates: Bool = false
    @Published public var updateCheckError: String? = nil

    // Live Progress Tracking
    @Published public var operationProgress: Double = 0.0
    @Published public var operationStage: String = ""
    @Published public var downloadedSizeMB: Double = 0.0

    private var devicePollTimer: Timer?

    public init() {
        LogManager.shared.log("OpenRestore Engine инициализирован. Библиотека: \(Self.libraryDir)", level: "INIT")
        cleanAllRestoreRequests()
        checkAllPermissions()
        refreshDevices()
        refreshPurchasedApps()
        startDevicePolling()
    }

    deinit {
        devicePollTimer?.invalidate()
    }

    private var pollCycle: Int = 0

    public func startDevicePolling() {
        DispatchQueue.main.async {
            self.devicePollTimer?.invalidate()
            self.devicePollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.refreshDevices()
                self.pollCycle += 1
                if self.pollCycle % 2 == 0 {
                    self.refreshAppleIdStatus()
                }
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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
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
        tell application "Apple Configurator" to activate
        tell application "System Events" to get name
        """)
        var errInfo: NSDictionary?
        _ = script?.executeAndReturnError(&errInfo)
        checkAllPermissions()
    }

    public func refreshDevices() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let devs = self.getConnectedDevicesDetails()
            DispatchQueue.main.async {
                if self.connectedDevices != devs {
                    self.connectedDevices = devs
                }
            }
        }
    }

    public func refreshPurchasedApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let apps = self.loadPurchasedAppsFromDB()
            let dsid = self.getOwnerDsid() ?? ""
            DispatchQueue.main.async {
                self.purchasedApps = apps
                self.currentAccountDsid = dsid
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

    public func getConnectedDevicesDetails() -> [DeviceInfo] {
        let coreScript = Self.workDir + "/ios_core.py"
        guard FileManager.default.fileExists(atPath: coreScript) else { return [] }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["devinfo"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else { return [] }

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 8.0) {
            if proc.isRunning { proc.terminate() }
        }

        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              !dict.isEmpty,
              let productType = dict["ProductType"] as? String, !productType.isEmpty
        else { return [] }

        let name = (dict["DeviceName"] as? String) ?? "iPhone"
        let productVersion = (dict["ProductVersion"] as? String) ?? ""
        let udid = (dict["UniqueDeviceID"] as? String) ?? ""
        let modelNum = (dict["RegulatoryModelNumber"] as? String) ?? (dict["ModelNumber"] as? String) ?? ""
        let givenMarketing = (dict["MarketingName"] as? String) ?? ""
        let marketingName = !givenMarketing.isEmpty ? givenMarketing : Self.mapMarketingName(productType, modelNumber: modelNum)

        // Format disk capacity
        var diskStr = ""
        if let totalBytes = dict["TotalDiskCapacity"] as? Int {
            let gb = Int(round(Double(totalBytes) / 1_000_000_000.0))
            var freeStr = ""
            if let freeBytes = dict["AvailableDiskCapacity"] as? Int {
                let freeGb = Double(freeBytes) / 1_073_741_824.0
                freeStr = String(format: " (свободно %.0f ГБ)", freeGb)
            }
            diskStr = "\(gb) ГБ\(freeStr)"
        }

        // Format battery
        var battStr = ""
        if let bat = dict["BatteryCurrentCapacity"] as? Int {
            battStr = "\(bat)%"
        }

        let serial = (dict["SerialNumber"] as? String) ?? ""
        let wifi = (dict["WiFiAddress"] as? String) ?? ""

        return [DeviceInfo(
            name: name,
            modelIdentifier: productType,
            marketingName: marketingName,
            iosVersion: "iOS \(productVersion)",
            diskCapacity: diskStr,
            battery: battStr,
            udid: udid,
            ecid: "",
            serialNumber: serial,
            wifiAddress: wifi
        )]
    }

    public func scanInstalledAppsFromDevice(ecid: String? = nil, catalog: [AppItem] = []) {
        DispatchQueue.main.async { self.isScanningApps = true }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let coreScript = "\(Self.workDir)/ios_core.py"
            var discovered: [DeviceInstalledApp] = []
            let userMappings = self.loadUserMappings()

            if FileManager.default.isExecutableFile(atPath: coreScript) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: coreScript)
                proc.arguments = ["apps"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                if (try? proc.run()) != nil {
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
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
                proc.standardError = Pipe()

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
            throw NSError(domain: "OpenRestore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не найден Apple ID в Apple Configurator. Войдите в аккаунт в Configurator."])
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(Self.defaultDBPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            throw NSError(domain: "OpenRestore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось открыть базу Apple Configurator."])
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
                throw NSError(domain: "OpenRestore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ошибка вставки записи в SQLite базу."])
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
            LogManager.shared.log("⚠️ Внимание: Для автоматических кликов в Apple Configurator требуется выдать доступ в «Системные настройки → Конфиденциальность → Универсальный доступ» для OpenRestore.", level: "AUTO")
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


    public func installApp(ipaPath: String, bundleId: String = "") async -> (Bool, String) {
        let appFilename = URL(fileURLWithPath: ipaPath).lastPathComponent
        LogManager.shared.log("🚀 Начало установки «\(appFilename)»...", level: "INSTALL")
        LogManager.shared.log("🔒 Безопасный режим: Данные устройства, контакты, фото и другие приложения защищены.", level: "INSTALL")
        appendLog("🚀 Установка «\(appFilename)»...")
        appendLog("🔒 Безопасный режим: данные и другие приложения не затрагиваются")

        DispatchQueue.main.async {
            self.operationProgress = 0.2
            self.operationStage = "Проверка пакета «\(appFilename)»..."
        }

        if autoSignWithAppleId && isAppleIdAuthenticated && !bundleId.isEmpty {
            DispatchQueue.main.async {
                self.operationProgress = 0.4
                self.operationStage = "Получение FairPlay-лицензии на \(self.activeAppleIdEmail)..."
            }
            appendLog("🔑 Запрос FairPlay-лицензии...")
            _ = await purchaseAppLicense(bundleId: bundleId)
        }

        DispatchQueue.main.async {
            self.operationProgress = 0.6
            self.operationStage = "Передача приложения на iPhone по прямому USB-каналу..."
        }
        appendLog("📲 Передача приложения на подключенный iPhone по прямому USB-каналу...")

        let coreScript = "\(Self.workDir)/ios_core.py"
        if FileManager.default.isExecutableFile(atPath: coreScript) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: coreScript)
            proc.arguments = ["install", ipaPath]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()

            if (try? proc.run()) != nil {
                DispatchQueue.main.async {
                    self.operationProgress = 0.85
                    self.operationStage = "Установка и регистрация приложения на iOS..."
                }
                appendLog("⚙️ Регистрация в SpringBoard и системных службах iOS...")
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

        // Fallback to cfgutil
        if FileManager.default.isExecutableFile(atPath: Self.cfgutilPath) {
            appendLog("🔄 Установка через Apple Configurator helper...")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: Self.cfgutilPath)
            proc.arguments = ["install-app", ipaPath]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                DispatchQueue.main.async {
                    self.operationProgress = 1.0
                    self.operationStage = proc.terminationStatus == 0 ? "Установка завершена успешно!" : "Ошибка установки"
                }

                if proc.terminationStatus == 0 {
                    LogManager.shared.log("🎉 «\(appFilename)» успешно установлено через cfgutil!", level: "INSTALL")
                    appendLog("🎉 «\(appFilename)» успешно установлено!")
                    return (true, str.isEmpty ? "Приложение успешно установлено на iPhone!" : str)
                } else {
                    LogManager.shared.log("❌ Ошибка cfgutil: \(str)", level: "INSTALL")
                    appendLog("❌ Ошибка: \(str)")
                    return (false, str.isEmpty ? "Ошибка установки через cfgutil" : str)
                }
            } catch {
                LogManager.shared.log("❌ Ошибка запуска cfgutil: \(error.localizedDescription)", level: "INSTALL")
                appendLog("❌ Ошибка: \(error.localizedDescription)")
                return (false, error.localizedDescription)
            }
        }

        return (false, "Утилита установки не найдена")
    }

    public func uninstallApp(bundleId: String) async -> (Bool, String) {
        let coreScript = Self.workDir + "/ios_core.py"
        guard FileManager.default.fileExists(atPath: coreScript) else { return (false, "ios_core.py не найден") }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["uninstall", bundleId]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

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

    public func downloadDirectAppStore(adamId: Int64, name: String) async -> (Bool, String, String?) {
        let coreScript = Self.workDir + "/ios_core.py"
        let outputDir = Self.libraryDir
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)

        DispatchQueue.main.async {
            self.operationProgress = 0.2
            self.operationStage = "Прямая загрузка из App Store (CDN Apple)..."
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["download_direct", String(adamId), outputDir]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else { return (false, "Не удалось запустить загрузчик", nil) }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = dict["success"] as? Bool, success {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: outputDir) {
                let match = files.first { $0.contains(String(adamId)) && $0.hasSuffix(".ipa") }
                if let m = match {
                    let fullPath = "\(outputDir)/\(m)"
                    DispatchQueue.main.async {
                        self.operationProgress = 1.0
                        self.operationStage = "Загрузка завершена!"
                    }
                    return (true, "Загружено успешно", fullPath)
                }
            }
            return (true, "Загружено", nil)
        }
        return (false, "Ошибка прямой загрузки App Store. Переключаюсь на метод Configurator...", nil)
    }

    public func refreshAppleIdStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // 1. Try reading live signed in account from Apple Configurator UI menu
            let scriptSource = """
            tell application "System Events"
                if exists (process "Apple Configurator") then
                    tell process "Apple Configurator"
                        try
                            tell menu bar 1
                                repeat with mi in menu bar items
                                    if (name of mi is "Учетная запись" or name of mi is "Account") then
                                        set firstItem to name of menu item 1 of menu 1 of mi
                                        if firstItem does not contain "Sign In" and firstItem does not contain "Войти" and firstItem is not "missing value" and firstItem is not "" then
                                            return "AUTH:" & firstItem
                                        else
                                            return "UNAUTH"
                                        end if
                                    end if
                                end repeat
                            end tell
                        end try
                    end tell
                end if
                return "UNKNOWN"
            end tell
            """

            var liveEmail: String? = nil
            var isLiveAuth: Bool? = nil

            var errInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: scriptSource) {
                let desc = appleScript.executeAndReturnError(&errInfo)
                let str = desc.stringValue ?? ""
                if str.hasPrefix("AUTH:") {
                    liveEmail = String(str.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                    isLiveAuth = true
                } else if str == "UNAUTH" {
                    isLiveAuth = false
                }
            }

            // 2. Also check ownerDsid from store.sqlite
            let dsid = self.getOwnerDsid() ?? ""

            DispatchQueue.main.async {
                let prevEmail = self.activeAppleIdEmail
                if let email = liveEmail, !email.isEmpty {
                    self.activeAppleIdEmail = email
                    self.activeAppleIdName = email.components(separatedBy: "@").first ?? email
                    self.isAppleIdAuthenticated = true
                    self.currentAccountDsid = dsid
                    if prevEmail != email {
                        LogManager.shared.log("✅ Обнаружен новый Apple ID в Apple Configurator: \(email)", level: "AUTH")
                        self.refreshPurchasedApps()
                    }
                } else if isLiveAuth == false {
                    self.isAppleIdAuthenticated = false
                    self.activeAppleIdEmail = ""
                    self.activeAppleIdName = ""
                } else if !dsid.isEmpty {
                    self.currentAccountDsid = dsid
                    if self.activeAppleIdEmail.isEmpty {
                        self.activeAppleIdEmail = "Apple ID (DSID: \(dsid))"
                        self.activeAppleIdName = "Пользователь"
                        self.isAppleIdAuthenticated = true
                    }
                }
            }
        }
    }

    public func openConfiguratorAccountDialog() {
        DispatchQueue.main.async {
            self.isAppleIdAuthenticated = false
            self.activeAppleIdEmail = ""
            self.activeAppleIdName = ""
            self.currentAccountDsid = ""
            self.purchasedApps = []
        }

        openConfigurator()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let scriptSource = """
            tell application "Apple Configurator" to activate
            tell application "System Events"
                tell process "Apple Configurator"
                    try
                        tell menu bar 1
                            repeat with mi in menu bar items
                                if (name of mi is "Учетная запись" or name of mi is "Account") then
                                    if (exists menu item "Sign Out…" of menu 1 of mi) then
                                        click menu item "Sign Out…" of menu 1 of mi
                                        delay 0.8
                                    else if (exists menu item "Выйти…" of menu 1 of mi) then
                                        click menu item "Выйти…" of menu 1 of mi
                                        delay 0.8
                                    end if

                                    if (exists menu item "Sign In…" of menu 1 of mi) then
                                        click menu item "Sign In…" of menu 1 of mi
                                    else if (exists menu item "Войти…" of menu 1 of mi) then
                                        click menu item "Войти…" of menu 1 of mi
                                    else
                                        click menu item 1 of menu 1 of mi
                                    end if
                                    exit repeat
                                end if
                            end repeat
                        end tell
                    end try
                end tell
            end tell
            """
            var errInfo: NSDictionary?
            let script = NSAppleScript(source: scriptSource)
            _ = script?.executeAndReturnError(&errInfo)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.refreshPurchasedApps()
                self.refreshAppleIdStatus()
            }
        }
    }

    public func loginAppleId(email: String, password: String, code: String? = nil) async -> (Bool, Bool, String) {
        let coreScript = Self.workDir + "/ios_core.py"
        guard FileManager.default.fileExists(atPath: coreScript) else {
            return (false, false, "ios_core.py не найден")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        var args = ["auth_login", email, password]
        if let c = code, !c.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(c.trimmingCharacters(in: .whitespaces))
        }
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else {
            return (false, false, "Не удалось запустить процесс входа")
        }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let success = (dict["success"] as? Bool) ?? false
            let req2FA = (dict["requires_2fa"] as? Bool) ?? false
            let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? ""

            if success {
                self.refreshAppleIdStatus()
            }
            return (success, req2FA, msg)
        }
        return (false, false, "Неизвестный ответ от сервера аутентификации")
    }

    public func logoutAppleId() async -> Bool {
        let coreScript = Self.workDir + "/ios_core.py"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["auth_revoke"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else { return false }
        proc.waitUntilExit()

        DispatchQueue.main.async {
            self.isAppleIdAuthenticated = false
            self.activeAppleIdName = ""
            self.activeAppleIdEmail = ""
        }
        return proc.terminationStatus == 0
    }

    public func purchaseAppLicense(bundleId: String) async -> (Bool, String) {
        let coreScript = Self.workDir + "/ios_core.py"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: coreScript)
        proc.arguments = ["purchase", bundleId]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        guard (try? proc.run()) != nil else { return (false, "Ошибка запуска purchase") }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = dict["success"] as? Bool {
            let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? ""
            return (success, msg)
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

    public func checkForUpdates(currentVersion: String = "1.5.0") async -> (AppUpdateInfo?, String?) {
        DispatchQueue.main.async {
            self.isCheckingUpdates = true
            self.updateCheckError = nil
        }

        defer {
            DispatchQueue.main.async {
                self.isCheckingUpdates = false
            }
        }

        guard let url = URL(string: "https://api.github.com/repos/Shavlak_1/OpenRestore/releases/latest") else {
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
                    id: "v1.5.0",
                    version: "v1.5.0",
                    title: "OpenRestore v1.5.0",
                    releaseNotes: "У вас установлена самая свежая версия программы.",
                    downloadUrl: nil,
                    publishedAt: "",
                    isNewer: false
                )
                DispatchQueue.main.async {
                    self.latestUpdateInfo = info
                }
                return (info, nil)
            }

            guard httpResponse.statusCode == 200 else {
                let err = "Ошибка сервера GitHub (\(httpResponse.statusCode))"
                DispatchQueue.main.async { self.updateCheckError = err }
                return (nil, err)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                let err = "Не удалось разобрать данные релиза"
                DispatchQueue.main.async { self.updateCheckError = err }
                return (nil, err)
            }

            let releaseName = (json["name"] as? String) ?? tagName
            let body = (json["body"] as? String) ?? ""
            let pubDate = (json["published_at"] as? String) ?? ""

            var downloadUrl: String? = nil
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let dUrl = asset["browser_download_url"] as? String {
                        if dUrl.hasSuffix(".dmg") || dUrl.hasSuffix(".zip") {
                            downloadUrl = dUrl
                            break
                        }
                    }
                }
            }
            if downloadUrl == nil {
                downloadUrl = json["html_url"] as? String
            }

            let cleanTag = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let cleanCurrent = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

            let isNewer = cleanTag.compare(cleanCurrent, options: .numeric) == .orderedDescending

            let updateInfo = AppUpdateInfo(
                id: tagName,
                version: tagName,
                title: releaseName,
                releaseNotes: body,
                downloadUrl: downloadUrl,
                publishedAt: pubDate,
                isNewer: isNewer
            )

            DispatchQueue.main.async {
                self.latestUpdateInfo = updateInfo
            }

            return (updateInfo, nil)
        } catch {
            let errMsg = error.localizedDescription
            DispatchQueue.main.async {
                self.updateCheckError = errMsg
            }
            return (nil, errMsg)
        }
    }
}
