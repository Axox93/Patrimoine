// Deterministic Xcode project generation. Node is needed only when changing the file list.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const id = key => crypto.createHash('sha256').update(key).digest('hex').slice(0, 24).toUpperCase();
const q = text => JSON.stringify(text);
const objects = [];
const add = (key, value) => { objects.push(`${id(key)} = { ${value} };`); return id(key); };
const list = values => `(${values.join(', ')},)`;
const files = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(item => {
  const rel = `${dir}/${item.name}`;
  return item.isDirectory() ? files(rel) : rel.endsWith('.swift') ? [rel] : [];
}).sort();
const app = files('Patrimoine');
const tests = files('PatrimoineTests');
const fileRef = file => add(`ref:${file}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${q(file)}; sourceTree = "<group>";`);
const buildRef = file => add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${file}`)};`);
const appRefs = app.map(fileRef), testRefs = tests.map(fileRef);
const appBuilds = app.map(buildRef), testBuilds = tests.map(buildRef);
const resources = ['Patrimoine/Resources/Assets.xcassets', 'Patrimoine/Resources/PrivacyInfo.xcprivacy'];
const resourceRefs = resources.map(file => add(`ref:${file}`, `isa = PBXFileReference; lastKnownFileType = ${file.endsWith('xcassets') ? 'folder.assetcatalog' : 'text.xml'}; path = ${q(file)}; sourceTree = "<group>";`));
const resourceBuilds = resources.map(buildRef);
for (const [key, name, type] of [['appProduct', 'Patrimoine.app', 'wrapper.application'], ['testProduct', 'PatrimoineTests.xctest', 'wrapper.cfbundle']]) {
  add(key, `isa = PBXFileReference; explicitFileType = ${type}; includeInIndex = 0; path = ${q(name)}; sourceTree = BUILT_PRODUCTS_DIR;`);
}
add('appGroup', `isa = PBXGroup; children = ${list([...appRefs, ...resourceRefs])}; name = Patrimoine; sourceTree = "<group>";`);
add('testGroup', `isa = PBXGroup; children = ${list(testRefs)}; name = PatrimoineTests; sourceTree = "<group>";`);
add('productGroup', `isa = PBXGroup; children = ${list([id('appProduct'), id('testProduct')])}; name = Products; sourceTree = "<group>";`);
add('rootGroup', `isa = PBXGroup; children = ${list([id('appGroup'), id('testGroup'), id('productGroup')])}; sourceTree = "<group>";`);
add('localPackage', 'isa = XCLocalSwiftPackageReference; relativePath = ".";');
for (const target of ['app', 'test']) {
  add(`${target}Package`, `isa = XCSwiftPackageProductDependency; package = ${id('localPackage')}; productName = PatrimoineCore;`);
  add(`${target}PackageBuild`, `isa = PBXBuildFile; productRef = ${id(`${target}Package`)};`);
  add(`${target}Frameworks`, `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ${list([id(`${target}PackageBuild`)])}; runOnlyForDeploymentPostprocessing = 0;`);
  add(`${target}Sources`, `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ${list(target === 'app' ? appBuilds : testBuilds)}; runOnlyForDeploymentPostprocessing = 0;`);
}
add('resources', `isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ${list(resourceBuilds)}; runOnlyForDeploymentPostprocessing = 0;`);
add('proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${id('appTarget')}; remoteInfo = Patrimoine;`);
add('testDependency', `isa = PBXTargetDependency; target = ${id('appTarget')}; targetProxy = ${id('proxy')};`);
add('appTarget', `isa = PBXNativeTarget; buildConfigurationList = ${id('appConfigs')}; buildPhases = ${list([id('appSources'), id('appFrameworks'), id('resources')])}; buildRules = (); dependencies = (); name = Patrimoine; packageProductDependencies = ${list([id('appPackage')])}; productName = Patrimoine; productReference = ${id('appProduct')}; productType = "com.apple.product-type.application";`);
add('testTarget', `isa = PBXNativeTarget; buildConfigurationList = ${id('testConfigs')}; buildPhases = ${list([id('testSources'), id('testFrameworks')])}; buildRules = (); dependencies = ${list([id('testDependency')])}; name = PatrimoineTests; packageProductDependencies = ${list([id('testPackage')])}; productName = PatrimoineTests; productReference = ${id('testProduct')}; productType = "com.apple.product-type.bundle.unit-test";`);
for (const scope of ['project', 'app', 'test']) {
  for (const config of ['Debug', 'Release']) {
    const common = `IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;`;
    const projectSettings = `${common} ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_OBJC_ARC = YES; ENABLE_TESTABILITY = ${config === 'Debug' ? 'YES' : 'NO'}; DEBUG_INFORMATION_FORMAT = ${config === 'Debug' ? 'dwarf' : '"dwarf-with-dsym"'}; SWIFT_OPTIMIZATION_LEVEL = ${config === 'Debug' ? '"-Onone"' : '"-O"'}; SWIFT_ACTIVE_COMPILATION_CONDITIONS = ${config === 'Debug' ? 'DEBUG' : '""'};`;
    const targetSettings = `${common} PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO; SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.1.0;`;
    const settings = scope === 'project' ? projectSettings : scope === 'app'
      ? `${targetSettings} PRODUCT_BUNDLE_IDENTIFIER = fr.patrimoine.personal; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Patrimoine/Resources/Info.plist; CODE_SIGN_ENTITLEMENTS = Patrimoine/Resources/Patrimoine.entitlements; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";`
      : `${targetSettings} PRODUCT_BUNDLE_IDENTIFIER = fr.patrimoine.personal.tests; GENERATE_INFOPLIST_FILE = YES; BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Patrimoine.app/Patrimoine"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";`;
    add(`${scope}:${config}`, `isa = XCBuildConfiguration; buildSettings = { ${settings} }; name = ${config};`);
  }
  add(`${scope}Configs`, `isa = XCConfigurationList; buildConfigurations = ${list([id(`${scope}:Debug`), id(`${scope}:Release`)])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
add('project', `isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1640; TargetAttributes = { ${id('appTarget')} = { CreatedOnToolsVersion = 16.4; }; ${id('testTarget')} = { CreatedOnToolsVersion = 16.4; TestTargetID = ${id('appTarget')}; }; }; }; buildConfigurationList = ${id('projectConfigs')}; compatibilityVersion = "Xcode 14.0"; developmentRegion = fr; hasScannedForEncodings = 0; knownRegions = (fr, en, Base); mainGroup = ${id('rootGroup')}; productRefGroup = ${id('productGroup')}; packageReferences = ${list([id('localPackage')])}; projectDirPath = ""; projectRoot = ""; targets = ${list([id('appTarget'), id('testTarget')])};`);
const projectDir = path.join(root, 'Patrimoine.xcodeproj');
fs.mkdirSync(path.join(projectDir, 'xcshareddata/xcschemes'), { recursive: true });
fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), `// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${objects.join('\n')}\n}; rootObject = ${id('project')}; }\n`);
const ref = (target, buildable, name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(target)}" BuildableName="${buildable}" BlueprintName="${name}" ReferencedContainer="container:Patrimoine.xcodeproj"/>`;
fs.writeFileSync(path.join(projectDir, 'xcshareddata/xcschemes/Patrimoine.xcscheme'), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${ref('appTarget','Patrimoine.app','Patrimoine')}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref('testTarget','PatrimoineTests.xctest','PatrimoineTests')}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('appTarget','Patrimoine.app','Patrimoine')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('appTarget','Patrimoine.app','Patrimoine')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`);

// Original geometric app icon, generated without an external graphics dependency.
const size = 1024, pixels = Buffer.alloc((size * 4 + 1) * size);
for (let y = 0; y < size; y++) {
  const row = y * (size * 4 + 1); pixels[row] = 0;
  for (let x = 0; x < size; x++) {
    let color = [17, 39, 32];
    const bars = [[248, 478, 366, 722], [453, 350, 571, 722], [658, 222, 776, 722]];
    const roundRect = (l,t,r,b,rad) => {
      const cx = Math.max(l + rad, Math.min(x, r - rad));
      const cy = Math.max(t + rad, Math.min(y, b - rad));
      return x >= l && x <= r && y >= t && y <= b && (x-cx)**2+(y-cy)**2<=rad**2;
    };
    if (bars.some(rect => roundRect(...rect, 34))) color = [188, 216, 169];
    if (roundRect(248, 775, 776, 804, 14)) color = [109, 145, 118];
    const index = row + 1 + x * 4;
    pixels[index] = color[0]; pixels[index+1] = color[1]; pixels[index+2] = color[2]; pixels[index+3] = 255;
  }
}
function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) { crc ^= byte; for(let i=0;i<8;i++) crc=(crc>>>1)^((crc&1)?0xedb88320:0); }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const typeBytes = Buffer.from(type), length = Buffer.alloc(4), crc = Buffer.alloc(4);
  length.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([typeBytes,data])));
  return Buffer.concat([length,typeBytes,data,crc]);
}
const header = Buffer.alloc(13); header.writeUInt32BE(size,0); header.writeUInt32BE(size,4); header[8]=8;header[9]=6;
const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]);
const iconDir = path.join(root,'Patrimoine/Resources/Assets.xcassets/AppIcon.appiconset');
fs.mkdirSync(iconDir,{recursive:true});fs.writeFileSync(path.join(iconDir,'AppIcon.png'),png);
fs.writeFileSync(path.join(iconDir,'Contents.json'),JSON.stringify({images:[{filename:'AppIcon.png',idiom:'universal',platform:'ios',size:'1024x1024'}],info:{author:'xcode',version:1}},null,2)+'\n');
console.log(`Generated Xcode project: ${app.length} app sources, ${tests.length} integration test files, local Swift package.`);
