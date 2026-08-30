import re

with open('native_app/ConfiguratorEngine.swift', 'r') as f:
    content = f.read()

# Instead of changing everywhere manually, let's look for specific problematic methods
# For example, refreshPurchasedApps
content = re.sub(r'([ \t]*)self\.isLoadingPurchasedApps = true', r'\1DispatchQueue.main.async { self.isLoadingPurchasedApps = true }', content)
content = re.sub(r'([ \t]*)self\.isLoadingPurchasedApps = false', r'\1DispatchQueue.main.async { self.isLoadingPurchasedApps = false }', content)

# update connectedDevices
content = re.sub(r'([ \t]*)self\.connectedDevices = sortedOnline', r'\1DispatchQueue.main.async { self.connectedDevices = sortedOnline }', content)
content = re.sub(r'([ \t]*)self\.knownDevices = updatedKnown', r'\1DispatchQueue.main.async { self.knownDevices = updatedKnown }', content)

# activeAppleIdEmail etc.
content = re.sub(r'([ \t]*)self\.activeAppleIdEmail = (.*)', r'\1DispatchQueue.main.async { self.activeAppleIdEmail = \2 }', content)
content = re.sub(r'([ \t]*)self\.activeAppleIdName = (.*)', r'\1DispatchQueue.main.async { self.activeAppleIdName = \2 }', content)
content = re.sub(r'([ \t]*)self\.isAppleIdAuthenticated = (.*)', r'\1DispatchQueue.main.async { self.isAppleIdAuthenticated = \2 }', content)
content = re.sub(r'([ \t]*)self\.isDirectAppleIdAuthenticated = (.*)', r'\1DispatchQueue.main.async { self.isDirectAppleIdAuthenticated = \2 }', content)
content = re.sub(r'([ \t]*)self\.currentAccountDsid = (.*)', r'\1DispatchQueue.main.async { self.currentAccountDsid = \2 }', content)
content = re.sub(r'([ \t]*)self\.purchasedApps = (.*)', r'\1DispatchQueue.main.async { self.purchasedApps = \2 }', content)
content = re.sub(r'([ \t]*)self\.totalPurchasedAppsCount = (.*)', r'\1DispatchQueue.main.async { self.totalPurchasedAppsCount = \2 }', content)

with open('native_app/ConfiguratorEngine.swift', 'w') as f:
    f.write(content)
