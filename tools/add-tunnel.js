// Adds the PacketTunnel (Network Extension) target to the Xcode project.
// Run from the repo root: node tools/add-tunnel.js
const fs = require('fs');
const path = require('path');

const P = 'ThreeOneOSFive.xcodeproj/project.pbxproj';
let s = fs.readFileSync(P, 'utf8');
if (s.includes('3105V600')) {
  console.log('already applied');
  process.exit(0);
}

const sources = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith('.swift')) sources.push(full.split(path.sep).join('/').replace(/^PacketTunnel\//, ''));
  }
})('PacketTunnel');
sources.sort();
console.log('tunnel sources:', sources.length);

const pad = (n) => String(n).padStart(2, '0');
const refLine = (id, file) => `\t\t${id} /* ${path.basename(file)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${file}"; sourceTree = "<group>"; };`;
const buildLine = (id, file, refId) => `\t\t${id} /* ${path.basename(file)} in Sources */ = {isa = PBXBuildFile; fileRef = ${refId}; };`;

const refs = [];
const builds = [];
const children = [];
sources.forEach((file, index) => {
  const id = `3105V1${pad(index + 1)}`;
  refs.push(refLine(id, file));
  builds.push(buildLine(`3105V2${pad(index + 1)}`, file, id));
  children.push(`\t\t\t\t${id} /* ${path.basename(file)} */,`);
});

function before(anchor, text) {
  if (!s.includes(anchor)) throw new Error(`missing anchor: ${anchor.slice(0, 60)}`);
  s = s.replace(anchor, text + anchor);
}

before('/* End PBXFileReference section */', [
  '\t\t3105V010 /* PacketTunnel.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = PacketTunnel.appex; sourceTree = BUILT_PRODUCTS_DIR; };',
  '\t\t3105V011 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };',
  '\t\t3105V012 /* PacketTunnel.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = PacketTunnel.entitlements; sourceTree = "<group>"; };',
  ...refs,
  '',
].join('\n'));

before('/* End PBXBuildFile section */', [
  '\t\t3105V002 /* PacketTunnel.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = 3105V010; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };',
  ...builds,
  '',
].join('\n'));

s = s.replace('\t\t\t\t3105A401 /* ThreeOneOSFive */,', '\t\t\t\t3105A401 /* ThreeOneOSFive */,\n\t\t\t\t3105V300 /* PacketTunnel */,');
s = s.replace('\t\t\t\t3105A010 /* 3105.app */,', '\t\t\t\t3105A010 /* 3105.app */,\n\t\t\t\t3105V010 /* PacketTunnel.appex */,');

before('/* End PBXGroup section */', [
  '\t\t3105V300 /* PacketTunnel */ = {',
  '\t\t\tisa = PBXGroup;',
  '\t\t\tchildren = (',
  '\t\t\t\t3105V011 /* Info.plist */,',
  '\t\t\t\t3105V012 /* PacketTunnel.entitlements */,',
  ...children,
  '\t\t\t);',
  '\t\t\tpath = PacketTunnel;',
  '\t\t\tsourceTree = "<group>";',
  '\t\t};',
  '',
].join('\n'));

s = s.replace(
  '\t\t\t\t3105A800 /* Resources */,\n\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);',
  '\t\t\t\t3105A800 /* Resources */,\n\t\t\t\t3105V403 /* Embed Foundation Extensions */,\n\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\t3105V500 /* PBXTargetDependency */,\n\t\t\t);'
);

before('/* Begin PBXProject section */', [
  '/* Begin PBXCopyFilesBuildPhase section */',
  '\t\t3105V403 /* Embed Foundation Extensions */ = {',
  '\t\t\tisa = PBXCopyFilesBuildPhase;',
  '\t\t\tbuildActionMask = 2147483647;',
  '\t\t\tdstPath = "";',
  '\t\t\tdstSubfolderSpec = 13;',
  '\t\t\tfiles = (',
  '\t\t\t\t3105V002 /* PacketTunnel.appex in Embed Foundation Extensions */,',
  '\t\t\t);',
  '\t\t\tname = "Embed Foundation Extensions";',
  '\t\t\trunOnlyForDeploymentPostprocessing = 0;',
  '\t\t};',
  '/* End PBXCopyFilesBuildPhase section */',
  '',
  '',
].join('\n'));

before('/* End PBXNativeTarget section */', [
  '\t\t3105V600 /* PacketTunnel */ = {',
  '\t\t\tisa = PBXNativeTarget;',
  '\t\t\tbuildConfigurationList = 3105V700;',
  '\t\t\tbuildPhases = (',
  '\t\t\t\t3105V400 /* Sources */,',
  '\t\t\t\t3105V401 /* Frameworks */,',
  '\t\t\t\t3105V402 /* Resources */,',
  '\t\t\t);',
  '\t\t\tbuildRules = (\n\t\t\t);',
  '\t\t\tdependencies = (\n\t\t\t);',
  '\t\t\tname = PacketTunnel;',
  '\t\t\tproductName = PacketTunnel;',
  '\t\t\tproductReference = 3105V010;',
  '\t\t\tproductType = "com.apple.product-type.app-extension";',
  '\t\t};',
  '',
].join('\n'));

