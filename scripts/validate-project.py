"""Structural checks only. These checks do not replace compilation or iPhone testing."""
import json
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
project = (root/'Patrimoine.xcodeproj/project.pbxproj').read_text()
for folder in ['Patrimoine','PatrimoineTests','PatrimoineUITests']:
    for source in (root/folder).rglob('*.swift'):
        assert source.relative_to(root).as_posix() in project, f'Missing build reference: {source}'
definitions = re.findall(r'^([0-9A-F]{24}) =', project, re.M)
assert len(definitions) == len(set(definitions)), 'Duplicate Xcode object ID'
assert set(re.findall(r'\b[0-9A-F]{24}\b',project)) == set(definitions), 'Dangling Xcode object reference'
for pattern in ['*.plist','*.entitlements','*.xcprivacy']:
    for file in (root/'Patrimoine/Resources').rglob(pattern):
        with file.open('rb') as f:
            plistlib.load(f)
for file in (root/'Patrimoine/Resources').rglob('*.json'):
    json.loads(file.read_text())
ET.parse(root/'Patrimoine.xcodeproj/xcshareddata/xcschemes/Patrimoine.xcscheme')
assert 'TARGETED_DEVICE_FAMILY = 1' in project
assert 'SUPPORTS_MACCATALYST = NO' in project
assert 'relativePath = "."' in project
assert (root/'Package.swift').exists()
assert (root/'.github/workflows/build-ios.yml').exists()
print(f'Structure validated: {len(definitions)} Xcode objects. Swift compilation not performed by this check.')
