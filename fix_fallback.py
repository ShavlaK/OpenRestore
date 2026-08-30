import re

with open('native_app/ContentView.swift', 'r') as f:
    content = f.read()

# 1. Add fallback to Configurator instead of aborting
fallback_code = """                } else {
                    engine.appendLog("⚠️ Прямая загрузка не удалась: \\(msg)")
                    engine.appendLog("🔄 Автоматический переход в резервный режим Apple Configurator...")
                    DispatchQueue.main.async {
                        self.engine.operationStage = "Переход в Apple Configurator..."
                    }
                    // Fallthrough to Configurator mode
                }"""

content = re.sub(r'\} else \{\n[ \t]*engine\.appendLog\("❌ Ошибка загрузки: \\\(msg\)"\)\n[ \t]*DispatchQueue\.main\.async \{\n[ \t]*self\.restoreError = msg\n[ \t]*self\.engine\.operationStage = "Ошибка: \\\(msg\)"\n[ \t]*\}\n[ \t]*return\n[ \t]*\}', fallback_code, content)


# 2. Add accessibility warning in settings
settings_code = """                        if currentEngineMode == .configurator {
                            Divider().padding(.vertical, 4)

                            Toggle(isOn: $autoClickConfigurator) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Автоматизация кликов в Apple Configurator")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Автоматически нажимает кнопку «Добавить» и закрывает диалоги замены.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if autoClickConfigurator && !engine.isAccessibilityGranted {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("⚠️ Требуется разрешение")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                    Text("Для автоматических кликов нужно разрешить управление компьютером.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Button("Разрешить в Системных настройках") {
                                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                        AXIsProcessTrustedWithOptions(options as CFDictionary)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.mini)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }"""

content = re.sub(r'if currentEngineMode == \.configurator \{\n[ \t]*Divider\(\)\.padding\(\.vertical, 4\)\n\n[ \t]*Toggle\(isOn: \$autoClickConfigurator\) \{\n[ \t]*VStack\(alignment: \.leading, spacing: 2\) \{\n[ \t]*Text\("Автоматизация кликов в Apple Configurator"\)\n[ \t]*\.font\(\.system\(size: 12, weight: \.semibold\)\)\n[ \t]*Text\("Автоматически нажимает кнопку «Добавить» и закрывает диалоги замены\."\)\n[ \t]*\.font\(\.system\(size: 11\)\)\n[ \t]*\.foregroundColor\(\.secondary\)\n[ \t]*\}\n[ \t]*\}\n[ \t]*\}', settings_code, content)

# 3. Change lineLimit(1) to lineLimit(3) for App Names to prevent truncation
content = re.sub(r'Text\(app\.displayName\.isEmpty \? app\.name : app\.displayName\)\n([ \t]*\.font[^\n]*)\n([ \t]*\.foregroundColor[^\n]*)\n[ \t]*\.lineLimit\(1\)', r'Text(app.displayName.isEmpty ? app.name : app.displayName)\n\1\n\2\n                                .lineLimit(3)', content)

content = re.sub(r'Text\(item\.displayName\)\n([ \t]*\.font[^\n]*)\n([ \t]*\.foregroundColor[^\n]*)\n[ \t]*\.lineLimit\(1\)', r'Text(item.displayName)\n\1\n\2\n                        .lineLimit(3)', content)

with open('native_app/ContentView.swift', 'w') as f:
    f.write(content)
