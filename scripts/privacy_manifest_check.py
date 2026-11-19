#!/usr/bin/env python3
"""A152 (D238): the privacy manifests say what the code does.

Apple requires a reason in PrivacyInfo.xcprivacy for every "required reason API" category a bundle's code uses.
This reads the Swift sources of each target, finds the categories they use, and compares them with the target's
manifest. It fails when a category is used but not declared, declared but not used, declared with a reason code
Apple does not list for it, or when the manifest says the app tracks. Categories, symbols and codes are Apple's
(developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes, read
2026-11-19). Runs anywhere: python3 scripts/privacy_manifest_check.py
"""
import glob
import os
import plistlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREFIX = "NSPrivacyAccessedAPICategory"

# Category -> (pattern over the code, the reason codes Apple lists for it).
CATEGORIES = {
    "UserDefaults": (r"\bUserDefaults\b|@AppStorage\b|@SceneStorage\b", {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"}),
    "FileTimestamp": (
        r"\.creationDate\b|\.modificationDate\b|fileModificationDate|contentModificationDate|creationDateKey"
        r"|\bf?stat\s*\(|\blstat\s*\(|\bfstatat\s*\(|getattrlist",
        {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"}),
    "SystemBootTime": (r"\bsystemUptime\b|\bmach_absolute_time\s*\(", {"35F9.1", "8FFB.1", "3D61.1"}),
    "DiskSpace": (
        r"volumeAvailableCapacity|volumeTotalCapacityKey|\bsystemFreeSize\b|\bsystemSize\b|\bf?statv?fs\s*\(",
        {"85F4.1", "E174.1", "7D9E.1", "B728.1"}),
    "ActiveKeyboards": (r"\bactiveInputModes\b", {"3EC4.1", "54BD.1"}),
}

DATA_TYPES = {
    "UserID", "DeviceID", "OtherUserContent", "CustomerSupport", "PhotosorVideos", "AudioData", "Contacts",
    "PurchaseHistory", "ProductInteraction", "EmailsOrTextMessages", "GameplayContent", "Name", "EmailAddress",
    "PhoneNumber", "PhysicalAddress", "OtherUserContactInfo", "Health", "Fitness", "PaymentInfo", "CreditInfo",
    "OtherFinancialInfo", "PreciseLocation", "CoarseLocation", "SensitiveInfo", "BrowsingHistory", "SearchHistory",
    "AdvertisingData", "OtherUsageData", "CrashData", "PerformanceData", "OtherDiagnosticData", "OtherDataTypes",
    "EnvironmentScanning", "Hands", "Head",
}
PURPOSES = {"ThirdPartyAdvertising", "DeveloperAdvertising", "Analytics", "ProductPersonalization", "AppFunctionality", "Other"}

# Target -> (its manifest, the source folders compiled into its executable). The local packages are linked
# statically into the app, so their code is the app's.
TARGETS = {
    "Lumen": ("Lumen/Resources/PrivacyInfo.xcprivacy", ["Lumen", "Shared", "Packages/LumenScoring/Sources", "Packages/LumenVAD/Sources"]),
    "LumenControls": ("LumenControls/PrivacyInfo.xcprivacy", ["LumenControls", "Shared"]),
}


def code_lines(path):
    """The lines of a Swift file that are code: comment lines and trailing comments do not use an API."""
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
                continue
            yield number, re.sub(r"\s//.*$", "", line.rstrip("\n"))


def used(folders):
    """Category -> the places in the code that use it."""
    found = {name: [] for name in CATEGORIES}
    for folder in folders:
        for path in sorted(glob.glob(os.path.join(ROOT, folder, "**", "*.swift"), recursive=True)):
            for number, line in code_lines(path):
                for name, (pattern, _) in CATEGORIES.items():
                    if re.search(pattern, line):
                        found[name].append(f"{os.path.relpath(path, ROOT)}:{number}")
    return {name: places for name, places in found.items() if places}


def check(target, manifest_path, folders):
    errors = []
    full = os.path.join(ROOT, manifest_path)
    if not os.path.exists(full):
        return [f"{target}: {manifest_path} is missing"]
    with open(full, "rb") as handle:
        manifest = plistlib.load(handle)
    if manifest.get("NSPrivacyTracking") is not False:
        errors.append(f"{target}: NSPrivacyTracking must be false (no tracking, granskning.md §2)")
    if manifest.get("NSPrivacyTrackingDomains"):
        errors.append(f"{target}: NSPrivacyTrackingDomains must be empty")

    declared = {}
    for entry in manifest.get("NSPrivacyAccessedAPITypes", []):
        name = entry.get("NSPrivacyAccessedAPIType", "")
        declared[name.removeprefix(PREFIX)] = set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
    in_code = used(folders)

    for name, places in in_code.items():
        if name not in declared:
            errors.append(f"{target}: the code uses {name} ({places[0]} and {len(places) - 1} more) but the manifest does not declare it")
    for name, reasons in declared.items():
        if name not in CATEGORIES:
            errors.append(f"{target}: {PREFIX}{name} is not one of Apple's categories")
            continue
        if name not in in_code:
            errors.append(f"{target}: the manifest declares {name} but the code does not use it")
        if not reasons:
            errors.append(f"{target}: {name} has no reason")
        for code in sorted(reasons - CATEGORIES[name][1]):
            errors.append(f"{target}: {code} is not a reason Apple lists for {name}")

    # The app group: user defaults shared between the app and its extension need 1C8F.1; the app's own need CA92.1.
    if "UserDefaults" in declared:
        group = any("suiteName" in line and "appGroup" in line
                    for folder in folders
                    for path in glob.glob(os.path.join(ROOT, folder, "**", "*.swift"), recursive=True)
                    for _, line in code_lines(path))
        if group and "1C8F.1" not in declared["UserDefaults"]:
            errors.append(f"{target}: the code reads the app group's user defaults, so UserDefaults needs 1C8F.1")
        if target == "Lumen" and "CA92.1" not in declared["UserDefaults"]:
            errors.append(f"{target}: the app's own user defaults need CA92.1")

    seen = set()
    for entry in manifest.get("NSPrivacyCollectedDataTypes", []):
        kind = entry.get("NSPrivacyCollectedDataType", "").removeprefix("NSPrivacyCollectedDataType")
        if kind not in DATA_TYPES:
            errors.append(f"{target}: NSPrivacyCollectedDataType{kind} is not one of Apple's data types")
        if kind in seen:
            errors.append(f"{target}: {kind} is listed twice")
        seen.add(kind)
        if not isinstance(entry.get("NSPrivacyCollectedDataTypeLinked"), bool):
            errors.append(f"{target}: {kind} must say whether it is linked to the user")
        if entry.get("NSPrivacyCollectedDataTypeTracking") is not False:
            errors.append(f"{target}: {kind} must not be used for tracking")
        purposes = [p.removeprefix("NSPrivacyCollectedDataTypePurpose") for p in entry.get("NSPrivacyCollectedDataTypePurposes", [])]
        if not purposes:
            errors.append(f"{target}: {kind} has no purpose")
        for purpose in purposes:
            if purpose not in PURPOSES:
                errors.append(f"{target}: {purpose} is not one of Apple's purposes")
            if purpose in ("ThirdPartyAdvertising", "DeveloperAdvertising"):
                errors.append(f"{target}: {kind} is declared for advertising; the app has none")

    print(f"{target} ({manifest_path})")
    for name in CATEGORIES:
        places = in_code.get(name, [])
        reasons = ", ".join(sorted(declared.get(name, []))) or "–"
        where = f"{len(places)} places, e.g. {places[0]}" if places else "not used"
        print(f"  {name:16} code: {where:70} manifest: {reasons}")
    print(f"  collected data types: {', '.join(sorted(seen)) or 'none'}")
    return errors


def main():
    errors = []
    for target, (manifest_path, folders) in TARGETS.items():
        errors += check(target, manifest_path, folders)
    for error in errors:
        print(f"::error::{error}")
    if errors:
        return 1
    print("Privacy manifests match the code.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
