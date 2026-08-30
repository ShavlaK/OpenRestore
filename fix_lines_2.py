import re

with open('native_app/ContentView.swift', 'r') as f:
    content = f.read()

# Change item.name lineLimit
content = re.sub(r'Text\(item\.name\)\n([ \t]*\.font[^\n]*)\n([ \t]*\.foregroundColor[^\n]*)\n[ \t]*\.lineLimit\(1\)', r'Text(item.name)\n\1\n\2\n                .lineLimit(3)', content)

with open('native_app/ContentView.swift', 'w') as f:
    f.write(content)
