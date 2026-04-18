#!/usr/bin/env python3
"""Generates Trove.xcodeproj/project.pbxproj from scratch."""

import os
import hashlib
import textwrap

ROOT = os.path.dirname(os.path.abspath(__file__))

def uid(name: str) -> str:
    """Deterministic 24-char hex ID from a name string."""
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

# ── Source files ────────────────────────────────────────────────────────────

SOURCES = [
    # App entry
    "Trove/TroveApp.swift",
    # Capture
    "Trove/Capture/ClipboardMonitor.swift",
    "Trove/Capture/ClipExtractor.swift",
    "Trove/Capture/TypeDetector.swift",
    "Trove/Capture/SensitiveContentDetector.swift",
    # Panel
    "Trove/Panel/TrovePanel.swift",
    "Trove/Panel/PanelView.swift",
    "Trove/Panel/ClipRow.swift",
    "Trove/Panel/DetailPreviewView.swift",
    # Settings
    "Trove/Settings/SettingsView.swift",
    # MenuBar
    "Trove/MenuBar/MenuBarController.swift",
    "Trove/MenuBar/FirstRunView.swift",
    "Trove/MenuBar/AboutView.swift",
    # Models
    "Trove/Model/Clip.swift",
    "Trove/Model/Filter.swift",
    "Trove/Model/Workspace.swift",
    # Persistence
    "Trove/Persistence/ClipStore.swift",
    "Trove/Persistence/CollectionStore.swift",
    # Services
    "Trove/Services/BlacklistService.swift",
    "Trove/Services/PasteService.swift",
    "Trove/Services/HotkeyService.swift",
    "Trove/Services/FilterEngine.swift",
    "Trove/Services/SnippetExpander.swift",
    "Trove/Services/AIService.swift",
    "Trove/Services/SyncService.swift",
    "Trove/Services/ShellFilterRunner.swift",
    # Supporting
    "Trove/Supporting/TroveSettings.swift",
    "Trove/Supporting/NSColor+Hex.swift",
    "Trove/Supporting/ImageOCR.swift",
    # Persistence (SQLite wrapper)
    "Trove/Persistence/SQLiteDB.swift",
    # Audit
    "Trove/Supporting/AuditLog.swift",
]

RESOURCES = [
    "Trove/Resources/Assets.xcassets",
    "Trove/Resources/TroveLogo.png",
    "Trove/Resources/MenuBarIcon.png",
    "Trove/Resources/MenuBarIcon@2x.png",
]

TEST_SOURCES = [
    "TroveTests/TypeDetectorTests.swift",
    "TroveTests/SensitiveContentDetectorTests.swift",
    "TroveTests/FilterEngineTests.swift",
    "TroveTests/SQLiteDBTests.swift",
    "TroveTests/ClipExtractorTests.swift",
]

UITEST_SOURCES = [
    "TroveUITests/TroveUITests.swift",
]

# ── UITest placeholder (create if missing) ──────────────────────────────────

uitest_path = os.path.join(ROOT, "TroveUITests/TroveUITests.swift")
os.makedirs(os.path.dirname(uitest_path), exist_ok=True)
if not os.path.exists(uitest_path):
    with open(uitest_path, "w") as f:
        f.write(textwrap.dedent("""\
            import XCTest

            final class TroveUITests: XCTestCase {
                func testLaunch() throws {
                    let app = XCUIApplication()
                    app.launch()
                }
            }
        """))

# ── IDs ─────────────────────────────────────────────────────────────────────

PROJECT_ID        = uid("PROJECT")
MAIN_GROUP_ID     = uid("MAIN_GROUP")
PRODUCTS_GROUP_ID = uid("PRODUCTS_GROUP")
TROVE_APP_ID      = uid("TROVE_APP_PRODUCT")
TROVE_TESTS_ID    = uid("TROVE_TESTS_PRODUCT")
TROVE_UITESTS_ID  = uid("TROVE_UITESTS_PRODUCT")

TARGET_TROVE      = uid("TARGET_TROVE")
TARGET_TESTS      = uid("TARGET_TESTS")
TARGET_UITESTS    = uid("TARGET_UITESTS")

