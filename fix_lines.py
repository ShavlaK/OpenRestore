import re

with open('native_app/ContentView.swift', 'r') as f:
    content = f.read()

# Change engine.operationStage lineLimit
content = re.sub(r'Text\(engine\.operationStage\.isEmpty \? engine\.currentStatus : engine\.operationStage\)\n([ \t]*\.font[^\n]*)\n[ \t]*\.lineLimit\(1\)', r'Text(engine.operationStage.isEmpty ? engine.currentStatus : engine.operationStage)\n\1\n                        .lineLimit(4)', content)

with open('native_app/ContentView.swift', 'w') as f:
    f.write(content)
