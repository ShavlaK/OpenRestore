import SwiftUI
import UniformTypeIdentifiers
import AppKit
import QuartzCore

// MARK: - Models
struct SavedIPA: Identifiable, Hashable {
    var id: String { path }
    let filename: String
    let displayName: String
    let version: String
    let path: String
    let size: String
    let date: String
    let adamId: String
    var artworkUrl: String? = nil
}

// MARK: - App Logo View (Blue gradient rounded squircle with white lightning bolt)
struct AppLogoView: View {
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 11

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 79/255, green: 180/255, blue: 255/255), Color(red: 26/255, green: 124/255, blue: 255/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.blue.opacity(0.4), radius: size * 0.2, x: 0, y: 2)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
                .frame(width: size, height: size)

            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Universal Rounded Capsule Button Modifier
extension View {
    @ViewBuilder
    func roundedCapsuleButton() -> some View {
        if #available(macOS 14.0, *) {
            self.buttonBorderShape(.capsule)
        } else {
            self.buttonBorderShape(.roundedRectangle)
        }
    }
}

// MARK: - Modern Monotone Matte Modifiers (Clean, Flat, Semi-transparent macOS Style)
struct MatteButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var tintColor: Color = .blue
    var cornerRadius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: isProminent ? .semibold : .medium))
            .foregroundColor(isProminent ? .white : .primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isProminent
                            ? tintColor.opacity(configuration.isPressed ? 0.80 : 0.95)
                            : Color.white.opacity(configuration.isPressed ? 0.12 : 0.07)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isProminent ? Color.clear : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func matteButton(isProminent: Bool = false, tint: Color = .blue, cornerRadius: CGFloat = 12) -> some View {
        self.buttonStyle(MatteButtonStyle(isProminent: isProminent, tintColor: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - Engine Mode Enum
public enum InstallEngineMode: String, CaseIterable, Identifiable {
    case direct = "direct"
    case configurator = "configurator"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .direct:
            return "Прямой нативный (Open Store Core)"
        case .configurator:
            return "Резервная системная служба"
        }
    }

    public var shortTitle: String {
        switch self {
        case .direct:
            return "Прямой нативный"
        case .configurator:
            return "Configurator"
        }
    }

    public var icon: String {
        switch self {
        case .direct:
            return "bolt.fill"
        case .configurator:
            return "gearshape.2.fill"
        }
    }
}

// MARK: - Sidebar Items
enum SidebarItem: String, CaseIterable, Identifiable {
    case device    = "Со старого iPhone"
    case purchases = "Покупки Apple ID"
    case customId  = "Произвольный ID"
    case library   = "Библиотека IPA"
    case settings  = "Настройки"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .device:    return "iphone.gen3"
        case .purchases: return "bag.fill"
        case .customId:  return "number"
        case .library:   return "archivebox.fill"
        case .settings:  return "gearshape.fill"
        }
    }

    var badgeColor: Color {
        switch self {
        case .device:    return Color(red: 52/255, green: 199/255, blue: 89/255) // Apple Green
        case .purchases: return Color(red: 0/255, green: 122/255, blue: 255/255) // Apple Blue
        case .customId:  return Color(red: 255/255, green: 149/255, blue: 0/255) // Apple Orange
        case .library:   return Color(red: 175/255, green: 82/255, blue: 222/255) // Apple Purple
        case .settings:  return Color(red: 142/255, green: 142/255, blue: 147/255) // Apple Gray
        }
    }
}