SRC_BUILD_PHASE   = uid("SRC_BUILD_PHASE_TROVE")
RES_BUILD_PHASE   = uid("RES_BUILD_PHASE_TROVE")
FW_BUILD_PHASE    = uid("FW_BUILD_PHASE_TROVE")
TEST_SRC_PHASE    = uid("SRC_BUILD_PHASE_TESTS")
TEST_FW_PHASE     = uid("FW_BUILD_PHASE_TESTS")
UITEST_SRC_PHASE  = uid("SRC_BUILD_PHASE_UITESTS")
UITEST_FW_PHASE   = uid("FW_BUILD_PHASE_UITESTS")

CONFIG_LIST_PROJ  = uid("CONFIG_LIST_PROJ")
CONFIG_LIST_APP   = uid("CONFIG_LIST_APP")
CONFIG_LIST_TEST  = uid("CONFIG_LIST_TEST")
CONFIG_LIST_UTEST = uid("CONFIG_LIST_UTEST")

DEBUG_PROJ        = uid("DEBUG_PROJ")
RELEASE_PROJ      = uid("RELEASE_PROJ")
DEBUG_APP         = uid("DEBUG_APP")
RELEASE_APP       = uid("RELEASE_APP")
DEBUG_TEST        = uid("DEBUG_TEST")
RELEASE_TEST      = uid("RELEASE_TEST")
DEBUG_UTEST       = uid("DEBUG_UTEST")
RELEASE_UTEST     = uid("RELEASE_UTEST")

# Entitlements file ref
ENTITLEMENTS_REF  = uid("ENTITLEMENTS_FILE_REF")

# ── Per-file IDs ─────────────────────────────────────────────────────────────

def file_ref(path): return uid(f"FILEREF_{path}")
def build_file(path): return uid(f"BUILDFILE_{path}")
def group_id(name): return uid(f"GROUP_{name}")

all_files = SOURCES + RESOURCES + TEST_SOURCES + UITEST_SOURCES

# ── Helpers ──────────────────────────────────────────────────────────────────

def pbx_file_reference(path, explicit_type=None):
    name = os.path.basename(path)
    if path.endswith(".swift"):
        ftype = "sourcecode.swift"
    elif path.endswith(".plist"):
        ftype = "text.plist.xml"
    elif path.endswith(".entitlements"):
        ftype = "text.plist.entitlements"
    elif path.endswith(".xcassets"):
        ftype = "folder.assetcatalog"
    elif path.endswith(".png"):
        ftype = "image.png"
    else:
        ftype = "file"
    if explicit_type:
        ftype = explicit_type
    return (f'\t\t{file_ref(path)} = {{isa = PBXFileReference; '
            f'lastKnownFileType = {ftype}; '
            f'path = "{name}"; sourceTree = "<group>"; }};')

def pbx_build_file(path, target="APP"):
    return (f'\t\t{build_file(path + target)} = {{isa = PBXBuildFile; '
            f'fileRef = {file_ref(path)}; }};')

# ── Groups ────────────────────────────────────────────────────────────────────

def collect_groups(paths):
    """Return {dir_path: [child_paths]} from file list."""
    groups = {}
    for p in paths:
        parts = p.split("/")
        for i in range(1, len(parts)):
            parent = "/".join(parts[:i])
            child  = "/".join(parts[:i+1])
            groups.setdefault(parent, set()).add(child)
        groups.setdefault(p, set())  # leaf
    return groups

def build_group_tree(paths):
    groups = {}
    for p in paths:
        parts = p.split("/")
        for depth in range(1, len(parts)):
            grp = "/".join(parts[:depth])
            child = "/".join(parts[:depth+1])
            groups.setdefault(grp, [])
            if child not in groups[grp]:
                groups[grp].append(child)
    return groups

ALL_PATHS = SOURCES + RESOURCES + [
    "Trove/Resources/Trove.entitlements",
] + TEST_SOURCES + UITEST_SOURCES

group_tree = build_group_tree(ALL_PATHS)

# ── Build the pbxproj string ──────────────────────────────────────────────────

lines = []

def L(s=""):
    lines.append(s)

L("// !$*UTF8*$!")
L("{")
L("\tarchiveVersion = 1;")
L("\tclasses = {")
L("\t};")
L("\tobjectVersion = 56;")
L("\tobjects = {")
L()

