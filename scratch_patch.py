import re

with open('native_app/ConfiguratorEngine.swift', 'r') as f:
    content = f.read()

# Make isAccessibilityGranted published
# (already is)

# Replace executeConfiguratorAutomation to handle error properly and not spam
