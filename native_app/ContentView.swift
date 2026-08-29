import SwiftUI
import AppKit

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
}

// MARK: - App Logo View (Blue gradient rounded squircle with white lightning bolt)
struct AppLogoView: View {
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.blue.opacity(0.35), radius: size * 0.15, x: 0, y: 1)

            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: size * 0.46, weight: .bold))
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
        case .device:    return "iphone.and.arrow.forward"
        case .purchases: return "bag.fill"
        case .customId:  return "number.circle.fill"
        case .library:   return "archivebox.fill"
        case .settings:  return "gearshape.fill"
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
    @StateObject private var engine = ConfiguratorEngine.shared
    @State private var catalogApps: [AppItem] = []
    @State private var searchQuery: String = ""
    @State private var customAdamId: String = ""
    @State private var savedIPAs: [SavedIPA] = []
    @State private var bypassPermissionsGate: Bool = false

    // Persisted settings (Zero-reprompt and full state restoration)
    @AppStorage("appColorScheme")          private var storedScheme: String = "system"
    @AppStorage("libraryPath")             private var customLibraryPath: String = ""
    @AppStorage("selectedSidebarTab")      private var storedSidebarTab: String = SidebarItem.device.rawValue
    @AppStorage("preferDirectMode")        private var preferDirectMode: Bool = true
    @AppStorage("autoClickConfigurator")   private var autoClickConfigurator: Bool = true
    @AppStorage("autoCheckUpdates")        private var autoCheckUpdates: Bool = true

    var selectedSidebar: SidebarItem {
        SidebarItem(rawValue: storedSidebarTab) ?? .device
    }

    // Batch download state
    @State private var selectedAdamIds: Set<Int64> = []
    @State private var isBatchDownloading: Bool = false
    @State private var batchTotal: Int = 0
    @State private var batchDone: Int = 0

    @State private var appToDeleteIPA: (name: String, path: String)? = nil
    @State private var showDeleteIPAConfirm: Bool = false
    @State private var showDeviceInfoSheet: Bool = false
    @State private var showDeviceManagerSheet: Bool = false
    @State private var selectedDeviceForDetail: DeviceInfo? = nil
    @State private var editingOwnerName: String = ""
    @State private var isEditingOwner: Bool = false
    @State private var showForgetConfirmDialog: Bool = false
    @State private var deviceToForget: DeviceInfo? = nil
    @State private var showAppleIdSheet: Bool = false

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
        return savedIPAs.first(where: { item in
            if aidStr != "0" && !aidStr.isEmpty && (item.adamId == aidStr || item.filename.contains(aidStr)) { return true }
            if !name.isEmpty && item.displayName.lowercased().contains(name.lowercased()) { return true }
            if !bundleId.isEmpty && item.filename.lowercased().contains(bundleId.lowercased()) { return true }
            return false
        })
    }

    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Subtle Liquid Glass Background for window
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // 1. Sidebar Navigation
                sidebarNavigationView
                    .frame(width: 250)

                // Separator
                Rectangle()
                    .fill(Color(NSColor.separatorColor).opacity(0.35))
                    .frame(width: 1)
                    .ignoresSafeArea()

                // 2. Main Content Area
                ZStack {
                    detailContentView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.65))
            }
        }
        .frame(minWidth: 940, minHeight: 620)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            engine.checkAllPermissions()
            engine.refreshAppleIdStatus()
            loadCatalog()
            loadSavedIPAs()
            engine.refreshDevices()
            engine.refreshPurchasedApps()
            engine.scanInstalledAppsFromDevice(catalog: catalogApps)
        }
        .sheet(isPresented: $isRestoring)              { restoreProgressSheet }
        .sheet(isPresented: $showManualAdamIdDialog)    { manualAdamIdSheet }
        .sheet(isPresented: $showDeviceManagerSheet)    { deviceManagerSheet }
        .sheet(isPresented: $showDeviceInfoSheet)       { deviceManagerSheet }
        .sheet(isPresented: $showAppleIdSheet)          { appleIdSheet }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("OpenRestore"), message: Text(alertMessage ?? ""),
                  dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showForgetConfirmDialog) {
            Alert(
                title: Text("Удалить связь с устройством?"),
                message: Text("Вы действительно хотите удалить сопряжение с «\(deviceToForget?.name ?? "устройством")»?\n\nСвязь и кэш будут удалены из OpenRestore, а сопряжение с Mac будет сброшено."),
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
            // App Title & Badge
            HStack(spacing: 10) {
                AppLogoView(size: 30, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenRestore")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("iOS App Manager")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Account & Device Glass Cards
            VStack(spacing: 8) {
                // Apple ID Button Card
                Button(action: {
                    showAppleIdSheet = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(engine.isAppleIdAuthenticated ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: engine.isAppleIdAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                                .font(.system(size: 16))
                                .foregroundColor(engine.isAppleIdAuthenticated ? .blue : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(engine.activeAppleIdEmail.isEmpty ? "Apple ID — Войти" : engine.activeAppleIdEmail)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(engine.currentAccountDsid.isEmpty ? "Нажмите для настроек" : "\(engine.purchasedApps.count) покупок • FairPlay")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(engine.isAppleIdAuthenticated ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Device Button Card (iMazing-style Interactive Header)
                let activeDev = engine.activeDevice
                Button(action: {
                    selectedDeviceForDetail = activeDev
                    showDeviceManagerSheet = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(activeDev != nil ? (activeDev?.connectionType == .usb ? Color.green.opacity(0.15) : (activeDev?.connectionType == .wifi ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))) : Color.secondary.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: activeDev?.connectionType.icon ?? "cable.connector")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(activeDev != nil ? (activeDev?.connectionType == .usb ? .green : (activeDev?.connectionType == .wifi ? .blue : .secondary)) : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            if let dev = activeDev {
                                Text(dev.marketingName.isEmpty ? dev.name : dev.marketingName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(dev.ownerName) • \(dev.iosVersion)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("iPhone не подключен")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Подключите кабель или Wi-Fi")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if let dev = activeDev {
                            Text(dev.isOnline ? dev.connectionType.rawValue : "Офлайн")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(dev.isOnline ? (dev.connectionType == .usb ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)) : Color.secondary.opacity(0.15))
                                .foregroundColor(dev.isOnline ? (dev.connectionType == .usb ? .green : .blue) : .secondary)
                                .clipShape(Capsule())
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Нажмите для открытия Менеджера устройств")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            // Section divider
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            // Scrollable Navigation List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Sources Section
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ИСТОЧНИКИ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 2)

                        sidebarNavButton(item: .device)
                        sidebarNavButton(item: .purchases)
                    }

                    // Tools Section
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ИНСТРУМЕНТЫ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 2)

                        sidebarNavButton(item: .customId)
                        sidebarNavButton(item: .library)
                    }

                    // System Section
                    VStack(alignment: .leading, spacing: 3) {
                        Text("СИСТЕМА")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 2)

                        sidebarNavButton(item: .settings)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Mode switch footer
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 14)

            HStack(spacing: 8) {
                Image(systemName: preferDirectMode ? "bolt.fill" : "app.badge")
                    .font(.system(size: 11))
                    .foregroundColor(preferDirectMode ? .blue : .orange)
                    .frame(width: 16)

                Text(preferDirectMode ? "Прямой режим (USB)" : "Apple Configurator")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Toggle("", isOn: $preferDirectMode)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // Interactive Sidebar Button
    private func sidebarNavButton(item: SidebarItem) -> some View {
        let isSelected = selectedSidebar == item
        let count = sidebarCount(item)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                storedSidebarTab = item.rawValue
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 18)

                Text(item.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue)
                            .shadow(color: Color.blue.opacity(0.25), radius: 3, x: 0, y: 1)
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
            if !engine.isAccessibilityGranted {
                accessibilityBanner
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

    private var accessibilityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text("Требуется разрешение «Универсальный доступ»")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                Text("Для автоматических кликов в Apple Configurator разрешите OpenRestore в Системных настройках.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Разрешить доступ") {
                engine.requestAccessibilityPrompt()
                engine.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .roundedCapsuleButton()
            .tint(.orange)
            .controlSize(.small)

            Button(action: {
                engine.checkAllPermissions()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Проверить снова")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Glass Toolbar Helper
    private func glassToolbar<T: View>(@ViewBuilder _ content: () -> T) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1),
                alignment: .bottom
            )
    }

    // MARK: - 0. Old Device Apps View
    private var oldDeviceAppsView: some View {
        VStack(spacing: 0) {
            glassToolbar {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Поиск среди \(engine.oldDeviceApps.count) приложений на iPhone...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Button(action: {
                        engine.scanInstalledAppsFromDevice(catalog: catalogApps)
                    }) {
                        HStack(spacing: 4) {
                            if engine.isScanningApps {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Обновить")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                    .disabled(engine.isScanningApps)
                }
            }

            // Batch selection bar
            let appsWithId = engine.oldDeviceApps.filter { $0.adamId != nil && $0.adamId! > 0 }
            if !appsWithId.isEmpty {
                HStack(spacing: 10) {
                    Button(selectedAdamIds.count == appsWithId.count ? "Снять выбор" : "Выбрать все (\(appsWithId.count))") {
                        if selectedAdamIds.count == appsWithId.count {
                            selectedAdamIds.removeAll()
                        } else {
                            selectedAdamIds = Set(appsWithId.compactMap { $0.adamId })
                        }
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)

                    if !selectedAdamIds.isEmpty {
                        Text("Выбрано: \(selectedAdamIds.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)

                        Button(action: { startBatchDownload(installToDevice: false) }) {
                            Label("Скачать (\(selectedAdamIds.count))", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .roundedCapsuleButton()
                        .controlSize(.small)
                        .disabled(isBatchDownloading)

                        Button(action: { startBatchDownload(installToDevice: true) }) {
                            Label("Установить (\(selectedAdamIds.count))", systemImage: "arrow.down.to.line.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.blue)
                        .controlSize(.small)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.06))
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
            }

            if engine.oldDeviceApps.isEmpty {
                emptyStateView(
                    icon: "iphone.gen3.slash",
                    title: "Приложения не найдены",
                    subtitle: "Подключите iPhone по кабелю и нажмите «Обновить», чтобы считать установленные программы."
                )
            } else {
                List(filteredOldDeviceApps) { app in
                    deviceAppRow(app: app)
                        .listRowSeparator(.visible)
                }
                .listStyle(.plain)
            }
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
                        .font(.system(size: 15))
                        .foregroundColor(isSelected ? .blue : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 15))
                    .foregroundColor(Color.secondary.opacity(0.3))
            }

            // App Icon
            appIconView(url: app.artworkUrl, name: app.name)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.displayName.isEmpty ? app.name : app.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !app.bundleVersion.isEmpty {
                        Text(app.bundleVersion)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.05))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(app.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let aid = app.adamId, aid > 0 {
                        Text("•").foregroundColor(.secondary)
                        Text("ID: \(String(aid))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }

                    if savedIPA != nil {
                        Text("•").foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                            Text("В библиотеке")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 6) {
                if let aid = app.adamId, aid > 0 {
                    if let saved = savedIPA {
                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: false)
                        }) {
                            Label("Скачать", systemImage: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 76, height: 26)
                        }
                        .buttonStyle(.bordered)
                        .roundedCapsuleButton()
                        .controlSize(.small)
                        .help("Скачать IPA заново")

                        Button(action: {
                            startInstallFlow(ipaPath: saved.path, name: app.displayName)
                        }) {
                            Label("Установить", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 136, height: 26)
                        }
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.green)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: false)
                        }) {
                            Label("Скачать", systemImage: "arrow.down.circle")
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 76, height: 26)
                        }
                        .buttonStyle(.bordered)
                        .roundedCapsuleButton()
                        .controlSize(.small)
                        .help("Скачать IPA в Библиотеку")

                        Button(action: {
                            startRestoreFlow(adamId: aid, name: app.name, installToDevice: true)
                        }) {
                            Label("Скачать и установить", systemImage: "arrow.down.to.line.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 136, height: 26)
                        }
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.blue)
                        .controlSize(.small)
                        .help("Скачать и установить на iPhone")
                    }
                } else {
                    Button("Указать ID") {
                        manualBundleId = app.bundleId
                        manualAppName = app.name
                        manualEnteredId = ""
                        showManualAdamIdDialog = true
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                    .foregroundColor(.orange)
                    .frame(width: 218, height: 26)
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
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.75))
                        .frame(width: 20, height: 26)
                }
                .buttonStyle(.plain)
                .help("Удалить IPA из библиотеки (без удаления с iPhone)")
            }
            .frame(width: 250, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 2. Purchased Apps View
    private var purchasedAppsView: some View {
        VStack(spacing: 0) {
            glassToolbar {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Поиск среди \(engine.purchasedApps.count) покупок в Apple ID...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Button(action: {
                        engine.refreshPurchasedApps()
                        engine.refreshAppleIdStatus()
                    }) {
                        Label("Синхронизировать", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                }
            }

            if engine.purchasedApps.isEmpty {
                emptyStateView(
                    icon: "bag",
                    title: "Покупки не найдены",
                    subtitle: "Нажмите на Apple ID в боковой панели, чтобы войти в аккаунт через Apple Configurator."
                )
            } else {
                List(filteredPurchasedApps) { item in
                    purchasedAppRow(item: item)
                        .listRowSeparator(.visible)
                }
                .listStyle(.plain)
            }
        }
    }

    private func purchasedAppRow(item: PurchasedApp) -> some View {
        let savedIPA = isSavedInLibrary(adamId: item.adamId, name: item.name, bundleId: item.bundleId)

        return HStack(spacing: 12) {
            appIconView(url: item.artworkUrl, name: item.name)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("•").foregroundColor(.secondary)

                    Text("ID: \(String(item.adamId))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)

                    if let d = item.purchaseDate {
                        Text("•").foregroundColor(.secondary)
                        Text(dateFormatted(d))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if let saved = savedIPA {
                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: false)
                    }) {
                        Label("Скачать", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 76, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                    .help("Скачать IPA заново")

                    Button(action: {
                        startInstallFlow(ipaPath: saved.path, name: item.name)
                    }) {
                        Label("Установить", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 136, height: 26)
                    }
                    .buttonStyle(.borderedProminent)
                    .roundedCapsuleButton()
                    .tint(.green)
                    .controlSize(.small)
                } else {
                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: false)
                    }) {
                        Label("Скачать", systemImage: "arrow.down.circle")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 76, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                    .help("Скачать IPA в Библиотеку")

                    Button(action: {
                        startRestoreFlow(adamId: item.adamId, name: item.name, extVersion: item.versionId, installToDevice: true)
                    }) {
                        Label("Скачать и установить", systemImage: "arrow.down.to.line.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 136, height: 26)
                    }
                    .buttonStyle(.borderedProminent)
                    .roundedCapsuleButton()
                    .tint(.blue)
                    .controlSize(.small)
                    .help("Скачать и установить на iPhone")
                }
            }
            .frame(width: 224, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 3. Custom ID View
    private var customIdView: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                AppLogoView(size: 56, cornerRadius: 16)

                VStack(spacing: 4) {
                    Text("Восстановление по Adam ID")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("Введите числовой идентификатор любого приложения из App Store для прямой загрузки официального IPA.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13, weight: .semibold))

                        TextField("Например: 570510529", text: $customAdamId)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .onSubmit {
                                if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                    startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: false)
                                }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .frame(width: 320)

                    HStack(spacing: 10) {
                        Button(action: {
                            if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: false)
                            }
                        }) {
                            Label("Скачать IPA", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .roundedCapsuleButton()
                        .controlSize(.regular)
                        .disabled(Int64(customAdamId.trimmingCharacters(in: .whitespaces)) == nil)

                        Button(action: {
                            if let id = Int64(customAdamId.trimmingCharacters(in: .whitespaces)) {
                                startRestoreFlow(adamId: id, name: "App \(id)", installToDevice: true)
                            }
                        }) {
                            Label("Скачать и установить", systemImage: "arrow.down.to.line.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.blue)
                        .controlSize(.regular)
                        .disabled(Int64(customAdamId.trimmingCharacters(in: .whitespaces)) == nil)
                    }
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - 4. Saved IPA Library View
    private var savedIPAsView: some View {
        VStack(spacing: 0) {
            glassToolbar {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Поиск среди \(savedIPAs.count) сохраненных IPA на Mac...", text: $savedIPASearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !savedIPASearchQuery.isEmpty {
                            Button(action: { savedIPASearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Button(action: { importIpaFile() }) {
                        Label("Импорт IPA", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)

                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: effectiveLibraryPath))
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
                    .help("Открыть в Finder")
                }
            }

            if !savedIPAs.isEmpty {
                HStack(spacing: 10) {
                    Button(selectedSavedIPAPaths.count == savedIPAs.count ? "Снять выбор" : "Выбрать все (\(savedIPAs.count))") {
                        if selectedSavedIPAPaths.count == savedIPAs.count {
                            selectedSavedIPAPaths.removeAll()
                        } else {
                            selectedSavedIPAPaths = Set(savedIPAs.map { $0.path })
                        }
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)

                    if !selectedSavedIPAPaths.isEmpty {
                        Text("Выбрано: \(selectedSavedIPAPaths.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)

                        Button(action: { startBatchInstallSavedIPAs() }) {
                            Label("Установить (\(selectedSavedIPAPaths.count))", systemImage: "arrow.down.to.line.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.green)
                        .controlSize(.small)
                        .disabled(isBatchInstallingIPAs)

                        Button(action: {
                            for p in selectedSavedIPAPaths { try? FileManager.default.removeItem(atPath: p) }
                            selectedSavedIPAPaths.removeAll()
                            loadSavedIPAs()
                        }) {
                            Label("Удалить (\(selectedSavedIPAPaths.count))", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        .roundedCapsuleButton()
                        .controlSize(.small)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.green.opacity(0.06))
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
            }

            if savedIPAs.isEmpty {
                emptyStateView(
                    icon: "archivebox",
                    title: "Библиотека IPA пуста",
                    subtitle: "Скачивайте приложения из покупок Apple ID или нажмите «Импорт IPA», чтобы добавить свои файлы."
                )
            } else {
                List(filteredSavedIPAs) { item in
                    savedIPARow(item: item)
                        .listRowSeparator(.visible)
                }
                .listStyle(.plain)
            }
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
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .blue : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !item.version.isEmpty {
                        Text(item.version)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.05))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(item.filename)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("•").foregroundColor(.secondary)

                    Text(item.size)
                        .font(.system(size: 10, weight: .semibold))

                    Text("•").foregroundColor(.secondary)

                    Text(item.date)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                startInstallFlow(ipaPath: item.path, name: item.displayName)
            }) {
                Label("Установить", systemImage: "iphone.and.arrow.forward")
            }
            .buttonStyle(.borderedProminent)
            .roundedCapsuleButton()
            .tint(.green)
            .controlSize(.small)

            Button(action: {
                try? FileManager.default.removeItem(atPath: item.path)
                loadSavedIPAs()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.75))
            }
            .buttonStyle(.plain)
            .help("Удалить из библиотеки")
        }
        .padding(.vertical, 4)
    }

    // MARK: - 5. Settings View (Theme & Library Path)
    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Настройки")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Управление оформлением, папками и алгоритмами загрузки")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Section 1: Appearance
                settingsCard(title: "Оформление интерфейса", icon: "paintbrush.fill", iconColor: .purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Тема приложения")
                            .font(.system(size: 12, weight: .semibold))

                        Picker("Тема оформления", selection: $storedScheme) {
                            Text("Системная").tag("system")
                            Text("Светлая").tag("light")
                            Text("Тёмная").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)

                        Text("Выбор цветовой темы применяется мгновенно ко всем окнам и модальным панелям OpenRestore.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Section 2: Library Storage
                settingsCard(title: "Расположение библиотеки IPA", icon: "archivebox.fill", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Папка для сохранения скачанных .ipa файлов")
                            .font(.system(size: 12, weight: .semibold))

                        HStack(spacing: 8) {
                            Text(effectiveLibraryPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
                            .buttonStyle(.bordered)
                            .roundedCapsuleButton()
                            .controlSize(.small)

                            if !customLibraryPath.isEmpty {
                                Button("Сбросить") {
                                    customLibraryPath = ""
                                    loadSavedIPAs()
                                }
                                .buttonStyle(.bordered)
                                .roundedCapsuleButton()
                                .controlSize(.small)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: effectiveLibraryPath))
                            }) {
                                Label("Показать в Finder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                            .roundedCapsuleButton()
                            .controlSize(.small)

                            Text("По умолчанию: ~/Downloads/OpenRestore")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 3: Download Engines
                settingsCard(title: "Алгоритмы восстановления", icon: "bolt.fill", iconColor: .blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $preferDirectMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Прямой USB и App Store режим (iMazing)")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Прямое скачивание и установка за 2 секунды без вызова Apple Configurator.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: $autoClickConfigurator) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Автоматизация Apple Configurator")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Автоматически инициирует загрузку при переключении на резервный метод.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Section 4: Debug & Logs
                settingsCard(title: "Журнал работы и отладка (Логи)", icon: "doc.text.magnifyingglass", iconColor: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Файл системного журнала OpenRestore:")
                            .font(.system(size: 12, weight: .semibold))

                        HStack(spacing: 8) {
                            Text(LogManager.shared.logFilePath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )

                            Button(action: {
                                if LogManager.shared.copyLogToClipboard() {
                                    copiedLogsToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                        copiedLogsToast = false
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedLogsToast ? "checkmark" : "doc.on.doc")
                                    Text(copiedLogsToast ? "Скопировано!" : "Копировать логи")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .roundedCapsuleButton()
                            .tint(copiedLogsToast ? .green : .blue)
                            .controlSize(.small)

                            Button(action: {
                                LogManager.shared.clearLog()
                            }) {
                                Label("Очистить", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .roundedCapsuleButton()
                            .controlSize(.small)

                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: LogManager.shared.logFilePath))
                            }) {
                                Label("Открыть файл", systemImage: "arrow.up.forward.square")
                            }
                            .buttonStyle(.bordered)
                            .roundedCapsuleButton()
                            .controlSize(.small)
                        }

                        // Live Log Terminal Preview in Settings
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Последние события (Live):")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(engine.progressLogs.count) записей")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            ScrollView {
                                VStack(alignment: .leading, spacing: 3) {
                                    if engine.progressLogs.isEmpty {
                                        Text("Лог пуст. Выполните действие (например, загрузку IPA) для появления записей.")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                    } else {
                                        ForEach(Array(engine.progressLogs.suffix(60).enumerated()), id: \.offset) { _, line in
                                            Text(line)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(Color(NSColor.labelColor))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                            }
                            .frame(height: 140)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                }

                // Section 5: Software Updates
                settingsCard(title: "Обновления программы", icon: "arrow.triangle.2.circlepath.circle.fill", iconColor: .teal) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Текущая версия: OpenRestore v1.5.0")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Сборка Universal 2 для macOS (Apple Silicon & Intel)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
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
                                        Text("Проверка...")
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Проверить обновления")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .roundedCapsuleButton()
                            .tint(.teal)
                            .controlSize(.small)
                            .disabled(engine.isCheckingUpdates)
                        }

                        Divider()

                        Toggle(isOn: $autoCheckUpdates) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Автоматически проверять обновления при запуске")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Приложение будет оповещать вас о выходе новых версий с GitHub.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let info = engine.latestUpdateInfo {
                            if info.isNewer {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.yellow)
                                        Text("Доступна новая версия: \(info.version)!")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.green)
                                        Spacer()
                                        if let dUrl = info.downloadUrl, let url = URL(string: dUrl) {
                                            Button("Скачать обновление") {
                                                NSWorkspace.shared.open(url)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .roundedCapsuleButton()
                                            .tint(.green)
                                            .controlSize(.small)
                                        }
                                    }

                                    if !info.releaseNotes.isEmpty {
                                        Text(info.releaseNotes)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(4)
                                    }
                                }
                                .padding(10)
                                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("У вас установлена самая актуальная версия программы (\(info.version)).")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                            }
                        } else if let err = engine.updateCheckError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Ошибка проверки: \(err)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Section 6: About
                settingsCard(title: "О программе OpenRestore", icon: "info.circle.fill", iconColor: .secondary) {
                    HStack(spacing: 14) {
                        AppLogoView(size: 44, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("OpenRestore 2.0 Pro")
                                .font(.system(size: 13, weight: .bold))
                            Text("Нативный клиент восстановления iOS-приложений с официальной FairPlay DRM лицензией Apple ID.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func fallbackIcon(name: String) -> some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold, design: .rounded))
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

    // MARK: - Apple ID Sheet
    private var appleIdSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Учётная запись Apple ID")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button("Закрыть") { showAppleIdSheet = false }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(engine.activeAppleIdEmail.isEmpty ? "Apple ID не авторизован" : engine.activeAppleIdEmail)
                                .font(.system(size: 14, weight: .bold))

                            if !engine.currentAccountDsid.isEmpty {
                                HStack(spacing: 3) {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                    Text("Активен")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }

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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text("Официальная привязка Apple Configurator")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text("Все приложения скачиваются с официальной FairPlay DRM лицензией вашего Apple ID.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: { engine.openConfiguratorAccountDialog() }) {
                        Label("Сменить Apple ID / Войти", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .roundedCapsuleButton()
                    .tint(.blue)

                    Button(action: {
                        engine.refreshPurchasedApps()
                        engine.refreshAppleIdStatus()
                    }) {
                        Label("Синхронизировать", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                }

                // Step-by-step manual guide
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 13))
                        Text("Инструкция по ручной смене Apple ID:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("1.").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)
                            Text("В окне **Apple Configurator** в строке меню выберите **Учётная запись (Account)**.").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text("2.").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)
                            Text("Нажмите **Выйти… (Sign Out)** (если уже выполнен вход), затем **Войти… (Sign In)**.").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text("3.").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)
                            Text("Введите Apple ID и пароль, с которого приобретены нужные приложения.").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text("4.").font(.system(size: 10, weight: .bold)).foregroundColor(.blue)
                            Text("Вернитесь в OpenRestore — аккаунт и список покупок подтянутся автоматически!").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
            }
            .padding(20)
        }
        .frame(width: 500)
    }

    // MARK: - Restore & Install Progress Sheet
    private var restoreProgressSheet: some View {
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
                .buttonStyle(.bordered)
                .roundedCapsuleButton()
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

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
                            .lineLimit(1)
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
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
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
                        .buttonStyle(.borderedProminent)
                        .roundedCapsuleButton()
                        .tint(.green)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 540)
    }

    // MARK: - Device Manager Sheet (iMazing Style)
    private var deviceManagerSheet: some View {
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
                .buttonStyle(.bordered)
                .roundedCapsuleButton()
                .controlSize(.small)

                Button("Закрыть") {
                    showDeviceManagerSheet = false
                    showDeviceInfoSheet = false
                }
                .buttonStyle(.borderedProminent)
                .roundedCapsuleButton()
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

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
                .frame(width: 270)
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
                                        Text(dev.marketingName.isEmpty ? dev.name : dev.marketingName)
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
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Характеристики и параметры")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))

                                VStack(spacing: 8) {
                                    deviceInfoRow(label: "Владелец", value: dev.ownerName)
                                    deviceInfoRow(label: "Имя устройства", value: dev.name)
                                    deviceInfoRow(label: "Модель", value: "\(dev.marketingName) (\(dev.modelIdentifier))")
                                    deviceInfoRow(label: "Версия системы", value: dev.iosVersion)
                                    deviceInfoRow(label: "Тип связи", value: dev.connectionType == .usb ? "USB-кабель (Прямой канал)" : (dev.connectionType == .wifi ? "Wi-Fi сеть (Беспроводная синхронизация)" : "Отключено"))
                                    if !dev.battery.isEmpty { deviceInfoRow(label: "Уровень заряда", value: dev.battery) }
                                    if !dev.diskCapacity.isEmpty { deviceInfoRow(label: "Память накопителя", value: dev.diskCapacity) }
                                    if !dev.serialNumber.isEmpty { deviceInfoRow(label: "Серийный номер", value: dev.serialNumber) }
                                    if !dev.wifiAddress.isEmpty { deviceInfoRow(label: "Wi-Fi MAC-адрес", value: dev.wifiAddress) }
                                    deviceInfoRow(label: "UDID", value: dev.udid)
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
                                        .buttonStyle(.borderedProminent)
                                        .roundedCapsuleButton()
                                        .controlSize(.regular)
                                    }

                                    if dev.isOnline {
                                        Button(action: {
                                            showDeviceManagerSheet = false
                                            showDeviceInfoSheet = false
                                            storedSidebarTab = SidebarItem.device.rawValue
                                            engine.scanInstalledAppsFromDevice(catalog: catalogApps)
                                        }) {
                                            Label("Сканировать приложения", systemImage: "arrow.clockwise")
                                        }
                                        .buttonStyle(.bordered)
                                        .roundedCapsuleButton()
                                        .controlSize(.regular)
                                    }

                                    Spacer()

                                    Button(action: {
                                        deviceToForget = dev
                                        showForgetConfirmDialog = true
                                    }) {
                                        Label("Удалить связь", systemImage: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.bordered)
                                    .roundedCapsuleButton()
                                    .controlSize(.regular)
                                    .help("Удалить сопряжение и историю устройства")
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .padding(16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "cable.connector")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Устройства не найдены")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Подключите iPhone через USB-кабель или по Wi-Fi для управления и установки приложений.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 760, height: 540)
    }

    private func deviceListCard(dev: DeviceInfo, isOnline: Bool) -> some View {
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
                        .frame(width: 30, height: 30)
                    Image(systemName: isOnline ? dev.connectionType.icon : "icloud.slash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isOnline ? (dev.connectionType == .usb ? .green : .blue) : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dev.name)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(dev.ownerName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("•").foregroundColor(.secondary).font(.system(size: 9))
                        Text(dev.iosVersion)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
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

    private func deviceInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }

    // MARK: - Manual Adam ID Sheet
    private var manualAdamIdSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Указать Adam ID")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button("Закрыть") { showManualAdamIdDialog = false }
                    .buttonStyle(.bordered)
                    .roundedCapsuleButton()
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Приложение: **\(manualAppName)**")
                    .font(.system(size: 13))
                Text("Bundle ID: `\(manualBundleId)`")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                TextField("Числовой Adam ID (например: 570510529)", text: $manualEnteredId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
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
                    .buttonStyle(.borderedProminent)
                    .roundedCapsuleButton()
                    .disabled(Int64(manualEnteredId.trimmingCharacters(in: .whitespaces)) == nil)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }

    // MARK: - Business Logic

    private func startBatchDownload(installToDevice: Bool) {
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
                engine.dismissConfiguratorModals()
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                var downloadSuccess = false
                var downloadedPath: String? = nil

                if preferDirectMode {
                    let (ok, _, ipa) = await engine.downloadDirectAppStore(adamId: adamId, name: name)
                    if ok, let p = ipa {
                        downloadSuccess = true
                        downloadedPath = p
                        engine.appendLog("✅ Скачан: \(name)")
                    }
                }

                if !downloadSuccess {
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
                        engine.appendLog("❌ Ошибка: \(error.localizedDescription)")
                        engine.removeRestoreRequest(adamId: adamId)
                        engine.dismissConfiguratorModals()
                    }
                }

                if downloadSuccess, installToDevice, let ipa = downloadedPath, engine.connectedDevices.first != nil {
                    let (ok, msg) = await engine.installApp(ipaPath: ipa)
                    engine.appendLog(ok ? "📲 Установлен: \(name)" : "⚠️ \(msg)")
                }

                batchDone += 1
                loadSavedIPAs()
                engine.dismissConfiguratorModals()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            alertMessage = "Файл IPA не найден на диске:\n\(ipaPath)"
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

        Task {
            let (ok, msg) = await engine.installApp(ipaPath: ipaPath)
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
            if preferDirectMode {
                engine.appendLog("⚡ Прямой режим (Adam ID: \(adamId))...")
                let (ok, msg, ipa) = await engine.downloadDirectAppStore(adamId: adamId, name: name)
                if ok, let path = ipa {
                    engine.appendLog("🎉 Скачан: \(path)")
                    restoreSuccessIPA = path
                    if shouldInstallAfterDownload, let dev = engine.connectedDevices.first {
                        let (ok2, msg2) = await engine.installApp(ipaPath: path)
                        engine.appendLog(ok2 ? "✅ Установлено на \(dev.name)!" : "⚠️ \(msg2)")
                    }
                    loadSavedIPAs()
                    return
                } else {
                    engine.appendLog("ℹ️ \(msg)")
                    engine.appendLog("🔄 Переключаюсь на Configurator...")
                }
            }

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
                if shouldInstallAfterDownload, let dev = engine.connectedDevices.first {
                    let (ok, msg) = await engine.installApp(ipaPath: result.path)
                    engine.appendLog(ok ? "✅ Установлено на \(dev.name)!" : "⚠️ \(msg)")
                }
                engine.removeRestoreRequest(adamId: adamId)
                loadSavedIPAs()
            } catch {
                engine.appendLog("Ошибка: \(error.localizedDescription)")
                engine.removeRestoreRequest(adamId: adamId)
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

        for f in files.filter({ $0.hasSuffix(".ipa") }).sorted(by: <) {
            let full = "\(path)/\(f)"
            if let attrs = try? FileManager.default.attributesOfItem(atPath: full) {
                let sizeBytes = (attrs[.size] as? Int64) ?? 0
                let sizeMB = String(format: "%.1f MB", Double(sizeBytes) / (1024.0 * 1024.0))
                let modDate = (attrs[.modificationDate] as? Date) ?? Date()
                let baseName = (f as NSString).deletingPathExtension
                var dispName = baseName
                var verStr = ""
                var adamId = ""

                if let vRange = baseName.range(of: " v", options: .backwards) {
                    dispName = String(baseName[..<vRange.lowerBound])
                    verStr = String(baseName[vRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                } else if let dash = baseName.components(separatedBy: "-").first, Int64(dash) != nil {
                    adamId = dash
                    if let m = catalogApps.first(where: { String($0.adam_id) == adamId }) { dispName = m.name }
                }

                list.append(SavedIPA(
                    filename: f,
                    displayName: dispName,
                    version: verStr,
                    path: full,
                    size: sizeMB,
                    date: df.string(from: modDate),
                    adamId: adamId
                ))
            }
        }
        savedIPAs = list
    }

    private func startBatchInstallSavedIPAs() {
        guard !selectedSavedIPAPaths.isEmpty, !isBatchInstallingIPAs else { return }
        let toInstall = Array(selectedSavedIPAPaths)
        isBatchInstallingIPAs = true
        batchInstallTotal = toInstall.count
        batchInstallCurrent = 0

        Task {
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
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = []
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
}