# PBXBuildFile
L("/* Begin PBXBuildFile section */")
for s in SOURCES:
    L(pbx_build_file(s, "APP"))
for s in TEST_SOURCES:
    L(pbx_build_file(s, "TEST"))
for s in UITEST_SOURCES:
    L(pbx_build_file(s, "UTEST"))
for r in RESOURCES:
    L(pbx_build_file(r, "APP"))
L("/* End PBXBuildFile section */")
L()

# PBXFileReference
L("/* Begin PBXFileReference section */")
for p in ALL_PATHS:
    L(pbx_file_reference(p))
# Products
L(f'\t\t{TROVE_APP_ID} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Trove.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
L(f'\t\t{TROVE_TESTS_ID} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TroveTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
L(f'\t\t{TROVE_UITESTS_ID} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TroveUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
L("/* End PBXFileReference section */")
L()

# PBXGroup
L("/* Begin PBXGroup section */")

# Main group
top_children = [group_id("Trove"), group_id("TroveTests"), group_id("TroveUITests"), PRODUCTS_GROUP_ID]
L(f'\t\t{MAIN_GROUP_ID} = {{')
L(f'\t\t\tisa = PBXGroup;')
L(f'\t\t\tchildren = (')
for c in top_children:
    L(f'\t\t\t\t{c},')
L(f'\t\t\t);')
L(f'\t\t\tsourceTree = "<group>";')
L(f'\t\t}};')

# Products group
L(f'\t\t{PRODUCTS_GROUP_ID} = {{')
L(f'\t\t\tisa = PBXGroup;')
L(f'\t\t\tchildren = (')
L(f'\t\t\t\t{TROVE_APP_ID},')
L(f'\t\t\t\t{TROVE_TESTS_ID},')
L(f'\t\t\t\t{TROVE_UITESTS_ID},')
L(f'\t\t\t);')
L(f'\t\t\tname = Products;')
L(f'\t\t\tsourceTree = "<group>";')
L(f'\t\t}};')

# Sub-groups from tree
def emit_group(grp_path, tree, all_paths_set):
    gid = group_id(grp_path)
    children = tree.get(grp_path, [])
    name = os.path.basename(grp_path)
    L(f'\t\t{gid} = {{')
    L(f'\t\t\tisa = PBXGroup;')
    L(f'\t\t\tchildren = (')
    for child in children:
        if child in all_paths_set:
            L(f'\t\t\t\t{file_ref(child)},')
        else:
            L(f'\t\t\t\t{group_id(child)},')
    L(f'\t\t\t);')
    L(f'\t\t\tpath = "{name}";')
    L(f'\t\t\tsourceTree = "<group>";')
    L(f'\t\t}};')

all_paths_set = set(ALL_PATHS)
emitted = set()

def emit_recursive(grp_path, tree, all_paths_set):
    if grp_path in emitted:
        return
    emitted.add(grp_path)
    emit_group(grp_path, tree, all_paths_set)
    for child in tree.get(grp_path, []):
        if child not in all_paths_set:
            emit_recursive(child, tree, all_paths_set)

for top in ["Trove", "TroveTests", "TroveUITests"]:
    emit_recursive(top, group_tree, all_paths_set)

L("/* End PBXGroup section */")
L()

# PBXNativeTarget
L("/* Begin PBXNativeTarget section */")

DEP_TESTS_ON_APP  = uid("DEP_TESTS_ON_APP")
DEP_UITESTS_ON_APP = uid("DEP_UITESTS_ON_APP")
PROXY_TESTS       = uid("PROXY_TESTS")
PROXY_UITESTS     = uid("PROXY_UITESTS")

def emit_target(tid, name, product_ref, product_type, src_phase, fw_phase, res_phase=None, config_list=None, deps=None):
    L(f'\t\t{tid} = {{')
    L(f'\t\t\tisa = PBXNativeTarget;')
    L(f'\t\t\tbuildConfigurationList = {config_list};')
    L(f'\t\t\tbuildPhases = (')
    L(f'\t\t\t\t{src_phase},')
    if res_phase:
        L(f'\t\t\t\t{res_phase},')
    L(f'\t\t\t\t{fw_phase},')
    L(f'\t\t\t);')
    L(f'\t\t\tbuildRules = (')
    L(f'\t\t\t);')
    L(f'\t\t\tdependencies = (')
    for dep in (deps or []):
        L(f'\t\t\t\t{dep},')
    L(f'\t\t\t);')
    L(f'\t\t\tname = {name};')
    L(f'\t\t\tproductName = {name};')
    L(f'\t\t\tproductReference = {product_ref};')
    L(f'\t\t\tproductType = "{product_type}";')
    L(f'\t\t}};')

# PBXTargetDependency + PBXContainerItemProxy for tests → app
L("/* Begin PBXContainerItemProxy section */")
for proxy_id, target_id in [(PROXY_TESTS, TARGET_TROVE), (PROXY_UITESTS, TARGET_TROVE)]:
    L(f'\t\t{proxy_id} = {{')
    L(f'\t\t\tisa = PBXContainerItemProxy;')
    L(f'\t\t\tcontainerPortal = {PROJECT_ID};')
    L(f'\t\t\tproxyType = 1;')
    L(f'\t\t\tremoteGlobalIDString = {target_id};')
    L(f'\t\t\tremoteInfo = Trove;')
    L(f'\t\t}};')
L("/* End PBXContainerItemProxy section */")
L()
L("/* Begin PBXTargetDependency section */")
L(f'\t\t{DEP_TESTS_ON_APP} = {{')
L(f'\t\t\tisa = PBXTargetDependency;')
L(f'\t\t\ttarget = {TARGET_TROVE};')
L(f'\t\t\ttargetProxy = {PROXY_TESTS};')
L(f'\t\t}};')
L(f'\t\t{DEP_UITESTS_ON_APP} = {{')
L(f'\t\t\tisa = PBXTargetDependency;')
L(f'\t\t\ttarget = {TARGET_TROVE};')
L(f'\t\t\ttargetProxy = {PROXY_UITESTS};')
L(f'\t\t}};')
L("/* End PBXTargetDependency section */")
L()

emit_target(TARGET_TROVE, "Trove", TROVE_APP_ID,
            "com.apple.product-type.application",
            SRC_BUILD_PHASE, FW_BUILD_PHASE, RES_BUILD_PHASE, CONFIG_LIST_APP)
emit_target(TARGET_TESTS, "TroveTests", TROVE_TESTS_ID,
            "com.apple.product-type.bundle.unit-test",
            TEST_SRC_PHASE, TEST_FW_PHASE, config_list=CONFIG_LIST_TEST,
            deps=[DEP_TESTS_ON_APP])
emit_target(TARGET_UITESTS, "TroveUITests", TROVE_UITESTS_ID,
            "com.apple.product-type.bundle.ui-testing",
            UITEST_SRC_PHASE, UITEST_FW_PHASE, config_list=CONFIG_LIST_UTEST,
            deps=[DEP_UITESTS_ON_APP])

L("/* End PBXNativeTarget section */")
L()

# PBXProject
L("/* Begin PBXProject section */")
L(f'\t\t{PROJECT_ID} = {{')
L(f'\t\t\tisa = PBXProject;')
L(f'\t\t\tattributes = {{')
L(f'\t\t\t\tBuildIndependentTargetsInParallel = 1;')
L(f'\t\t\t\tLastSwiftUpdateCheck = 1500;')
L(f'\t\t\t\tLastUpgradeCheck = 1500;')
L(f'\t\t\t}};')
L(f'\t\t\tbuildConfigurationList = {CONFIG_LIST_PROJ};')
L(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
L(f'\t\t\tdevelopmentRegion = en;')
L(f'\t\t\thasScannedForEncodings = 0;')
L(f'\t\t\tknownRegions = (')
L(f'\t\t\t\ten,')
L(f'\t\t\t\tBase,')
L(f'\t\t\t);')
L(f'\t\t\tmainGroup = {MAIN_GROUP_ID};')
L(f'\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID};')
L(f'\t\t\tprojectDirPath = "";')
L(f'\t\t\tprojectRoot = "";')
L(f'\t\t\ttargets = (')
L(f'\t\t\t\t{TARGET_TROVE},')
L(f'\t\t\t\t{TARGET_TESTS},')
L(f'\t\t\t\t{TARGET_UITESTS},')
L(f'\t\t\t);')
L(f'\t\t}};')
L("/* End PBXProject section */")
L()

# Build phases
L("/* Begin PBXSourcesBuildPhase section */")

def emit_sources_phase(phase_id, files, suffix):
    L(f'\t\t{phase_id} = {{')
    L(f'\t\t\tisa = PBXSourcesBuildPhase;')
    L(f'\t\t\tbuildActionMask = 2147483647;')
    L(f'\t\t\tfiles = (')
    for f in files:
        L(f'\t\t\t\t{build_file(f + suffix)},')
    L(f'\t\t\t);')
    L(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    L(f'\t\t}};')

emit_sources_phase(SRC_BUILD_PHASE, SOURCES, "APP")
emit_sources_phase(TEST_SRC_PHASE, TEST_SOURCES, "TEST")
emit_sources_phase(UITEST_SRC_PHASE, UITEST_SOURCES, "UTEST")
L("/* End PBXSourcesBuildPhase section */")
L()

L("/* Begin PBXResourcesBuildPhase section */")
L(f'\t\t{RES_BUILD_PHASE} = {{')
L(f'\t\t\tisa = PBXResourcesBuildPhase;')
L(f'\t\t\tbuildActionMask = 2147483647;')
L(f'\t\t\tfiles = (')
for r in RESOURCES:
    L(f'\t\t\t\t{build_file(r + "APP")},')
L(f'\t\t\t);')
L(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
L(f'\t\t}};')
L("/* End PBXResourcesBuildPhase section */")
L()

L("/* Begin PBXFrameworksBuildPhase section */")
for phase_id in [FW_BUILD_PHASE, TEST_FW_PHASE, UITEST_FW_PHASE]:
    L(f'\t\t{phase_id} = {{')
    L(f'\t\t\tisa = PBXFrameworksBuildPhase;')
    L(f'\t\t\tbuildActionMask = 2147483647;')
    L(f'\t\t\tfiles = (')
    L(f'\t\t\t);')
    L(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    L(f'\t\t}};')
L("/* End PBXFrameworksBuildPhase section */")
L()

# Build configurations
L("/* Begin XCBuildConfiguration section */")

def project_debug():
    return {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": '"DEBUG=1 $(inherited)"',
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "macosx",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    }

def project_release():
    d = project_debug()
    d.update({
        "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
        "ENABLE_NS_ASSERTIONS": "NO",
        "GCC_OPTIMIZATION_LEVEL": "s",
        "GCC_PREPROCESSOR_DEFINITIONS": '"$(inherited)"',
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "ONLY_ACTIVE_ARCH": "NO",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '""',
        "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
        "VALIDATE_PRODUCT": "YES",
    })
    return d

def app_debug():
    return {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_ENTITLEMENTS": "Trove/Resources/Trove.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "COMBINE_HIDPI_IMAGES": "YES",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_ASSET_PATHS": '""',
        "ENABLE_PREVIEWS": "YES",
        "INFOPLIST_FILE": "Trove/Resources/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/../Frameworks"',
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "MARKETING_VERSION": "0.1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.trove.Trove",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SDKROOT": "macosx",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
    }

def app_release():
    d = app_debug()
    d["SWIFT_EMIT_LOC_STRINGS"] = "NO"
    return d

def test_debug():
    return {
        "BUNDLE_LOADER": '"$(TEST_HOST)"',
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "MARKETING_VERSION": "0.1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.trove.TroveTests",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SDKROOT": "macosx",
        "SWIFT_VERSION": "5.0",
        "TEST_HOST": '"$(BUILT_PRODUCTS_DIR)/Trove.app/Contents/MacOS/Trove"',
    }

def uitest_debug():
    return {
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "MARKETING_VERSION": "0.1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.trove.TroveUITests",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SDKROOT": "macosx",
        "SWIFT_VERSION": "5.0",
        "TEST_TARGET_NAME": "Trove",
    }

def emit_config(cid, name, settings):
    L(f'\t\t{cid} = {{')
    L(f'\t\t\tisa = XCBuildConfiguration;')
    L(f'\t\t\tbuildSettings = {{')
    for k, v in settings.items():
        L(f'\t\t\t\t{k} = {v};')
    L(f'\t\t\t}};')
    L(f'\t\t\tname = {name};')
    L(f'\t\t}};')

emit_config(DEBUG_PROJ,   "Debug",   project_debug())
emit_config(RELEASE_PROJ, "Release", project_release())
emit_config(DEBUG_APP,    "Debug",   app_debug())
emit_config(RELEASE_APP,  "Release", app_release())
emit_config(DEBUG_TEST,   "Debug",   test_debug())
emit_config(RELEASE_TEST, "Release", test_debug())
emit_config(DEBUG_UTEST,  "Debug",   uitest_debug())
emit_config(RELEASE_UTEST,"Release", uitest_debug())
L("/* End XCBuildConfiguration section */")
L()

# XCConfigurationList
L("/* Begin XCConfigurationList section */")

def emit_config_list(cid, configs, default_name, comment):
    L(f'\t\t{cid} = {{')
    L(f'\t\t\tisa = XCConfigurationList;')
    L(f'\t\t\tbuildConfigurations = (')
    for cfg_id, cfg_name in configs:
        L(f'\t\t\t\t{cfg_id} /* {cfg_name} */,')
    L(f'\t\t\t);')
    L(f'\t\t\tdefaultConfigurationIsVisible = 0;')
    L(f'\t\t\tdefaultConfigurationName = {default_name};')
    L(f'\t\t}};')

emit_config_list(CONFIG_LIST_PROJ,  [(DEBUG_PROJ, "Debug"), (RELEASE_PROJ, "Release")],  "Release", "Project")
emit_config_list(CONFIG_LIST_APP,   [(DEBUG_APP,  "Debug"), (RELEASE_APP,  "Release")],  "Release", "Trove")
emit_config_list(CONFIG_LIST_TEST,  [(DEBUG_TEST, "Debug"), (RELEASE_TEST, "Release")],  "Release", "TroveTests")
emit_config_list(CONFIG_LIST_UTEST, [(DEBUG_UTEST,"Debug"), (RELEASE_UTEST,"Release")], "Release", "TroveUITests")
L("/* End XCConfigurationList section */")
L()

L("\t};")
L(f'\trootObject = {PROJECT_ID};')
L("}")

# ── Write files ───────────────────────────────────────────────────────────────

proj_dir = os.path.join(ROOT, "Trove.xcodeproj")
ws_dir   = os.path.join(proj_dir, "project.xcworkspace")
os.makedirs(ws_dir, exist_ok=True)

pbxproj_path = os.path.join(proj_dir, "project.pbxproj")
with open(pbxproj_path, "w") as f:
    f.write("\n".join(lines))
print(f"Wrote {pbxproj_path}")

ws_contents = os.path.join(ws_dir, "contents.xcworkspacedata")
with open(ws_contents, "w") as f:
    f.write(textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace version = "1.0">
           <FileRef location = "self:">
           </FileRef>
        </Workspace>
    """))
print(f"Wrote {ws_contents}")

# Scheme
schemes_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)
scheme_path = os.path.join(schemes_dir, "Trove.xcscheme")
with open(scheme_path, "w") as f:
    f.write(textwrap.dedent(f"""\
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme LastUpgradeVersion = "1500" version = "1.7">
           <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
              <BuildActionEntries>
                 <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
                    <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TARGET_TROVE}" BuildableName = "Trove.app" BlueprintName = "Trove" ReferencedContainer = "container:Trove.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
              <Testables>
                 <TestableReference skipped = "NO">
                    <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TARGET_TESTS}" BuildableName = "TroveTests.xctest" BlueprintName = "TroveTests" ReferencedContainer = "container:Trove.xcodeproj">
                    </BuildableReference>
                 </TestableReference>
              </Testables>
           </TestAction>
           <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
              <BuildableProductRunnable runnableDebuggingMode = "0">
                 <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TARGET_TROVE}" BuildableName = "Trove.app" BlueprintName = "Trove" ReferencedContainer = "container:Trove.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </LaunchAction>
           <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
              <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TARGET_TROVE}" BuildableName = "Trove.app" BlueprintName = "Trove" ReferencedContainer = "container:Trove.xcodeproj">
              </BuildableReference>
           </ArchiveAction>
        </Scheme>
    """))
print(f"Wrote {scheme_path}")
print("\nDone. Open Trove.xcodeproj in Xcode.")