s = s.replace('\t\t\ttargets = (\n\t\t\t\t3105A500,\n\t\t\t);', '\t\t\ttargets = (\n\t\t\t\t3105A500,\n\t\t\t\t3105V600,\n\t\t\t);');

before('/* End PBXResourcesBuildPhase section */', [
  '\t\t3105V402 /* Resources */ = {',
  '\t\t\tisa = PBXResourcesBuildPhase;',
  '\t\t\tbuildActionMask = 2147483647;',
  '\t\t\tfiles = (\n\t\t\t);',
  '\t\t\trunOnlyForDeploymentPostprocessing = 0;',
  '\t\t};',
  '',
].join('\n'));

before('/* End PBXSourcesBuildPhase section */', [
  '\t\t3105V400 /* Sources */ = {',
  '\t\t\tisa = PBXSourcesBuildPhase;',
  '\t\t\tbuildActionMask = 2147483647;',
  '\t\t\tfiles = (',
  ...sources.map((_, index) => `\t\t\t\t3105V2${pad(index + 1)},`),
  '\t\t\t);',
  '\t\t\trunOnlyForDeploymentPostprocessing = 0;',
  '\t\t};',
  '',
].join('\n'));

before('/* End PBXFrameworksBuildPhase section */', [
  '\t\t3105V401 /* Frameworks */ = {',
  '\t\t\tisa = PBXFrameworksBuildPhase;',
  '\t\t\tbuildActionMask = 2147483647;',
  '\t\t\tfiles = (\n\t\t\t);',
  '\t\t\trunOnlyForDeploymentPostprocessing = 0;',
  '\t\t};',
  '',
].join('\n'));

before('/* Begin PBXVariantGroup section */', [
  '/* Begin PBXContainerItemProxy section */',
  '\t\t3105V501 /* PBXContainerItemProxy */ = {',
  '\t\t\tisa = PBXContainerItemProxy;',
  '\t\t\tcontainerPortal = 3105A900 /* Project object */;',
  '\t\t\tproxyType = 1;',
  '\t\t\tremoteGlobalIDString = 3105V600;',
  '\t\t\tremoteInfo = PacketTunnel;',
  '\t\t};',
  '/* End PBXContainerItemProxy section */',
  '',
  '/* Begin PBXTargetDependency section */',
  '\t\t3105V500 /* PBXTargetDependency */ = {',
  '\t\t\tisa = PBXTargetDependency;',
  '\t\t\ttarget = 3105V600 /* PacketTunnel */;',
  '\t\t\ttargetProxy = 3105V501 /* PBXContainerItemProxy */;',
  '\t\t};',
  '/* End PBXTargetDependency section */',
  '',
  '',
].join('\n'));

const configuration = (suffix, name) => [
  `\t\t3105V7${suffix} /* ${name} */ = {`,
  '\t\t\tisa = XCBuildConfiguration;',
  '\t\t\tbuildSettings = {',
  '\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;',
  '\t\t\t\tCODE_SIGN_ENTITLEMENTS = "";',
  '\t\t\t\tCODE_SIGN_STYLE = Automatic;',
  '\t\t\t\tCURRENT_PROJECT_VERSION = 35;',
  '\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;',
  '\t\t\t\tGENERATE_INFOPLIST_FILE = NO;',
  '\t\t\t\tINFOPLIST_FILE = PacketTunnel/Info.plist;',
  '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;',
  '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (',
  '\t\t\t\t\t"$(inherited)",',
  '\t\t\t\t\t"@executable_path/Frameworks",',
  '\t\t\t\t\t"@executable_path/../../Frameworks",',
  '\t\t\t\t);',
  '\t\t\t\tMARKETING_VERSION = 4.0.1;',
  '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.apple.mobile.MobileHouseArrest.tunnel";',
  '\t\t\t\tPRODUCT_NAME = PacketTunnel;',
  '\t\t\t\tSKIP_INSTALL = YES;',
  '\t\t\t\tSWIFT_VERSION = 5.0;',
  '\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";',
  '\t\t\t};',
  `\t\t\tname = ${name};`,
  '\t\t};',
  '',
].join('\n');

before('/* End XCBuildConfiguration section */', configuration('01', 'Debug') + configuration('02', 'Release'));

before('/* End XCConfigurationList section */', [
  '\t\t3105V700 /* Build configuration list for PBXNativeTarget "PacketTunnel" */ = {',
  '\t\t\tisa = XCConfigurationList;',
  '\t\t\tbuildConfigurations = (',
  '\t\t\t\t3105V701 /* Debug */,',
  '\t\t\t\t3105V702 /* Release */,',
  '\t\t\t);',
  '\t\t\tdefaultConfigurationIsVisible = 0;',
  '\t\t\tdefaultConfigurationName = Release;',
  '\t\t};',
  '',
].join('\n'));

fs.writeFileSync(P, s);
console.log('patched project.pbxproj ->', s.length, 'bytes');