// MARK: - Native Window Blur Background
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @ObservedObject private var engine = ConfiguratorEngine.shared
    @State private var catalogApps: [AppItem] = []
    @State private var searchQuery: String = ""
    @State private var customAdamId: String = ""
    @State private var savedIPAs: [SavedIPA] = []
    @State private var bypassPermissionsGate: Bool = false

    // Persisted settings (Zero-reprompt and full state restoration)
    @AppStorage("appColorScheme")          private var storedScheme: String = "system"
    @AppStorage("libraryPath")             private var customLibraryPath: String = ""
    @AppStorage("selectedSidebarTab")      private var storedSidebarTab: String = SidebarItem.device.rawValue
    @AppStorage("installEngineMode")       private var installEngineMode: String = InstallEngineMode.direct.rawValue
    @AppStorage("preferDirectMode")        private var preferDirectMode: Bool = true
    @AppStorage("autoClickConfigurator")   private var autoClickConfigurator: Bool = true
    @AppStorage("autoCheckUpdates")        private var autoCheckUpdates: Bool = true

    var currentEngineMode: InstallEngineMode {
        let mode = InstallEngineMode(rawValue: installEngineMode) ?? .direct
        if mode == .configurator && !engine.isConfiguratorInstalled {
            return .direct
        }
        return mode
    }

    var selectedSidebar: SidebarItem {
        SidebarItem(rawValue: storedSidebarTab) ?? .device
    }

    @Environment(\.colorScheme) private var colorScheme

    // Batch download state
    @State private var selectedAdamIds: Set<Int64> = []
    @State private var isBatchDownloading: Bool = false
    @State private var batchTotal: Int = 0
    @State private var batchDone: Int = 0

    @State private var appToDeleteIPA: (name: String, path: String)? = nil
    @State private var showDeleteIPAConfirm: Bool = false
    @State private var showDeviceManagerSheet: Bool = false
    @State private var selectedDeviceForDetail: DeviceInfo? = nil
    @State private var editingOwnerName: String = ""
    @State private var isEditingOwner: Bool = false
    @State private var showForgetConfirmDialog: Bool = false
    @State private var deviceToForget: DeviceInfo? = nil
    @State private var showAppleIdSheet: Bool = false
    @State private var appleIdEmailInput: String = ""
    @State private var appleIdPasswordInput: String = ""
    @State private var appleId2FACodeInput: String = ""
    @State private var is2FARequired: Bool = false
    @State private var isLoggingInAppleId: Bool = false
    @State private var appleIdAuthError: String = ""
    @State private var appleIdAuthSuccess: String = ""
    @State private var isPasswordVisible: Bool = false
    @AppStorage("vpnNoticeDismissed") private var vpnNoticeDismissed: Bool = false

    @State private var selectedSavedIPAPaths: Set<String> = []
    @State private var savedIPASearchQuery: String = ""
    @State private var isBatchInstallingIPAs: Bool = false
    @State private var batchInstallCurrent: Int = 0
    @State private var batchInstallTotal: Int = 0

    @State private var showManualAdamIdDialog: Bool = false
    @State private var manualBundleId: String = ""
    @State private var manualAppName: String = ""
    @State private var manualEnteredId: String = ""

    @State private var isRestoring: Bool = false
    @State private var restoringAppName: String = ""
    @State private var restoringAdamId: Int64 = 0
    @State private var shouldInstallAfterDownload: Bool = false
    @State private var restoreError: String? = nil
    @State private var restoreSuccessIPA: String? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var copiedLogsToast: Bool = false

    var effectiveLibraryPath: String {
        customLibraryPath.isEmpty ? ConfiguratorEngine.libraryDir : customLibraryPath
    }

    var preferredScheme: ColorScheme? {
        switch storedScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var filteredPurchasedApps: [PurchasedApp] {
        if searchQuery.isEmpty { return engine.purchasedApps }
        let q = searchQuery.lowercased()
        return engine.purchasedApps.filter {
            $0.name.lowercased().contains(q) || $0.bundleId.lowercased().contains(q) || String($0.adamId).contains(q)
        }
    }

    var filteredSavedIPAs: [SavedIPA] {
        if savedIPASearchQuery.isEmpty { return savedIPAs }
        let q = savedIPASearchQuery.lowercased()
        return savedIPAs.filter {
            $0.displayName.lowercased().contains(q) || $0.filename.lowercased().contains(q) ||
            $0.version.lowercased().contains(q) || $0.adamId.contains(q)
        }
    }

    var filteredOldDeviceApps: [DeviceInstalledApp] {
        if searchQuery.isEmpty { return engine.oldDeviceApps }
        let q = searchQuery.lowercased()
        return engine.oldDeviceApps.filter {
            $0.name.lowercased().contains(q) ||
            $0.displayName.lowercased().contains(q) ||
            $0.bundleId.lowercased().contains(q) ||
            ($0.adamId != nil && String($0.adamId!).contains(q))
        }
    }

    func isSavedInLibrary(adamId: Int64, name: String = "", bundleId: String = "") -> SavedIPA? {
        let aidStr = String(adamId)
        guard let item = savedIPAs.first(where: { item in
            if aidStr != "0" && !aidStr.isEmpty && (item.adamId == aidStr || item.filename.contains(aidStr)) { return true }
            if !name.isEmpty && item.displayName.lowercased().contains(name.lowercased()) { return true }
            if !bundleId.isEmpty && item.filename.lowercased().contains(bundleId.lowercased()) { return true }
            return false
        }) else { return nil }

        // Validate that the IPA is not a 0-byte/22-byte broken artifact
        if let attr = try? FileManager.default.attributesOfItem(atPath: item.path),
           let sz = attr[.size] as? Int64, sz > 1_000_000 {
            return item
        }
        return nil
    }

    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Frosted Glass Window Canvas (Tahoe Matte Translucent Canvas)
            ZStack {
                VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                Theme.Colors.windowFrostedTint(for: colorScheme)
            }
            .ignoresSafeArea()

            WindowConfigurator()
                .frame(width: 0, height: 0)

            HStack(spacing: Theme.Metrics.panelSpacing) {
                // Left Floating Sidebar Card (300px width, 26px continuous rounded squircle)
                sidebarNavigationView
                    .frame(width: Theme.Metrics.sidebarWidth)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous)
                            .fill(Theme.Colors.sidebarBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous)
                            .stroke(Theme.Colors.sidebarBorder(for: colorScheme), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 10, x: 0, y: 3)

                // Right Floating Canvas Card (flex-1, 26px continuous rounded squircle)
                detailContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous)
                            .fill(Theme.Colors.canvasBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous)
                            .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 10, x: 0, y: 3)
            }
            .padding(Theme.Metrics.windowPadding)
            .ignoresSafeArea(.all, edges: .top)

            if engine.isMandatoryUpdateInProgress {
                mandatoryUpdateOverlay
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusWindow, style: .continuous))
        .ignoresSafeArea()
        .frame(minWidth: 940, minHeight: 620)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            loadCatalog()
            loadSavedIPAs()
            engine.refreshDevices()
            engine.refreshPurchasedApps()
            engine.scanInstalledAppsFromDevice(catalog: catalogApps)
            Task {
                await engine.checkAndApplyMandatoryUpdate()
            }
        }
        .sheet(isPresented: $isRestoring)              { restoreProgressSheet }
        .sheet(isPresented: $showManualAdamIdDialog)    { manualAdamIdSheet }
        .sheet(isPresented: $showDeviceManagerSheet)    { deviceManagerSheet }
        .sheet(isPresented: $showAppleIdSheet)          { appleIdSheet }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Open Store"), message: Text(alertMessage ?? ""),
                  dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showForgetConfirmDialog) {
            Alert(
                title: Text("Удалить связь с устройством?"),
                message: Text("Вы действительно хотите удалить сопряжение с «\(deviceToForget?.name ?? "устройством")»?\n\nСвязь и кэш будут удалены из Open Store, а сопряжение с Mac будет сброшено."),
                primaryButton: .destructive(Text("Удалить связь")) {
                    if let dev = deviceToForget {
                        engine.forgetDevice(id: dev.id)
                        if selectedDeviceForDetail?.id == dev.id {
                            selectedDeviceForDetail = engine.activeDevice
                        }
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
        .alert(isPresented: $showDeleteIPAConfirm) {
            Alert(
                title: Text("Удалить IPA из библиотеки?"),
                message: Text("Удалить сохранённый файл «\(appToDeleteIPA?.name ?? "")» из папки Библиотеки?\n\nС вашего iPhone приложение удалено НЕ будет и продолжит работать."),
                primaryButton: .destructive(Text("Удалить из библиотеки")) {
                    if let item = appToDeleteIPA {
                        try? FileManager.default.removeItem(atPath: item.path)
                        loadSavedIPAs()
                        alertMessage = "Файл «\(item.name)» удален из библиотеки. Приложение на iPhone сохранено."
                        showAlert = true
                    }
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }

    // MARK: - Sidebar Navigation View (Fully interactive, reliable clicks)
    private var sidebarNavigationView: some View {
        VStack(spacing: 0) {
            // Brand (Top area with traffic light inset)
            HStack(spacing: 12) {
                AppLogoView(size: 40, cornerRadius: 11)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Store")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                    Text("iOS App Manager")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 14)

            // Account & Device Glass Cards
            VStack(spacing: 8) {
                // Apple ID Button Card
                Button(action: {
                    if currentEngineMode == .configurator {
                        engine.openConfigurator()
                    } else {
                        showAppleIdSheet = true
                    }
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill((currentEngineMode == .configurator && !engine.currentAccountDsid.isEmpty) || (currentEngineMode == .direct && engine.isAppleIdAuthenticated) ? Theme.Colors.blueTint(for: colorScheme) : Color.primary.opacity(0.06))
                                .frame(width: 32, height: 32)
                            Image(systemName: engine.isAppleIdAuthenticated || (currentEngineMode == .configurator && !engine.currentAccountDsid.isEmpty) ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.system(size: 18))
                                .foregroundColor(engine.isAppleIdAuthenticated || (currentEngineMode == .configurator && !engine.currentAccountDsid.isEmpty) ? Theme.Colors.blue : Theme.Colors.textTertiary(for: colorScheme))
                        }

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(currentEngineMode == .configurator ? "Apple Configurator Auth" : (engine.activeAppleIdEmail.isEmpty ? "Apple ID — Войти" : engine.activeAppleIdEmail))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                .lineLimit(1)
                            Text(currentEngineMode == .configurator ? (!engine.currentAccountDsid.isEmpty ? "\(engine.purchasedApps.count) покупок • Configurator" : "Нажмите, чтобы открыть") : (engine.isLoadingPurchasedApps ? "Загрузка (\(engine.purchasedApps.count)/\(engine.totalPurchasedAppsCount > 0 ? "\(engine.totalPurchasedAppsCount)" : "..."))" : (engine.isAppleIdAuthenticated && engine.purchasedApps.isEmpty ? "Загрузка покупок..." : (engine.currentAccountDsid.isEmpty && !engine.isAppleIdAuthenticated ? "Нажмите для входа" : "\(engine.purchasedApps.count) покупок • FairPlay"))))
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                .lineLimit(1)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Colors.cardBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Device Button Card
                let activeDev = engine.activeDevice
                Button(action: {
                    selectedDeviceForDetail = activeDev
                    showDeviceManagerSheet = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(activeDev != nil ? Color.blue.opacity(0.18) : Color.primary.opacity(0.06))
                                .frame(width: 32, height: 32)
                            Image(systemName: activeDev?.connectionType == .usb ? "cable.connector" : "wifi")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(activeDev != nil ? Theme.Colors.blue : Theme.Colors.textTertiary(for: colorScheme))
                        }

                        VStack(alignment: .leading, spacing: 1.5) {
                            if let dev = activeDev {
                                Text(dev.formattedDisplayName)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                    .lineLimit(1)
                                Text("\(dev.modelIdentifier) • \(dev.iosVersion)")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                    .lineLimit(1)
                            } else {
                                Text("iPhone не подключен")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                    .lineLimit(1)
                                Text("Подключите кабель или Wi-Fi")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                    .lineLimit(1)
                            }
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 4)

                        if let dev = activeDev {
                            Text(dev.connectionType == .usb ? "USB" : "Wi-Fi")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Theme.Colors.blueTint(for: colorScheme))
                                .foregroundColor(Theme.Colors.blue)
                                .clipShape(Capsule())
                        } else {
                            Circle()
                                .fill(Theme.Colors.textTertiary(for: colorScheme))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(activeDev != nil ? Theme.Colors.blueTint(for: colorScheme) : Theme.Colors.cardBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(activeDev != nil ? Theme.Colors.blue.opacity(0.35) : Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Нажмите для открытия Менеджера устройств")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Section divider
            Rectangle()
                .fill(Theme.Colors.separator(for: colorScheme))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            // Scrollable Navigation List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Sources Section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Источники")
                            .font(.system(size: 10.5, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(0.6)
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 4)

                        sidebarNavButton(item: .device)
                        sidebarNavButton(item: .purchases)
                    }

                    // Tools Section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Инструменты")
                            .font(.system(size: 10.5, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(0.6)
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 4)

                        sidebarNavButton(item: .customId)
                        sidebarNavButton(item: .library)
                    }

                    // System Section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Система")
                            .font(.system(size: 10.5, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(0.6)
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 4)

                        sidebarNavButton(item: .settings)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Mode switch footer
            Rectangle()
                .fill(Theme.Colors.separator(for: colorScheme))
                .frame(height: 1)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.blue)
                        .frame(width: 18)

                    Text("Прямой нативный")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { currentEngineMode == .direct },
                        set: { isDirect in
                            installEngineMode = isDirect ? InstallEngineMode.direct.rawValue : InstallEngineMode.configurator.rawValue
                            preferDirectMode = isDirect
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(!engine.isConfiguratorInstalled)
                    .help(engine.isConfiguratorInstalled ? "" : "Требуется установка Apple Configurator")
                }

                Text("Быстрая установка без Configurator")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // Interactive Sidebar Button (macOS System Settings squircle badge style)
    private func sidebarNavButton(item: SidebarItem) -> some View {
        let isSelected = selectedSidebar == item
        let count = sidebarCount(item)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                storedSidebarTab = item.rawValue
                searchQuery = ""
                savedIPASearchQuery = ""
            }
        }) {
            HStack(spacing: 10) {
                // Colored squircle icon badge (22x22, radius 6 continuous)
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [item.badgeColor.opacity(0.88), item.badgeColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: 22)
                        .shadow(color: item.badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        .frame(width: 22, height: 22)

                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                if item == .settings && engine.latestUpdateInfo?.isNewer == true {
                    Text("NEW")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green))
                        .foregroundColor(.white)
                } else if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                        .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary(for: colorScheme))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background(
                Group {
                    if isSelected {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0/255, green: 122/255, blue: 255/255), Color(red: 0/255, green: 105/255, blue: 225/255)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: Color.blue.opacity(0.32), radius: 4, x: 0, y: 1.5)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

    private func sidebarCount(_ item: SidebarItem) -> Int? {
        switch item {
        case .device:    return engine.oldDeviceApps.count
        case .purchases: return engine.purchasedApps.count
        case .library:   return savedIPAs.count
        case .customId, .settings: return nil
        }
    }

    // MARK: - Detail Content Router
    @ViewBuilder
    private var detailContentView: some View {
        VStack(spacing: 0) {
            if engine.isVpnActive && !vpnNoticeDismissed {
                vpnTopNoticeBanner
                    .zIndex(200)
            }

            switch selectedSidebar {
            case .device:    oldDeviceAppsView
            case .purchases: purchasedAppsView
            case .customId:  customIdView
            case .library:   savedIPAsView
            case .settings:  settingsView
            }
        }
    }

// MARK: - Tahoe Liquid Glass Backdrop Blur (Adjustable Radius)
struct BackdropBlurView: NSViewRepresentable {
    var radius: CGFloat = 6.0

    func makeNSView(context: Context) -> NSView {
        let view = CustomBlurView()
        view.radius = radius
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? CustomBlurView {
            v.radius = radius
        }
    }

    private class CustomBlurView: NSView {
        var radius: CGFloat = 6.0 {
            didSet { updateFilter() }
        }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
        }
        required init?(coder: NSCoder) { fatalError() }

        override func makeBackingLayer() -> CALayer {
            if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
                return backdropClass.init()
            }
            return CALayer()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateFilter()
        }

        private func updateFilter() {
            guard let layer = self.layer else { return }
            if let filterClass = NSClassFromString("CAFilter") as? NSObject.Type {
                let sel = NSSelectorFromString("filterWithType:")
                if let filter = filterClass.perform(sel, with: "gaussianBlur")?.takeUnretainedValue() as? NSObject {
                    filter.setValue(radius, forKey: "inputRadius")
                    filter.setValue(true, forKey: "inputNormalizeEdges")
                    layer.filters = [filter]
                }
            }
        }
    }
}

    // MARK: - Minimalistic Seamless Toolbar Header
    @ViewBuilder
    private func frostedGlassHeader<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity)

            // Soft, subtle hairline divider (0.5pt with gentle opacity)
            Rectangle()
                .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.35))
                .frame(height: 0.5)
        }
        .background(
            ZStack {
                BackdropBlurView(radius: 6.0)
                Theme.Colors.canvasBackground(for: colorScheme)
                    .opacity(colorScheme == .dark ? 0.15 : 0.20)
            }
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.03), radius: 5, x: 0, y: 2)
        .zIndex(100)
    }

    // MARK: - Liquid Glass Modal Sheet Container
    @ViewBuilder
    private func liquidGlassSheet<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                ZStack {
                    BackdropBlurView(radius: 8.0)
                    (colorScheme == .dark
                        ? Color(red: 28/255, green: 28/255, blue: 34/255)
                        : Color(red: 248/255, green: 248/255, blue: 252/255))
                        .opacity(colorScheme == .dark ? 0.72 : 0.82)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSheet, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusSheet, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.45), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 24, x: 0, y: 10)
    }

    // MARK: - Modern macOS Detail Navigation Bar (Tahoe Liquid Glass)
    private func pageHeaderContent<Right: View>(
        title: String,
        subtitle: String = "",
        @ViewBuilder rightContent: () -> Right
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // macOS Navigation Chevrons (< >) Capsule
            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Colors.textTertiary(for: colorScheme).opacity(0.55))
                        .frame(width: 24, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(true)

                Button(action: {}) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Colors.textTertiary(for: colorScheme).opacity(0.55))
                        .frame(width: 24, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
            .padding(.horizontal, 2)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(Theme.Colors.controlBackground(for: colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
            )

            // Page Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.25)
                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 320, alignment: .leading)

            Spacer(minLength: 12)

            rightContent()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 20)
        .padding(.top, (engine.isVpnActive && !vpnNoticeDismissed) ? 8 : 16)
        .padding(.bottom, 12)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
    }

    private func pageHeaderBar<Right: View>(
        title: String,
        subtitle: String = "",
        @ViewBuilder rightContent: () -> Right
    ) -> some View {
        frostedGlassHeader {
            pageHeaderContent(title: title, subtitle: subtitle, rightContent: rightContent)
        }
    }

    // MARK: - Minimalistic macOS Search Capsule
    private func searchField(query: Binding<String>, placeholder: String, width: CGFloat = 220) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                .font(.system(size: 12, weight: .medium))

            TextField(placeholder, text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))

            if !query.wrappedValue.isEmpty {
                Button(action: { query.wrappedValue = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: 30)
        .background(
            Capsule()
                .fill(Theme.Colors.controlBackground(for: colorScheme))
        )
        .overlay(
            Capsule()
                .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - 0. Old Device Apps View
    private var oldDeviceHeader: some View {
        let appsWithId = engine.oldDeviceApps.filter { $0.adamId != nil && $0.adamId! > 0 }
        return frostedGlassHeader {
            VStack(spacing: 0) {
                pageHeaderContent(
                    title: "Приложения с iPhone",
                    subtitle: engine.activeDevice != nil ? "\(engine.activeDevice!.formattedDisplayName) • \(filteredOldDeviceApps.count) приложений" : "\(filteredOldDeviceApps.count) приложений"
                ) {
                    HStack(spacing: 10) {
                        searchField(query: $searchQuery, placeholder: "Поиск приложений...", width: 220)

                        Button(action: {
                            engine.scanInstalledAppsFromDevice(catalog: catalogApps)
                        }) {
                            HStack(spacing: 5) {
                                if engine.isScanningApps {
                                    ProgressView().controlSize(.small).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                Text("Обновить")
                            }
                        }
                        .liquidGlass(variant: .glass, size: .md)
                        .disabled(engine.isScanningApps)
                    }
                }

                // Batch selection bar integrated seamlessly into frosted glass header
                if !appsWithId.isEmpty {
                    Rectangle()
                        .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                        .frame(height: 0.5)

                    HStack(spacing: 10) {
                        Button(selectedAdamIds.count == appsWithId.count ? "Снять выбор" : "Выбрать все (\(appsWithId.count))") {
                            if selectedAdamIds.count == appsWithId.count {
                                selectedAdamIds.removeAll()
                            } else {
                                selectedAdamIds = Set(appsWithId.compactMap { $0.adamId })
                            }
                        }
                        .liquidGlass(variant: .glass, size: .sm)

                        if !selectedAdamIds.isEmpty {
                            Text("Выбрано: \(selectedAdamIds.count)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Theme.Colors.blue)

                            Button(action: { startBatchDownload(installToDevice: false) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Скачать (\(selectedAdamIds.count))")
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)
                            .disabled(isBatchDownloading)

                            Button(action: { startBatchDownload(installToDevice: true) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                    Text("Установить (\(selectedAdamIds.count))")
                                }
                            }
                            .liquidGlass(variant: .primary, size: .sm)
                            .disabled(isBatchDownloading)
                        }

                        Spacer()

                        if isBatchDownloading {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.6)
                                Text("Загрузка: \(batchDone)/\(batchTotal)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                }
            }
        }
    }

    private var oldDeviceAppsView: some View {
        Group {
            if engine.oldDeviceApps.isEmpty {
                emptyStateView(
                    icon: "iphone.gen3.slash",
                    title: "Приложения не найдены",
                    subtitle: "Подключите iPhone по кабелю и нажмите «Обновить», чтобы считать установленные программы."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredOldDeviceApps) { app in
                            deviceAppRow(app: app)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            oldDeviceHeader
        }
    }

    private func deviceAppRow(app: DeviceInstalledApp) -> some View {
        let isSelected = app.adamId != nil && selectedAdamIds.contains(app.adamId!)
        let savedIPA = isSavedInLibrary(adamId: app.adamId ?? 0, name: app.name, bundleId: app.bundleId)

        return HStack(spacing: 12) {
            // Checkbox
            if let aid = app.adamId, aid > 0 {
                Button(action: {
                    if isSelected { selectedAdamIds.remove(aid) }
                    else { selectedAdamIds.insert(aid) }
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? Theme.Colors.blue : Theme.Colors.textTertiary(for: colorScheme))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textTertiary(for: colorScheme).opacity(0.4))
            }

            // App Icon
            appIconView(url: app.artworkUrl, name: app.name)

            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.displayName.isEmpty ? app.name : app.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    if !app.bundleVersion.isEmpty {
                        Text(app.bundleVersion)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(app.bundleId)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    if let aid = app.adamId, aid > 0 {
                        Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        Text("ID: \(String(aid))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.blue)
                    }

                    if savedIPA != nil {
                        Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("В библиотеке")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Theme.Colors.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.greenTint(for: colorScheme))
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 8)

            // Actions
            HStack(spacing: 8) {
                if let aid = app.adamId, aid > 0 {
                    if let saved = savedIPA {
                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: false)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Скачать")
                            }
                        }
                        .liquidGlass(variant: .glass, size: .sm)
                        .help("Скачать IPA заново")

                        Button(action: {
                            startInstallFlow(ipaPath: saved.path, name: app.displayName)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Установить")
                            }
                        }
                        .liquidGlass(variant: .green, size: .sm)
                    } else {
                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: false)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Скачать")
                            }
                        }
                        .liquidGlass(variant: .glass, size: .sm)
                        .help("Скачать IPA в Библиотеку")

                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: true)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.to.line.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Скачать и установить")
                            }
                        }
                        .liquidGlass(variant: .primary, size: .sm)
                        .help("Скачать и установить на iPhone")
                    }
                } else {
                    Button(action: {
                        manualBundleId = app.bundleId
                        manualAppName = app.name
                        manualEnteredId = ""
                        showManualAdamIdDialog = true
                    }) {
                        Text("Указать ID")
                    }
                    .liquidGlass(variant: .orange, size: .sm)
                }

                Button(action: {
                    if let saved = savedIPA {
                        appToDeleteIPA = (name: URL(fileURLWithPath: saved.path).lastPathComponent, path: saved.path)
                        showDeleteIPAConfirm = true
                    } else {
                        alertMessage = "Файл IPA для «\(app.displayName)» отсутствует в локальной библиотеке.\n\nНапоминание: приложение с iPhone пользователя НЕ удаляется."
                        showAlert = true
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.Colors.blueTint(for: colorScheme) : Theme.Colors.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.Colors.blue.opacity(0.4) : Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - 2. Purchased Apps View
    private var purchasedAppsHeader: some View {
        pageHeaderBar(
            title: "Покупки Apple ID",
            subtitle: engine.isAppleIdAuthenticated ? "\(engine.activeAppleIdEmail) • \(engine.purchasedApps.count) покупок" : "Войдите в Apple ID для синхронизации"
        ) {
            HStack(spacing: 10) {
                searchField(query: $searchQuery, placeholder: "Поиск в покупках...", width: 220)

                Button(action: {
                    engine.refreshPurchasedApps()
                    engine.refreshAppleIdStatus()
                }) {
                    HStack(spacing: 5) {
                        if engine.isLoadingPurchasedApps {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        let countStr = engine.totalPurchasedAppsCount > 0 ? "\(engine.totalPurchasedAppsCount)" : "..."
                        Text(engine.isLoadingPurchasedApps ? "Загрузка (\(engine.purchasedApps.count)/\(countStr))" : "Синхронизировать")
                    }
                }
                .liquidGlass(variant: .glass, size: .md)
                .disabled(engine.isLoadingPurchasedApps)
            }
        }
    }

    private var purchasedAppsView: some View {
        Group {
            if engine.purchasedApps.isEmpty {
                emptyStateView(
                    icon: "bag",
                    title: engine.isLoadingPurchasedApps ? "Синхронизация покупок..." : "Покупки не найдены",
                    subtitle: engine.isLoadingPurchasedApps ? "Загружаем полный список ваших приложений из Apple ID..." : "Нажмите на Apple ID в боковой панели, чтобы войти в аккаунт и синхронизировать приложения."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPurchasedApps) { item in
                            purchasedAppRow(item: item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            purchasedAppsHeader
        }
    }

    private func purchasedAppRow(item: PurchasedApp) -> some View {
        let savedIPA = isSavedInLibrary(adamId: item.adamId, name: item.name, bundleId: item.bundleId)

        return HStack(spacing: 12) {
            appIconView(url: item.artworkUrl, name: item.name)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.bundleId)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))

                    Text("ID: \(String(item.adamId))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.blue)

                    if let d = item.purchaseDate {
                        Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        Text(dateFormatted(d))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                    }

                    if savedIPA != nil {
                        Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("В библиотеке")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Theme.Colors.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.greenTint(for: colorScheme))
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let saved = savedIPA {
                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: false)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Скачать")
                        }
                    }
                    .liquidGlass(variant: .glass, size: .sm)
                    .help("Скачать IPA заново")

                    Button(action: {
                        startInstallFlow(ipaPath: saved.path, name: item.name)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Установить")
                        }
                    }
                    .liquidGlass(variant: .green, size: .sm)
                } else {
                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: false)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Скачать")
                        }
                    }
                    .liquidGlass(variant: .glass, size: .sm)
                    .help("Скачать IPA в Библиотеку")

                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: true)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.to.line.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Скачать и установить")
                        }
                    }
                    .liquidGlass(variant: .primary, size: .sm)
                    .help("Скачать и установить на iPhone")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Colors.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - 3. Custom ID View
    private var customIdView: some View {
        let valid = customAdamId.trimmingCharacters(in: .whitespaces).count >= 6 && Int64(customAdamId.trimmingCharacters(in: .whitespaces)) != nil

        return VStack(spacing: 0) {
            pageHeaderBar(
                title: "Установка по Adam ID",
                subtitle: "Прямая загрузка официального IPA"
            ) {
                EmptyView()
            }

            Spacer()

            VStack(spacing: 24) {
                // 72x72 Glowing App Logo (Squircle radius 19 continuous)
                ZStack {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 92/255, green: 188/255, blue: 255/255), Color(red: 26/255, green: 124/255, blue: 255/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.blue.opacity(0.45), radius: 18, x: 0, y: 6)

                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("Восстановление по Adam ID")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                    Text("Введите числовой идентификатор любого приложения из App Store для прямой загрузки официального IPA.")
                        .font(.system(size: 13.5))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "number")
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                            .font(.system(size: 15, weight: .bold))

                        TextField("Например: 570510529", text: $customAdamId)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .onSubmit {
                                if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                    startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: false)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .frame(width: 380, height: 44)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.controlBackground(for: colorScheme))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Button(action: {
                            if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: false)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Скачать IPA")
                            }
                        }
                        .liquidGlass(variant: .glass, size: .lg)
                        .disabled(!valid)

                        Button(action: {
                            if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Скачать и установить")
                            }
                        }
                        .liquidGlass(variant: .primary, size: .lg)
                        .disabled(!valid)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Colors.cardBackground(for: colorScheme))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 4. Saved IPA Library View
    private var savedIPAsHeader: some View {
        frostedGlassHeader {
            VStack(spacing: 0) {
                pageHeaderContent(
                    title: "Библиотека IPA",
                    subtitle: "\(savedIPAs.count) сохранённых файлов IPA"
                ) {
                    HStack(spacing: 10) {
                        searchField(query: $savedIPASearchQuery, placeholder: "Поиск в библиотеке...", width: 220)

                        Button(action: { importIpaFile() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Импорт IPA")
                            }
                        }
                        .liquidGlass(variant: .glass, size: .md)

                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: effectiveLibraryPath))
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .liquidGlass(variant: .glass, size: .md)
                        .help("Открыть в Finder")
                    }
                }

                if !savedIPAs.isEmpty {
                    Rectangle()
                        .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                        .frame(height: 0.5)

                    HStack(spacing: 10) {
                        Button(selectedSavedIPAPaths.count == savedIPAs.count ? "Снять выбор" : "Выбрать все (\(savedIPAs.count))") {
                            if selectedSavedIPAPaths.count == savedIPAs.count {
                                selectedSavedIPAPaths.removeAll()
                            } else {
                                selectedSavedIPAPaths = Set(savedIPAs.map { $0.path })
                            }
                        }
                        .liquidGlass(variant: .glass, size: .sm)

                        if !selectedSavedIPAPaths.isEmpty {
                            Text("Выбрано: \(selectedSavedIPAPaths.count)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Theme.Colors.blue)

                            Button(action: { startBatchInstallSavedIPAs() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                    Text("Установить (\(selectedSavedIPAPaths.count))")
                                }
                            }
                            .liquidGlass(variant: .primary, size: .sm)
                            .disabled(isBatchInstallingIPAs)

                            Button(action: {
                                for p in selectedSavedIPAPaths { try? FileManager.default.removeItem(atPath: p) }
                                selectedSavedIPAPaths.removeAll()
                                loadSavedIPAs()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                    Text("Удалить (\(selectedSavedIPAPaths.count))")
                                }
                            }
                            .liquidGlass(variant: .destructive, size: .sm)
                        }

                        Spacer()

                        if isBatchInstallingIPAs {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.6)
                                Text("Установка: \(batchInstallCurrent)/\(batchInstallTotal)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                }
            }
        }
    }

    private var savedIPAsView: some View {
        Group {
            if savedIPAs.isEmpty {
                emptyStateView(
                    icon: "archivebox",
                    title: "Библиотека IPA пуста",
                    subtitle: "Скачивайте приложения из покупок Apple ID или нажмите «Импорт IPA», чтобы добавить свои файлы."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSavedIPAs) { item in
                            savedIPARow(item: item)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            savedIPAsHeader
        }
    }

    private func savedIPARow(item: SavedIPA) -> some View {
        let isSelected = selectedSavedIPAPaths.contains(item.path)

        return HStack(spacing: 12) {
            Button(action: {
                if isSelected { selectedSavedIPAPaths.remove(item.path) }
                else { selectedSavedIPAPaths.insert(item.path) }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Theme.Colors.blue : Theme.Colors.textTertiary(for: colorScheme))
            }
            .buttonStyle(.plain)

            // App Icon
            appIconView(url: item.artworkUrl, name: item.displayName)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    if !item.version.isEmpty {
                        Text(item.version)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            .clipShape(Capsule())
                    }

                    Text(item.size)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.purpleTint(for: colorScheme))
                        .foregroundColor(Theme.Colors.purple)
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    Text(item.filename)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    Text("•").foregroundColor(Theme.Colors.textTertiary(for: colorScheme))

                    Text(item.date)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(action: {
                    startInstallFlow(ipaPath: item.path, name: item.displayName)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Установить")
                    }
                }
                .liquidGlass(variant: .primary, size: .sm)

                Button(action: {
                    try? FileManager.default.removeItem(atPath: item.path)
                    loadSavedIPAs()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help("Удалить из библиотеки")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.Colors.blueTint(for: colorScheme) : Theme.Colors.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.Colors.blue.opacity(0.4) : Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - 5. Settings View (Theme & Library Path)
    private var settingsHeader: some View {
        pageHeaderBar(
            title: "Настройки",
            subtitle: "Оформление, библиотека и параметры установки"
        ) {
            EmptyView()
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Appearance
                settingsCard(title: "Оформление интерфейса", icon: "paintbrush.fill", iconColor: Theme.Colors.purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Тема приложения")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                        Picker("Тема оформления", selection: $storedScheme) {
                            Text("Системная").tag("system")
                            Text("Светлая").tag("light")
                            Text("Тёмная").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)

                        Text("Выбор цветовой темы применяется мгновенно ко всем окнам и модальным панелям Open Store.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                    }
                }

                // Section 2: Library Storage
                settingsCard(title: "Расположение библиотеки IPA", icon: "archivebox.fill", iconColor: Theme.Colors.green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Папка для сохранения скачанных .ipa файлов")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                        HStack(spacing: 8) {
                            Text(effectiveLibraryPath)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.Colors.controlBackground(for: colorScheme), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
                                )

                            Button("Выбрать...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.canCreateDirectories = true
                                panel.prompt = "Выбрать папку"
                                if panel.runModal() == .OK, let url = panel.url {
                                    customLibraryPath = url.path
                                    loadSavedIPAs()
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)

                            if !customLibraryPath.isEmpty {
                                Button("Сбросить") {
                                    customLibraryPath = ""
                                    loadSavedIPAs()
                                }
                                .liquidGlass(variant: .glass, size: .sm)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: effectiveLibraryPath))
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder")
                                    Text("Показать в Finder")
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)

                            Text("По умолчанию: ~/Downloads/Open Store")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        }
                    }
                }

                // Section 3: Engine Mode
                settingsCard(title: "Движок установки и восстановления", icon: "bolt.fill", iconColor: Theme.Colors.blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Выберите основной метод работы приложения:")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))

                        // Option 1: Direct Standalone (Default & Recommended)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                installEngineMode = InstallEngineMode.direct.rawValue
                                preferDirectMode = true
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(currentEngineMode == .direct ? Theme.Colors.blue : Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    if currentEngineMode == .direct {
                                        Circle()
                                            .fill(Theme.Colors.blue)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 14))

                                        Text("Прямой нативный режим (Open Store Core)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                                        Text("По умолчанию")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.Colors.blue)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(Theme.Colors.blueTint(for: colorScheme))
                                            .clipShape(Capsule())
                                    }

                                    Text("Молниеносная установка за 2–3 секунды в фоновом режиме через системный сервис iOS. Не требует запуска сторонних утилит, AppleScript и разрешений системы.")
                                        .font(.system(size: 12.5))
                                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(currentEngineMode == .direct ? Theme.Colors.blueTint(for: colorScheme) : Theme.Colors.cardBackground(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(currentEngineMode == .direct ? Theme.Colors.blue.opacity(0.45) : Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // Option 2: Apple Configurator (Legacy / Fallback)
                        if engine.isConfiguratorInstalled {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    installEngineMode = InstallEngineMode.configurator.rawValue
                                    preferDirectMode = false
                                }
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(currentEngineMode == .configurator ? Theme.Colors.amber : Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1.5)
                                            .frame(width: 18, height: 18)
                                        if currentEngineMode == .configurator {
                                            Circle()
                                                .fill(Theme.Colors.amber)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "gearshape.2.fill")
                                                .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                                                .font(.system(size: 14))

                                            Text("Apple Configurator (Резервный режим)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                                            Text("Резерв")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.Colors.amber)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2.5)
                                                .background(Theme.Colors.orangeTint(for: colorScheme))
                                                .clipShape(Capsule())
                                        }

                                        Text("Классический режим через графический интерфейс Apple Configurator и базу данных CoreData. Включается только при необходимости.")
                                            .font(.system(size: 12.5))
                                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(currentEngineMode == .configurator ? Theme.Colors.orangeTint(for: colorScheme) : Theme.Colors.cardBackground(for: colorScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(currentEngineMode == .configurator ? Theme.Colors.amber.opacity(0.45) : Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            if currentEngineMode == .configurator {
                                Divider().padding(.vertical, 4)

                                Toggle(isOn: $autoClickConfigurator) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Автоматизация кликов в Apple Configurator")
                                            .font(.system(size: 12.5, weight: .semibold))
                                        Text("Автоматически нажимает кнопку «Добавить» и закрывает диалоги замены.")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if autoClickConfigurator && !engine.isAccessibilityGranted {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⚠️ Требуется разрешение")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(.red)
                                        Text("Для автоматических кликов нужно разрешить управление компьютером.")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.secondary)
                                        Button("Разрешить в Системных настройках") {
                                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                            AXIsProcessTrustedWithOptions(options as CFDictionary)
                                        }
                                        .liquidGlass(variant: .destructive, size: .sm)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.redTint(for: colorScheme))
                                    .cornerRadius(10)
                                }
                            }
                        } else {
                            // Missing Configurator Memo
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Резервный режим недоступен")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    Text("Open Store имеет два режима скачивания. Прямой режим включен по умолчанию. Чтобы использовать резервный режим, скачайте Apple Configurator из Mac App Store (если ваша версия macOS его поддерживает).")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.primary.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.Colors.cardBorder(for: colorScheme), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                    }
                }

                // Section 4: Diagnostics & Logs
                settingsCard(title: "Диагностика и системный журнал", icon: "doc.text.magnifyingglass", iconColor: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Файл системного журнала Open Store:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))

                        HStack(spacing: 8) {
                            Text(LogManager.shared.logFilePath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.Colors.controlBackground(for: colorScheme), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
                                )

                            Button(action: {
                                if LogManager.shared.copyLogToClipboard() {
                                    copiedLogsToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        copiedLogsToast = false
                                    }
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: copiedLogsToast ? "checkmark" : "doc.on.doc")
                                    Text(copiedLogsToast ? "Скопировано!" : "Копировать логи")
                                }
                            }
                            .liquidGlass(variant: copiedLogsToast ? .green : .glass, size: .sm)

                            Button(action: {
                                LogManager.shared.clearLog()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                    Text("Очистить")
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)

                            Button(action: {
                                let logUrl = URL(fileURLWithPath: LogManager.shared.logFilePath)
                                NSWorkspace.shared.activateFileViewerSelecting([logUrl])
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.forward.app")
                                    Text("Показать лог")
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)
                        }

                        Text("Лог-файл автоматически сохраняет диагностические сообщения, ошибки сетевых запросов и события установки.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                    }
                }

                // Section 5: Software Updates
                settingsCard(title: "Обновление программы", icon: "arrow.triangle.2.circlepath.circle.fill", iconColor: Theme.Colors.purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Текущая версия: Open Store v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.3")")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                Text("Проверка релизов на GitHub в реальном времени.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            }
                            Spacer()
                            Button(action: {
                                Task {
                                    _ = await engine.checkForUpdates()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if engine.isCheckingUpdates {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(engine.isCheckingUpdates ? "Проверка..." : "Проверить обновления")
                                }
                            }
                            .liquidGlass(variant: .glass, size: .sm)
                            .disabled(engine.isCheckingUpdates)
                        }

                        Divider()

                        Toggle(isOn: $autoCheckUpdates) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Автоматически проверять обновления при запуске")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Приложение будет оповещать вас о выходе новых версий с GitHub.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            }
                        }

                        if engine.isUpdatingApp {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView(value: engine.updateDownloadProgress)
                                        .progressViewStyle(.linear)
                                    Text("\(Int(engine.updateDownloadProgress * 100))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                }

                                HStack {
                                    Text(engine.updateStatusStage)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .padding(12)
                            .background(Theme.Colors.blueTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
                        } else if let info = engine.latestUpdateInfo {
                            if info.isNewer {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.yellow)
                                        Text("Доступна новая версия: \(info.version)!")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.green)
                                        Spacer()
                                    }

                                    if !info.releaseNotes.isEmpty {
                                        Text(info.releaseNotes)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                            .lineLimit(4)
                                    }

                                    HStack(spacing: 8) {
                                        Button(action: {
                                            Task {
                                                _ = await engine.performSelfUpdate(updateInfo: info)
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                                Text("Обновить и перезапустить")
                                            }
                                        }
                                        .liquidGlass(variant: .green, size: .sm)

                                        if let dUrl = info.downloadUrl, let url = URL(string: dUrl) {
                                            Button("Открыть на GitHub") {
                                                NSWorkspace.shared.open(url)
                                            }
                                            .liquidGlass(variant: .glass, size: .sm)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Theme.Colors.greenTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                        Text("У вас установлена актуальная версия (\(info.version)).")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                                        Spacer()
                                        Button("Переустановить с GitHub") {
                                            Task {
                                                _ = await engine.performSelfUpdate(updateInfo: info)
                                            }
                                        }
                                        .liquidGlass(variant: .glass, size: .sm)
                                    }
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                            }
                        } else if let err = engine.updateCheckError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Ошибка проверки: \(err)")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            }
                            .padding(10)
                            .background(Theme.Colors.orangeTint(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Section 6: About
                settingsCard(title: "О программе Open Store", icon: "info.circle.fill", iconColor: .secondary) {
                    HStack(spacing: 14) {
                        AppLogoView(size: 44, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Open Store")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                            Text("Нативный клиент установки и восстановления iOS-приложений с официальной FairPlay DRM лицензией Apple ID.")
                                .font(.system(size: 11.5))
                                .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                        }
                    }
                }

                Text("Open Store 2.0 (build 2604) • macOS 26 Tahoe")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, (engine.isVpnActive && !vpnNoticeDismissed) ? 8 : 16)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            settingsHeader
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                // 28x28 Squircle Icon Badge with continuous corner radius 8
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.88), iconColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: iconColor.opacity(0.3), radius: 3, x: 0, y: 1)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Apple ID Sheet
    private var appleIdSheet: some View {
        liquidGlassSheet {
            VStack(spacing: 0) {
                HStack {
                    Text("Учётная запись Apple ID")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Закрыть") {
                        showAppleIdSheet = false
                        appleIdAuthError = ""
                        appleIdAuthSuccess = ""
                        is2FARequired = false
                        appleIdPasswordInput = ""
                        appleId2FACodeInput = ""
                        isPasswordVisible = false
                    }
                    .liquidGlass(variant: .glass, size: .sm)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                    .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 16) {
                if engine.isVpnActive {
                    vpnWarningBanner
                }

                if engine.isDirectAppleIdAuthenticated && !engine.activeAppleIdEmail.isEmpty {
                    // Authenticated Card
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 46, height: 46)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(engine.activeAppleIdName.isEmpty ? "Пользователь Apple ID" : engine.activeAppleIdName)
                                    .font(.system(size: 15, weight: .bold))

                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("Аккаунт авторизован")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            }

                            Text(engine.activeAppleIdEmail)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            HStack(spacing: 6) {
                                if !engine.currentAccountDsid.isEmpty {
                                    Text("DSID: \(engine.currentAccountDsid)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text("•").foregroundColor(.secondary)
                                }
                                Text("Покупок в базе: \(engine.purchasedApps.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        Button(action: {
                            engine.refreshPurchasedApps()
                            engine.refreshAppleIdStatus()
                        }) {
                            Label("Синхронизировать покупки", systemImage: "arrow.clockwise")
                        }
                        .liquidGlass(variant: .glass, size: .sm)

                        Spacer()

                        Button(role: .destructive, action: {
                            Task {
                                _ = await engine.logoutAppleId()
                            }
                        }) {
                            Label("Сменить аккаунт / Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .liquidGlass(variant: .destructive, size: .sm)
                    }
                } else {
                    // Login Form
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Вход в Apple ID")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Для прямой загрузки и лицензирования приложений из App Store")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(spacing: 10) {
                            TextField("Apple ID (email@example.com)", text: $appleIdEmailInput)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)

                            // Password with Eye preview toggle
                            HStack {
                                if isPasswordVisible {
                                    TextField("Пароль Apple ID", text: $appleIdPasswordInput)
                                        .textFieldStyle(.plain)
                                } else {
                                    SecureField("Пароль Apple ID", text: $appleIdPasswordInput)
                                        .textFieldStyle(.plain)
                                }
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .help(isPasswordVisible ? "Скрыть пароль" : "Показать пароль")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )

                            if is2FARequired {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13))
                                        Text("Проверочный код (2FA):")
                                            .font(.system(size: 12, weight: .bold))
                                        Spacer()
                                        Button(action: {
                                            appleId2FACodeInput = ""
                                            isLoggingInAppleId = true
                                            appleIdAuthError = ""
                                            Task {
                                                let (ok, req2fa, msg) = await engine.loginAppleId(
                                                    email: appleIdEmailInput,
                                                    password: appleIdPasswordInput,
                                                    code: nil
                                                )
                                                DispatchQueue.main.async {
                                                    self.isLoggingInAppleId = false
                                                    if ok {
                                                        self.appleIdAuthSuccess = "Вход успешно выполнен!"
                                                        self.is2FARequired = false
                                                        self.appleIdPasswordInput = ""
                                                        self.appleId2FACodeInput = ""
                                                        self.engine.refreshAppleIdStatus()
                                                        self.engine.refreshPurchasedApps()
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                            self.showAppleIdSheet = false
                                                        }
                                                    } else {
                                                        self.is2FARequired = req2fa
                                                        self.appleIdAuthError = msg
                                                    }
                                                }
                                            }
                                        }) {
                                            Label("Запросить новый код", systemImage: "arrow.clockwise")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.blue)
                                        .disabled(isLoggingInAppleId)
                                    }

                                    TextField("Введите 6 цифр (например: 123456)", text: $appleId2FACodeInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))

                                    Text("Нажмите «Разрешить» на всплывшем окне Apple и введите появившийся код.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }

                        if !appleIdAuthError.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 11))
                                Text(appleIdAuthError)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        if !appleIdAuthSuccess.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                                Text(appleIdAuthSuccess)
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        HStack {
                            Spacer()
                            Button(action: {
                                guard !appleIdEmailInput.isEmpty, !appleIdPasswordInput.isEmpty else {
                                    appleIdAuthError = "Введите email и пароль Apple ID"
                                    return
                                }
                                if is2FARequired && appleId2FACodeInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    appleIdAuthError = "Введите 6-значный код 2FA"
                                    return
                                }
                                isLoggingInAppleId = true
                                appleIdAuthError = ""
                                appleIdAuthSuccess = ""

                                Task {
                                    let (ok, req2fa, msg) = await engine.loginAppleId(
                                        email: appleIdEmailInput,
                                        password: appleIdPasswordInput,
                                        code: is2FARequired ? appleId2FACodeInput : nil
                                    )
                                    DispatchQueue.main.async {
                                        self.isLoggingInAppleId = false
                                        if ok {
                                            self.appleIdAuthSuccess = "Вход успешно выполнен!"
                                            self.is2FARequired = false
                                            self.appleIdPasswordInput = ""
                                            self.appleId2FACodeInput = ""
                                            self.engine.refreshAppleIdStatus()
                                            self.engine.refreshPurchasedApps()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                self.showAppleIdSheet = false
                                            }
                                        } else if req2fa {
                                            self.is2FARequired = true
                                            self.appleIdAuthError = msg
                                        } else {
                                            self.appleIdAuthError = msg
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isLoggingInAppleId {
                                        ProgressView().controlSize(.small)
                                    }
                                    Text(is2FARequired ? "Подтвердить код (2FA)" : "Войти")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 16)
                            }
                            .liquidGlass(variant: .primary, size: .md)
                            .disabled(isLoggingInAppleId || appleIdEmailInput.isEmpty || appleIdPasswordInput.isEmpty || (is2FARequired && appleId2FACodeInput.trimmingCharacters(in: .whitespaces).isEmpty))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                    )
                }

                // Security Note
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.blue)
                    Text("Авторизация выполняется напрямую через защищенный протокол Apple Store. Ваши учетные данные шифруются по алгоритму AES-256 и сохраняются локально в изолированном файловом хранилище Open Store.")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                }
                .padding(10)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
        }
        .frame(width: 480)
        }
        .onAppear {
            if appleIdEmailInput.isEmpty && !engine.activeAppleIdEmail.isEmpty && !engine.activeAppleIdEmail.contains("DSID") && !engine.isDirectAppleIdAuthenticated {
                appleIdEmailInput = engine.activeAppleIdEmail
            }
        }
        .onDisappear {
            if !engine.isDirectAppleIdAuthenticated {
                is2FARequired = false
                appleIdPasswordInput = ""
                appleId2FACodeInput = ""
                appleIdAuthError = ""
                appleIdAuthSuccess = ""
                isPasswordVisible = false
            }
        }
    }

    // MARK: - Shared Icon Helper
    private func appIconView(url: String?, name: String) -> some View {
        Group {
            if let u = url, let imgUrl = URL(string: u) {
                AsyncImage(url: imgUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallbackIcon(name: name)
                    }
                }
            } else {
                fallbackIcon(name: name)
            }
        }
        .frame(width: Theme.Metrics.iconSizeLarge, height: Theme.Metrics.iconSizeLarge)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusIcon, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusIcon, style: .continuous)
                .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func fallbackIcon(name: String) -> some View {
        ZStack {
            LinearGradient(colors: [Theme.Colors.blue.opacity(0.8), Color.indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Restore & Install Progress Sheet
    private var restoreProgressSheet: some View {
        liquidGlassSheet {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(restoringAdamId == 0 ? "Установка на iPhone" : (shouldInstallAfterDownload ? "Загрузка и установка" : "Загрузка IPA"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(restoringAppName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Закрыть") {
                        if restoringAdamId > 0 {
                            engine.removeRestoreRequest(adamId: restoringAdamId)
                        }
                        isRestoring = false
                    }
                    .liquidGlass(variant: .glass, size: .sm)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                    .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 12) {
                // Safety badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text("Безопасный режим: Данные устройства, контакты, фото и другие приложения защищены")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.08))
                .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(engine.operationStage.isEmpty ? engine.currentStatus : engine.operationStage)
                            .font(.system(size: 12, weight: .medium))
                        .lineLimit(4)
                        Spacer()
                        Text("\(Int(round(engine.operationProgress * 100)))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    ProgressView(value: engine.operationProgress, total: 1.0)
                        .progressViewStyle(.linear)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(engine.progressLogs, id: \.self) { log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(NSColor.labelColor))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(height: 140)
                .background(Theme.Colors.cardBackground(for: colorScheme))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                )

                HStack {
                    if restoringAdamId > 0 {
                        Toggle("Установить на iPhone сразу после скачивания", isOn: $shouldInstallAfterDownload)
                            .font(.system(size: 11))
                    }
                    Spacer()
                    if restoreSuccessIPA != nil || engine.operationProgress >= 1.0 {
                        Button("Готово") {
                            isRestoring = false
                            loadSavedIPAs()
                        }
                        .liquidGlass(variant: .green, size: .md)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 540)
        }
    }

    // MARK: - Device Manager Sheet (iMazing Style)
    private var deviceManagerSheet: some View {
        liquidGlassSheet {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Менеджер устройств")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Text("Управление подключенными iPhone/iPad, связью по USB и Wi-Fi, историей и сопряжением")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        engine.refreshDevices()
                    }) {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                    .liquidGlass(variant: .glass, size: .sm)

                    Button("Закрыть") {
                        showDeviceManagerSheet = false
                    }
                    .liquidGlass(variant: .primary, size: .sm)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                    .frame(height: 0.5)

            // Main Split Body: Left List, Right Inspector
            HStack(spacing: 0) {
                // Left Column: Devices List
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // Section 1: Connected Devices (Online)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("ПОДКЛЮЧЕНЫ СЕЙЧАС (\(engine.connectedDevices.count))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)

                                if engine.connectedDevices.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "cable.connector")
                                            .foregroundColor(.secondary)
                                        Text("Нет подключенных устройств")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                                } else {
                                    ForEach(engine.connectedDevices) { dev in
                                        deviceListCard(dev: dev, isOnline: true)
                                    }
                                }
                            }

                            // Section 2: Remembered / Previously Connected Devices (History)
                            let offlineDevices = engine.knownDevices.filter { k in !engine.connectedDevices.contains(where: { $0.id == k.id }) }
                            if !offlineDevices.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("РАНЕЕ ПОДКЛЮЧАЛИСЬ (\(offlineDevices.count))")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.top, 6)

                                    ForEach(offlineDevices) { dev in
                                        deviceListCard(dev: dev, isOnline: false)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(width: 300)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

                Divider()

                // Right Column: Detailed Device Inspector
                let currentDev = selectedDeviceForDetail ?? engine.activeDevice ?? engine.connectedDevices.first ?? engine.knownDevices.first

                if let dev = currentDev {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Device Hero Banner
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: dev.isOnline ? [Color.blue, Color.cyan] : [Color.gray, Color.secondary],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(color: dev.isOnline ? Color.blue.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 2)

                                    Image(systemName: "iphone.gen3")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(dev.formattedDisplayName)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))

                                        // Connection Type Badge
                                        HStack(spacing: 4) {
                                            Image(systemName: dev.connectionType.icon)
                                                .font(.system(size: 10, weight: .bold))
                                            Text(dev.isOnline ? dev.connectionType.rawValue : "Не в сети")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(dev.isOnline ? (dev.connectionType == .usb ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)) : Color.secondary.opacity(0.15))
                                        .foregroundColor(dev.isOnline ? (dev.connectionType == .usb ? .green : .blue) : .secondary)
                                        .clipShape(Capsule())

                                        if dev.id == engine.activeDevice?.id {
                                            Text("Активно")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    HStack(spacing: 6) {
                                        Text("Владелец: **\(dev.ownerName)**")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Text("•").foregroundColor(.secondary)
                                        Text(dev.iosVersion)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }

                                    if !dev.isOnline {
                                        Text("Последнее подключение: \(formatDate(dev.lastSeen))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )

                            // Specs Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Характеристики и параметры")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 0) {
                                    deviceInfoRow(label: "Владелец", value: dev.ownerName)
                                    Divider().opacity(0.25).padding(.vertical, 5)
                                    deviceInfoRow(label: "Имя устройства", value: dev.name)
                                    Divider().opacity(0.25).padding(.vertical, 5)
                                    deviceInfoRow(label: "Модель", value: "\(dev.marketingName) (\(dev.modelIdentifier))")
                                    Divider().opacity(0.25).padding(.vertical, 5)
                                    deviceInfoRow(label: "Версия системы", value: dev.iosVersion)
                                    Divider().opacity(0.25).padding(.vertical, 5)
                                    deviceInfoRow(label: "Тип связи", value: dev.connectionType == .usb ? "USB-кабель (Прямой канал)" : (dev.connectionType == .wifi ? "Wi-Fi сеть (Беспроводная синхронизация)" : "Отключено"))
                                    if !dev.battery.isEmpty {
                                        Divider().opacity(0.25).padding(.vertical, 5)
                                        deviceInfoRow(label: "Уровень заряда", value: dev.battery)
                                    }
                                    if !dev.diskCapacity.isEmpty {
                                        Divider().opacity(0.25).padding(.vertical, 5)
                                        deviceInfoRow(label: "Память накопителя", value: dev.diskCapacity)
                                    }
                                    if !dev.serialNumber.isEmpty {
                                        Divider().opacity(0.25).padding(.vertical, 5)
                                        deviceInfoRow(label: "Серийный номер", value: dev.serialNumber, isMonospaced: true)
                                    }
                                    if !dev.wifiAddress.isEmpty {
                                        Divider().opacity(0.25).padding(.vertical, 5)
                                        deviceInfoRow(label: "Wi-Fi MAC-адрес", value: dev.wifiAddress, isMonospaced: true)
                                    }
                                    Divider().opacity(0.25).padding(.vertical, 5)
                                    deviceInfoRow(label: "UDID", value: dev.udid, isMonospaced: true)
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )

                            // Actions Card
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Управление устройством")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))

                                HStack(spacing: 10) {
                                    if dev.id != engine.activeDevice?.id {
                                        Button(action: {
                                            engine.selectDevice(id: dev.id)
                                            selectedDeviceForDetail = dev
                                        }) {
                                            Label("Сделать активным", systemImage: "checkmark.circle.fill")
                                        }
                                        .liquidGlass(variant: .primary, size: .sm)
                                    }

                                    if dev.isOnline {
                                        Button(action: {
                                            showDeviceManagerSheet = false
                                            storedSidebarTab = SidebarItem.device.rawValue
                                            engine.scanInstalledAppsFromDevice(catalog: catalogApps)
                                        }) {
                                            Label("Сканировать приложения", systemImage: "arrow.clockwise")
                                        }
                                        .liquidGlass(variant: .glass, size: .sm)
                                    }

                                    Spacer()

                                    Button(action: {
                                        deviceToForget = dev
                                        showForgetConfirmDialog = true
                                    }) {
                                        Label("Удалить связь", systemImage: "trash")
                                    }
                                    .liquidGlass(variant: .destructive, size: .sm)
                                    .help("Удалить сопряжение и историю устройства")
                                }
                            }
                            .padding(14)
                            .background(Theme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.Colors.cardBorder(for: colorScheme), lineWidth: 1)
                            )
                        }
                        .padding(16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "cable.connector")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.Colors.textTertiary(for: colorScheme))
                        Text("Устройства не найдены")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                        Text("Подключите iPhone через USB-кабель или по Wi-Fi для управления и установки приложений.")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 820, height: 570)
        }
    }

    private func deviceListCard(dev: DeviceInfo, isOnline: Bool) -> some View {
        let isActive = engine.activeDevice?.id == dev.id
        let isSelected = (selectedDeviceForDetail?.id ?? engine.activeDevice?.id) == dev.id
        return Button(action: {
            selectedDeviceForDetail = dev
            if isOnline {
                engine.selectDevice(id: dev.id)
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isOnline ? (dev.connectionType == .usb ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)) : Color.secondary.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: isOnline ? dev.connectionType.icon : "icloud.slash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isOnline ? (dev.connectionType == .usb ? .green : .blue) : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(dev.formattedDisplayName)
                            .font(.system(size: 12, weight: isActive ? .bold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if isOnline {
                            Text(dev.connectionType == .usb ? "USB" : "Wi-Fi")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(dev.connectionType == .usb ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                                .foregroundColor(dev.connectionType == .usb ? .green : .blue)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 4) {
                        Text(dev.ownerName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        Text("•").foregroundColor(.secondary).font(.system(size: 9))
                        Text(dev.iosVersion)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isActive {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Активно")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.green.opacity(0.08) : (isSelected ? Color.blue.opacity(0.08) : Color.primary.opacity(0.03)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? Color.green.opacity(0.3) : (isSelected ? Color.blue.opacity(0.2) : Color.primary.opacity(0.06)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func deviceInfoRow(label: String, value: String, isMonospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            
            Spacer().frame(width: 12)
            
            Text(value)
                .font(isMonospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Manual Adam ID Sheet
    private var manualAdamIdSheet: some View {
        liquidGlassSheet {
            VStack(spacing: 0) {
                HStack {
                    Text("Указать Adam ID")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Закрыть") { showManualAdamIdDialog = false }
                        .liquidGlass(variant: .glass, size: .sm)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.Colors.cardBorder(for: colorScheme).opacity(0.18))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Приложение: **\(manualAppName)**")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textPrimary(for: colorScheme))
                    Text("Bundle ID: `\(manualBundleId)`")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary(for: colorScheme))

                    TextField("Числовой Adam ID (например: 570510529)", text: $manualEnteredId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.controlBackground(for: colorScheme), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Theme.Colors.controlBorder(for: colorScheme), lineWidth: 1)
                        )
                        .onSubmit {
                            if let aid = Int64(manualEnteredId.trimmingCharacters(in: .whitespaces)) {
                                engine.saveUserMapping(bundleId: manualBundleId, adamId: aid)
                                showManualAdamIdDialog = false
                            }
                        }

                    HStack {
                        Spacer()
                        Button("Сохранить") {
                            if let aid = Int64(manualEnteredId.trimmingCharacters(in: .whitespaces)) {
                                engine.saveUserMapping(bundleId: manualBundleId, adamId: aid)
                                showManualAdamIdDialog = false
                            }
                        }
                        .liquidGlass(variant: .primary, size: .sm)
                        .disabled(Int64(manualEnteredId.trimmingCharacters(in: .whitespaces)) == nil)
                    }
                }
                .padding(20)
            }
            .frame(width: 420)
        }
    }

    // MARK: - Business Logic

    private func startBatchDownload(installToDevice: Bool) {
        LogManager.shared.log("👤 Действие пользователя: Запуск пакетного скачивания \(installToDevice ? "с установкой" : "")", level: "USER_ACTION")
        guard !selectedAdamIds.isEmpty, !isBatchDownloading else { return }

        let selectedApps: [(adamId: Int64, name: String)] = selectedAdamIds.compactMap { aid in
            engine.oldDeviceApps.first(where: { $0.adamId == aid }).map { (aid, $0.name) }
        }.sorted { $0.name < $1.name }

        batchTotal = selectedApps.count
        batchDone = 0
        isBatchDownloading = true
        selectedAdamIds.removeAll()

        Task {
            for (adamId, name) in selectedApps {
                engine.appendLog("📦 Пакетная загрузка [\(batchDone + 1)/\(batchTotal)]: \(name)")
                try? await Task.sleep(nanoseconds: 800_000_000)

                var downloadSuccess = false
                var downloadedPath: String? = nil

                if currentEngineMode == .direct {
                    let (ok, msg, ipa) = await engine.downloadDirectAppStore(adamId: adamId, name: name)
                    if ok, let p = ipa {
                        downloadSuccess = true
                        downloadedPath = p
                        engine.appendLog("✅ Скачан: \(name)")
                    } else if msg.contains("AUTH_REQUIRED") {
                        engine.appendLog("🔐 Требуется авторизация в Apple ID...")
                        DispatchQueue.main.async {
                            self.isBatchDownloading = false
                            self.showAppleIdSheet = true
                        }
                        break
                    } else {
                        engine.appendLog("⚠️ Не удалось скачать «\(name)»: \(msg)")
                    }
                } else {
                    // Configurator Mode
                    do {
                        engine.cleanAllRestoreRequests()
                        try engine.injectRestoreRequest(adamId: adamId)
                        if engine.isConfiguratorRunning() { engine.quitConfigurator() }
                        engine.openConfigurator()
                        if autoClickConfigurator {
                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                            engine.executeConfiguratorAutomation(adamId: adamId, appName: name)
                        }
                        let result = try await engine.watchAndCapture(adamId: adamId, knownName: name, timeout: 300.0)
                        downloadSuccess = true
                        downloadedPath = result.path
                        engine.removeRestoreRequest(adamId: adamId)
                        engine.dismissConfiguratorModals()
                    } catch {
                        engine.appendLog("❌ Ошибка Configurator: \(error.localizedDescription)")
                        engine.removeRestoreRequest(adamId: adamId)
                        engine.dismissConfiguratorModals()
                    }
                }

                if downloadSuccess, installToDevice, let ipa = downloadedPath, let dev = engine.activeDevice ?? engine.connectedDevices.first {
                    let (ok, msg) = await engine.installApp(ipaPath: ipa, udid: dev.udid)
                    engine.appendLog(ok ? "📲 Установлен: \(name)" : "⚠️ \(msg)")
                }

                batchDone += 1
                loadSavedIPAs()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }

            DispatchQueue.main.async {
                isBatchDownloading = false
                alertMessage = "Завершено: \(batchDone) из \(batchTotal)."
                showAlert = true
                loadSavedIPAs()
            }
        }
    }

    private func startInstallFlow(ipaPath: String, name: String) {
        LogManager.shared.log("👤 Действие пользователя: Запуск установки локального IPA \(name)", level: "USER_ACTION")
        if !engine.isDirectAppleIdAuthenticated && currentEngineMode == .direct {
            showAppleIdSheet = true
            return
        }
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            alertMessage = "Файл IPA не найден на диске:\n\(ipaPath)"
            showAlert = true
            return
        }

        guard engine.activeDevice?.isOnline == true || !engine.connectedDevices.isEmpty else {
            alertMessage = "iPhone не подключен!\nПожалуйста, подключите устройство по USB-кабелю, разблокируйте экран и нажмите «Доверять этому компьютеру»."
            showAlert = true
            return
        }

        restoringAdamId = 0
        restoringAppName = name
        shouldInstallAfterDownload = true
        restoreError = nil
        restoreSuccessIPA = nil
        engine.progressLogs = []
        engine.operationProgress = 0.1
        engine.operationStage = "Инициализация установки «\(name)»..."
        isRestoring = true

        let targetUdid = (engine.connectedDevices.first(where: { $0.connectionType == .usb && $0.isOnline }) ?? engine.connectedDevices.first(where: { $0.isOnline }) ?? engine.activeDevice)?.udid ?? ""

        Task {
            let (ok, msg) = await engine.installApp(ipaPath: ipaPath, udid: targetUdid)
            DispatchQueue.main.async {
                if ok {
                    restoreSuccessIPA = ipaPath
                    engine.operationProgress = 1.0
                    engine.operationStage = "«\(name)» успешно установлено!"
                } else {
                    restoreError = msg
                    engine.operationStage = "Ошибка установки: \(msg)"
                }
                loadSavedIPAs()
            }
        }
    }

    private func startRestoreFlow(adamId: Int64, name: String, extVersion: Int64 = 0, installToDevice: Bool = false) {
        LogManager.shared.log("👤 Действие пользователя: Запуск загрузки приложения \(name) из App Store", level: "USER_ACTION")
        if !engine.isDirectAppleIdAuthenticated && currentEngineMode == .direct {
            showAppleIdSheet = true
            return
        }
        guard adamId > 0 else {
            alertMessage = "У приложения «\(name)» отсутствует Adam ID."
            showAlert = true
            return
        }

        if let saved = isSavedInLibrary(adamId: adamId, name: name, bundleId: ""), installToDevice {
            startInstallFlow(ipaPath: saved.path, name: name)
            return
        }

        restoringAdamId = adamId
        restoringAppName = name
        shouldInstallAfterDownload = installToDevice
        restoreError = nil
        restoreSuccessIPA = nil
        engine.progressLogs = []
        engine.operationProgress = 0.1
        engine.operationStage = "Инициализация «\(name)»..."
        isRestoring = true

        Task {
            if currentEngineMode == .direct {
                engine.appendLog("⚡ Прямой нативный режим (Adam ID: \(adamId))...")
                let (ok, msg, ipa) = await engine.downloadDirectAppStore(adamId: adamId, name: name)
                if ok, let path = ipa {
                    engine.appendLog("🎉 Скачан: \(path)")
                    restoreSuccessIPA = path
                    if shouldInstallAfterDownload, let dev = engine.activeDevice ?? engine.connectedDevices.first {
                        let (ok2, msg2) = await engine.installApp(ipaPath: path, udid: dev.udid)
                        engine.appendLog(ok2 ? "✅ Установлено на \(dev.name)!" : "⚠️ \(msg2)")
                        DispatchQueue.main.async {
                            if !ok2 { self.restoreError = msg2 }
                        }
                    }
                    loadSavedIPAs()
                    return
                } else if msg.contains("AUTH_REQUIRED") {
                    engine.appendLog("🔐 Требуется авторизация в Apple ID...")
                    DispatchQueue.main.async {
                        self.isRestoring = false
                        self.showAppleIdSheet = true
                    }
                    return
                } else {
                    engine.appendLog("⚠️ Прямая загрузка не удалась: \(msg)")
                    if engine.isConfiguratorInstalled {
                        engine.appendLog("🔄 Автоматический переход в резервный режим Apple Configurator...")
                        DispatchQueue.main.async {
                            self.engine.operationStage = "Переход в Apple Configurator..."
                        }
                    } else {
                        engine.appendLog("❌ Резервный режим недоступен. Скачивание отменено.")
                        DispatchQueue.main.async {
                            self.restoreError = "Прямая загрузка не удалась, а резервный режим недоступен. Установите Apple Configurator из Mac App Store."
                        }
                        return
                    }
                    // Fallthrough to Configurator mode
                }
            }

            // Apple Configurator Mode
            if engine.isConfiguratorInstalled {
                do {
                    if engine.isConfiguratorRunning() { engine.quitConfigurator() }
                    try engine.injectRestoreRequest(adamId: adamId, extVersion: extVersion)
                    engine.openConfigurator()
                    if autoClickConfigurator {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        engine.executeConfiguratorAutomation(adamId: adamId, appName: name)
                    }
                    let result = try await engine.watchAndCapture(adamId: adamId, knownName: name)
                    engine.appendLog("🎉 IPA сохранён: \(result.path)")
                    restoreSuccessIPA = result.path
                    if shouldInstallAfterDownload, let dev = engine.activeDevice ?? engine.connectedDevices.first {
                        let (ok, msg) = await engine.installApp(ipaPath: result.path, udid: dev.udid)
                        engine.appendLog(ok ? "✅ Установлено на \(dev.name)!" : "⚠️ \(msg)")
                    }
                    engine.removeRestoreRequest(adamId: adamId)
                    loadSavedIPAs()
                } catch {
                    engine.appendLog("Ошибка Configurator: \(error.localizedDescription)")
                    engine.removeRestoreRequest(adamId: adamId)
                    DispatchQueue.main.async {
                        self.restoreError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func loadCatalog() {
        let url = Bundle.main.url(forResource: "catalog", withExtension: "json") ?? URL(fileURLWithPath: "catalog.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [AppItem]].self, from: data) {
            catalogApps = decoded["apps"] ?? []
        }
    }

    private func loadSavedIPAs() {
        let path = effectiveLibraryPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            savedIPAs = []
            return
        }
        var list: [SavedIPA] = []
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"

        for f in files.filter({ $0.hasSuffix(".ipa") || $0.hasSuffix(".tmp") }).sorted(by: <) {
            let full = "\(path)/\(f)"
            if let attrs = try? FileManager.default.attributesOfItem(atPath: full) {
                let sizeBytes = (attrs[.size] as? Int64) ?? 0
                if f.hasSuffix(".tmp") || sizeBytes < 500_000 {
                    // Automatically clean up broken / 22-byte dummy files and unfinished tmp files
                    try? FileManager.default.removeItem(atPath: full)
                    continue
                }
                let sizeMB = String(format: "%.1f MB", Double(sizeBytes) / (1024.0 * 1024.0))
                let modDate = (attrs[.modificationDate] as? Date) ?? Date()
                let baseName = (f as NSString).deletingPathExtension
                var dispName = baseName
                var verStr = ""
                var adamId = ""

                var artUrl: String? = nil

                if let vRange = baseName.range(of: " v", options: .backwards) {
                    dispName = String(baseName[..<vRange.lowerBound])
                    verStr = String(baseName[vRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                } else if let dash = baseName.components(separatedBy: "-").first, Int64(dash) != nil {
                    adamId = dash
                    let rest = String(baseName.dropFirst(dash.count + 1)).trimmingCharacters(in: .whitespaces)
                    if !rest.isEmpty { dispName = rest }
                    if let m = catalogApps.first(where: { String($0.adam_id) == adamId }) {
                        dispName = m.name
                    } else if let devApp = engine.oldDeviceApps.first(where: { String($0.adamId ?? 0) == adamId }) {
                        dispName = devApp.name
                        artUrl = devApp.artworkUrl
                    } else if let p = engine.purchasedApps.first(where: { String($0.adamId) == adamId }) {
                        dispName = p.name
                        artUrl = p.artworkUrl
                    }
                } else if let under = baseName.components(separatedBy: "_").first, Int64(under) != nil {
                    adamId = under
                    let parts = baseName.components(separatedBy: "_")
                    if parts.count > 1 { verStr = parts.last ?? "" }
                    if let m = catalogApps.first(where: { String($0.adam_id) == adamId }) {
                        dispName = m.name
                    } else if let devApp = engine.oldDeviceApps.first(where: { String($0.adamId ?? 0) == adamId }) {
                        dispName = devApp.name
                        artUrl = devApp.artworkUrl
                    } else if let p = engine.purchasedApps.first(where: { String($0.adamId) == adamId }) {
                        dispName = p.name
                        artUrl = p.artworkUrl
                    }
                } else {
                    if let m = catalogApps.first(where: { $0.name.lowercased() == baseName.lowercased() }) {
                        dispName = m.name
                        adamId = String(m.adam_id)
                    } else if let p = engine.purchasedApps.first(where: { $0.name.lowercased() == baseName.lowercased() }) {
                        dispName = p.name
                        artUrl = p.artworkUrl
                        adamId = String(p.adamId)
                    }
                }

                list.append(SavedIPA(
                    filename: f,
                    displayName: dispName,
                    version: verStr,
                    path: full,
                    size: sizeMB,
                    date: df.string(from: modDate),
                    adamId: adamId,
                    artworkUrl: artUrl
                ))
            }
        }
        DispatchQueue.main.async {
            self.savedIPAs = list
        }

        let missingArt = list.filter { ($0.artworkUrl == nil || $0.artworkUrl?.isEmpty == true) && !$0.adamId.isEmpty }
        if !missingArt.isEmpty {
            Task {
                let idList = missingArt.map { $0.adamId }.joined(separator: ",")
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
                                    if let idx = self.savedIPAs.firstIndex(where: { $0.adamId == String(trackId) }) {
                                        self.savedIPAs[idx].artworkUrl = art
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func startBatchInstallSavedIPAs() {
        guard !selectedSavedIPAPaths.isEmpty, !isBatchInstallingIPAs else { return }
        let toInstall = Array(selectedSavedIPAPaths)
        isBatchInstallingIPAs = true
        batchInstallTotal = toInstall.count
        batchInstallCurrent = 0

        Task {
            guard engine.activeDevice?.isOnline == true else {
                alertMessage = "Устройство офлайн!"
                showAlert = true
                isBatchInstallingIPAs = false
                return
            }
            for (idx, ipaPath) in toInstall.enumerated() {
                batchInstallCurrent = idx + 1
                let (ok, msg) = await engine.installApp(ipaPath: ipaPath)
                if !ok { engine.appendLog("Ошибка: \(URL(fileURLWithPath: ipaPath).lastPathComponent): \(msg)") }
            }
            isBatchInstallingIPAs = false
            alertMessage = "Установка \(toInstall.count) приложений завершена!"
            showAlert = true
        }
    }

    private func importIpaFile() {
        LogManager.shared.log("👤 Действие пользователя: Импорт стороннего IPA-файла", level: "USER_ACTION")
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "ipa")].compactMap { $0 }
        if panel.runModal() == .OK {
            for url in panel.urls {
                let dest = "\(effectiveLibraryPath)/\(url.lastPathComponent)"
                try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: dest))
            }
            loadSavedIPAs()
        }
    }

    private func dateFormatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        return df.string(from: date)
    }

    // MARK: - VPN Warning Banners
    private var vpnTopNoticeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)

            Text("⚠️ «Обнаружен активный VPN. Это может приводить к ошибкам авторизации Apple ID, задержкам кодов 2FA и снижению скорости скачивания, а также существует вероятность временной блокировки аккаунта Apple ID со стороны системы безопасности Apple. При возникновении сбоев рекомендуется временно отключить VPN».")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vpnNoticeDismissed = true
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Скрыть предупреждение")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Color.orange.opacity(0.12))
        .overlay(Rectangle().fill(Color.orange.opacity(0.25)).frame(height: 1), alignment: .bottom)
    }

    private var vpnWarningBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Обнаружен активный VPN")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)

                Text("⚠️ «Обнаружен активный VPN. Это может приводить к ошибкам авторизации Apple ID, задержкам кодов 2FA и снижению скорости скачивания, а также существует вероятность временной блокировки аккаунта Apple ID со стороны системы безопасности Apple. При возникновении сбоев рекомендуется временно отключить VPN».")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                    // .fixedSize(horizontal: false, vertical: true) - removed for wrapping
            }
        }
        .padding(18)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Mandatory Update Screen
    private var mandatoryUpdateOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.teal.opacity(0.35), Color.clear], center: .center, startRadius: 20, endRadius: 75))
                        .frame(width: 150, height: 150)

                    if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                       let iconImage = NSImage(contentsOf: iconUrl) {
                        Image(nsImage: iconImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .teal.opacity(0.4), radius: 15, x: 0, y: 5)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.teal)
                            .shadow(color: .teal.opacity(0.5), radius: 15)
                    }
                }

                VStack(spacing: 8) {
                    Text("Open Store")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Обязательное обновление системы")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))

                    if !engine.mandatoryUpdateNewVersion.isEmpty {
                        Text("Версия \(engine.mandatoryUpdateNewVersion)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.teal.opacity(0.2))
                            .foregroundColor(.teal)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.teal.opacity(0.4), lineWidth: 1))
                    }
                }

                VStack(spacing: 12) {
                    ProgressView(value: engine.mandatoryUpdateProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.teal)
                        .frame(width: 320)

                    HStack {
                        Text(engine.mandatoryUpdateStage.isEmpty ? engine.updateStatusStage : engine.mandatoryUpdateStage)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(engine.mandatoryUpdateProgress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.teal)
                    }
                    .frame(width: 320)
                }

                Text("Приложение перезапустится автоматически после завершения установки.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
    }
}
