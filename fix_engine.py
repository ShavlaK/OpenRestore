import re

with open('native_app/ConfiguratorEngine.swift', 'r') as f:
    content = f.read()

# Modify executeConfiguratorAutomation to exit early if !isAccessibilityGranted
early_exit_code = """    public func executeConfiguratorAutomation(adamId: Int64, appName: String = "") {
        if !isAccessibilityGranted {
            LogManager.shared.log("⚠️ Внимание: Для автоматических кликов требуется выдать доступ в «Системные настройки → Конфиденциальность → Универсальный доступ» для OpenRestore.", level: "AUTO")
            return // Skip AppleScript execution to avoid errors
        }"""

content = re.sub(r'    public func executeConfiguratorAutomation\(adamId: Int64, appName: String = ""\) \{\n[ \t]*if !isAccessibilityGranted \{\n[ \t]*LogManager\.shared\.log\("⚠️ Внимание: Для автоматических кликов в Apple Configurator требуется выдать доступ в «Системные настройки → Конфиденциальность → Универсальный доступ» для OpenRestore\.", level: "AUTO"\)\n[ \t]*\}', early_exit_code, content)

with open('native_app/ConfiguratorEngine.swift', 'w') as f:
    f.write(content)
