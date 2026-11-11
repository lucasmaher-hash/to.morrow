#!/usr/bin/env python3
"""Deterministic native app target around the same sources used by SwiftPM."""
from pathlib import Path
from hashlib import sha1
root = Path(__file__).resolve().parents[1]
def key(s): return sha1(s.encode()).hexdigest()[:24].upper()
objects = []
def obj(k, value):
    objects.append(f'{key(k)} = {{ {value} }};')
    return key(k)
sources, resources, refs = [], [], []
for p in sorted((root/'Sources/TomorrowMac').rglob('*.swift')) + sorted(p for p in (root/'Assets').iterdir() if p.is_file()):
    rel=p.relative_to(root).as_posix()
    ref=obj(rel, f'isa = PBXFileReference; path = "{rel}"; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    build=obj('build'+rel, f'isa = PBXBuildFile; fileRef = {ref};')
    (sources if p.suffix == '.swift' else resources).append(build)
def ids(values): return '(' + ','.join(values) + ',)'
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {ids(sources)}; runOnlyForDeploymentPostprocessing = 0;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {ids(resources)}; runOnlyForDeploymentPostprocessing = 0;')
obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = ../Shove95Kit;')
obj('dependency', f'isa = XCSwiftPackageProductDependency; package = {key("package")}; productName = Shove95Kit;')
obj('library', f'isa = PBXBuildFile; productRef = {key("dependency")};')
obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({key("library")},); runOnlyForDeploymentPostprocessing = 0;')
obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = TomorrowMac.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products', f'isa = PBXGroup; children = ({key("app")},); name = Products; sourceTree = "<group>";')
obj('group', f'isa = PBXGroup; children = {ids(refs+[key("products")])}; sourceTree = "<group>";')
for config,env,aps in [('Debug','Development','development'),('Release','Production','production')]:
    obj('project'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ SDKROOT = macosx; MACOSX_DEPLOYMENT_TARGET = 26.0; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES; }};')
    obj('target'+config, f'''isa = XCBuildConfiguration; name = {config}; buildSettings = {{
        PRODUCT_NAME = TomorrowMac; PRODUCT_BUNDLE_IDENTIFIER = com.lucasmaher.tomorrow.macdraft;
        INFOPLIST_FILE = Config/Info.plist; CODE_SIGN_ENTITLEMENTS = Config/TomorrowMac.entitlements;
        DEVELOPMENT_TEAM = 35875F7J33; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "Apple Development";
        ICLOUD_ENVIRONMENT = {env}; APS_ENVIRONMENT = {aps};
        SWIFT_OPTIMIZATION_LEVEL = "{'-Onone' if config=='Debug' else '-O'}";
        SWIFT_ACTIVE_COMPILATION_CONDITIONS = "{'DEBUG' if config=='Debug' else ''}";
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
        ENABLE_HARDENED_RUNTIME = YES; COMBINE_HIDPI_IMAGES = NO;
    }};''')
for prefix in ['project','target']:
    obj(prefix+'configs', f'isa = XCConfigurationList; buildConfigurations = ({key(prefix+"Debug")},{key(prefix+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
obj('target', f'''isa = PBXNativeTarget; name = TomorrowMac; productName = TomorrowMac; productReference = {key('app')}; productType = "com.apple.product-type.application";
buildConfigurationList = {key('targetconfigs')}; buildPhases = ({key('sources')},{key('frameworks')},{key('resources')},); buildRules = (); dependencies = (); packageProductDependencies = ({key('dependency')},);''')
obj('project', f'''isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; TargetAttributes = {{ {key('target')} = {{ CreatedOnToolsVersion = 27.1; DevelopmentTeam = 35875F7J33; ProvisioningStyle = Automatic; SystemCapabilities = {{ com.apple.iCloud = {{enabled = 1;}}; com.apple.Push = {{enabled = 1;}}; }}; }}; }}; }};
buildConfigurationList = {key('projectconfigs')}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = {key('group')}; productRefGroup = {key('products')}; projectDirPath = ""; projectRoot = ""; targets = ({key('target')},); packageReferences = ({key('package')},);''')
project=root/'TomorrowMac.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+key('project')+'; }\n')
scheme=project/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
(scheme/'TomorrowMac.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key('target')}" BuildableName="TomorrowMac.app" BlueprintName="TomorrowMac" ReferencedContainer="container:TomorrowMac.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key('target')}" BuildableName="TomorrowMac.app" BlueprintName="TomorrowMac" ReferencedContainer="container:TomorrowMac.xcodeproj"/></BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(project)
