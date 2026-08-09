#!/usr/bin/env python3
"""Hold the privacy manifests to what the Swift actually does.

A privacy manifest is a legal declaration, and it is the one file in this
repo that can go quietly false in *both* directions:

  * **Under-declared** — somebody adds `ProcessInfo.processInfo.systemUptime`
    to a spring animation, ships, and the upload comes back ITMS-91053. The
    code is fine, the build is fine, nothing local complains.
  * **Over-declared** — somebody deletes the App Group mirror and leaves
    `1C8F.1` behind, and the app is now claiming a capability it does not
    have, in a document Apple reads as a promise.

So this checker never reads the manifest and agrees with it. It reads the
**Swift** — the same rule `check_weather.py` and `check_touch.py` learned the
hard way — works out which required-reason API categories each target
genuinely touches, and demands the manifests say exactly that. Swap the two
reason codes between the app and the widget and it fails; that is the point.

It also parses `project.pbxproj` for the membership exceptions, because the
widget extension compiles one file that lives in the app's folder, and a
checker that scanned folders alone would have a blind spot exactly one file
wide.

Run: python3 tools/check_privacy.py
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "Pawmodoro.xcodeproj" / "project.pbxproj"

# Apple's allowlist, transcribed from
# developer.apple.com/documentation/BundleResources/
#   app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
# A code outside these sets is not "wrong for this app" — it is not a code.
ALLOWED_REASONS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1", "8FFB.1", "3D61.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"85F4.1", "E174.1", "7D9E.1", "B728.1"},
    "NSPrivacyAccessedAPICategoryActiveKeyboards": {"3EC4.1", "54BD.1"},
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"},
}

# What each category looks like in Swift. Written as call/member shapes rather
# than bare words: `stat` is a word that appears in English prose about
# decaying stats, and this file's first draft matched two comments in
# Model/Antics.swift. Comments are stripped before any of this runs, but the
# patterns stay narrow anyway — a checker that cries wolf gets switched off.
CATEGORY_PATTERNS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": [
        r"\.creationDate\b",
        r"\.modificationDate\b",
        r"\bfileCreationDate\b",
        r"\bfileModificationDate\b",
        r"\.contentModificationDateKey\b",
        r"\.creationDateKey\b",
        r"\.addedToDirectoryDateKey\b",
        r"\.attributeModificationDateKey\b",
        r"\bNSFileCreationDate\b",
        r"\bNSFileModificationDate\b",
        r"\battributesOfItem\s*\(",
        r"\bresourceValues\s*\(",
        r"\b(?:f?get|f)?stat\s*\(",
        r"\bgetattrlist(?:bulk|at)?\s*\(",
        r"\bfgetattrlist\s*\(",
        r"\blstat\s*\(",
        r"\bfstatat\s*\(",
    ],
    "NSPrivacyAccessedAPICategorySystemBootTime": [
        r"\.systemUptime\b",
        r"\bmach_absolute_time\s*\(",
        r"\bmach_continuous_time\s*\(",
        r"\bKERN_BOOTTIME\b",
        r"kern\.boottime",
    ],
    "NSPrivacyAccessedAPICategoryDiskSpace": [
        r"\.volumeAvailableCapacity\w*Key\b",
        r"\.volumeTotalCapacityKey\b",
        r"\bsystemFreeSize\b",
        r"\bNSFileSystemFreeSize\b",
        r"\bNSFileSystemSize\b",
        r"\battributesOfFileSystem\s*\(",
        r"\bf?statv?fs\s*\(",
    ],
    "NSPrivacyAccessedAPICategoryActiveKeyboards": [
        r"\.activeInputModes\b",
        r"\bTISCopyCurrentKeyboardInputSource\s*\(",
    ],
}

# User defaults is split, because the two reason codes are not
# interchangeable and picking one is the mistake this file exists to stop.
# CA92.1 covers the app's own container. 1C8F.1 covers the App Group — and
# CA92.1's own text says it "does not permit ... writing information that can
# be accessed by other apps", so the group write needs its own code.
DEFAULTS_OWN = re.compile(r"UserDefaults\.standard|UserDefaults\s*=\s*\.standard")
DEFAULTS_SUITE = re.compile(r"UserDefaults\s*\(\s*suiteName\s*:")

# The app makes no network calls, and three manifest keys say so. If that ever
# stops being true the manifest is the last place anybody would remember to
# look, so check the claim rather than the key.
NETWORK_PATTERNS = [
    r"\bURLSession\b",
    r"\bNWConnection\b",
    r"\bWKWebView\b",
    r"\bCFURLRequest\b",
    r"\bNSURLConnection\b",
    r"https?://",
]

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT = re.compile(r"//[^\n]*")
STRING_LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def strip_noise(source: str) -> str:
    """Remove comments and string literals.

    Both are places where an API name can appear without being called. The
    doc comment in `WidgetMirror.swift` says "UserDefaults" four times before
    it ever opens one, and a URL in a `///` line is not a network call.
    Replaced with spaces rather than deleted so nothing accidentally joins up.
    """
    source = BLOCK_COMMENT.sub(lambda m: " " * len(m.group()), source)
    source = LINE_COMMENT.sub(lambda m: " " * len(m.group()), source)
    source = STRING_LITERAL.sub(lambda m: " " * len(m.group()), source)
    return source


def membership_exceptions() -> dict[str, list[str]]:
    """Files that belong to a target other than the folder they live in.

    `PawmodoroWidgets/` and `Pawmodoro/` are file-system synchronized groups,
    so target membership is "the folder" plus these. Reading them out of the
    pbxproj rather than hard-coding the one we know about is the difference
    between a checker and a second copy of a fact.
    """
    text = PBXPROJ.read_text()
    out: dict[str, list[str]] = {}
    for block in re.finditer(
        r'Exceptions for "(?P<folder>[^"]+)" folder in "(?P<target>[^"]+)" target'
        r'.*?membershipExceptions\s*=\s*\((?P<files>.*?)\);',
        text,
        re.S,
    ):
        files = re.findall(r"([^\s,()]+)", block.group("files"))
        out.setdefault(block.group("target"), []).extend(
            f"{block.group('folder')}/{f}" for f in files
        )
    return out


def sources_for(folder: str, extra: list[str]) -> list[Path]:
    paths = sorted((ROOT / folder).rglob("*.swift"))
    for rel in extra:
        p = ROOT / rel
        if p.suffix == ".swift" and p.exists() and p not in paths:
            paths.append(p)
    return paths


def audit(paths: list[Path]) -> tuple[dict[str, set[str]], list[str], list[str]]:
    """Return (category -> required reason codes, evidence lines, network hits)."""
    required: dict[str, set[str]] = {}
    evidence: list[tuple[str, str]] = []
    network: list[str] = []
    defaults_category = "NSPrivacyAccessedAPICategoryUserDefaults"

    for path in paths:
        clean = strip_noise(path.read_text())
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(clean.splitlines(), 1):
            for category, patterns in CATEGORY_PATTERNS.items():
                for pattern in patterns:
                    if re.search(pattern, line):
                        required.setdefault(category, set())
                        evidence.append(
                            (category, f"{rel}:{lineno}  {category}  /{pattern}/")
                        )
            if DEFAULTS_OWN.search(line):
                required.setdefault(defaults_category, set()).add("CA92.1")
                evidence.append(
                    (defaults_category, f"{rel}:{lineno}  UserDefaults(own) -> CA92.1")
                )
            if DEFAULTS_SUITE.search(line):
                required.setdefault(defaults_category, set()).add("1C8F.1")
                evidence.append(
                    (defaults_category, f"{rel}:{lineno}  UserDefaults(group) -> 1C8F.1")
                )
            for pattern in NETWORK_PATTERNS:
                if re.search(pattern, line):
                    network.append(f"{rel}:{lineno}  /{pattern}/")

    return required, evidence, network


def check_bundle(name: str, manifest: Path, paths: list[Path], verbose: bool) -> list[str]:
    problems: list[str] = []

    if not manifest.exists():
        return [f"{name}: no privacy manifest at {manifest.relative_to(ROOT)}"]

    try:
        declared_plist = plistlib.loads(manifest.read_bytes())
    except Exception as exc:  # noqa: BLE001 — the message is the whole point
        return [f"{name}: {manifest.relative_to(ROOT)} is not a valid plist ({exc})"]

    required, evidence, network = audit(paths)

    if verbose:
        print(f"\n  {name}: {len(paths)} Swift files")
        for _, line in evidence:
            print(f"    {line}")

    # --- the three "we collect nothing" keys -----------------------------
    if declared_plist.get("NSPrivacyTracking") is not False:
        problems.append(f"{name}: NSPrivacyTracking must be present and false")
    for key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes"):
        value = declared_plist.get(key)
        if value is None:
            problems.append(f"{name}: {key} is missing")
        elif value:
            problems.append(
                f"{name}: {key} is non-empty — this app collects nothing and "
                f"has no network code; if that changed, change PRIVACY.md too"
            )
    if network:
        problems.append(
            f"{name}: network API found, so the empty tracking/collection keys "
            f"may no longer be true — {network[0]}"
        )

    # --- declared vs. what the Swift does --------------------------------
    declared: dict[str, set[str]] = {}
    for entry in declared_plist.get("NSPrivacyAccessedAPITypes", []):
        category = entry.get("NSPrivacyAccessedAPIType")
        reasons = set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
        if category in declared:
            problems.append(f"{name}: {category} declared twice")
        declared[category] = reasons
        if category not in ALLOWED_REASONS:
            problems.append(f"{name}: unknown API category {category!r}")
            continue
        for reason in sorted(reasons - ALLOWED_REASONS[category]):
            problems.append(
                f"{name}: {reason!r} is not one of Apple's codes for {category}"
            )
        if not reasons:
            problems.append(f"{name}: {category} declared with no reason")

    for category in sorted(set(required) | set(declared)):
        want = required.get(category)
        have = declared.get(category)
        if want is None:
            problems.append(
                f"{name}: declares {category} but no source file in this target "
                f"uses it — an unbacked claim is as wrong as a missing one"
            )
        elif have is None:
            first = next(text for cat, text in evidence if cat == category)
            problems.append(
                f"{name}: uses {category} but the manifest does not declare it "
                f"(first hit: {first})"
            )
        elif want and want - have:
            problems.append(
                f"{name}: {category} is missing reason(s) {sorted(want - have)} "
                f"that the source requires"
            )
        elif want and have - want:
            problems.append(
                f"{name}: {category} declares reason(s) {sorted(have - want)} "
                f"with no code behind them in this target"
            )

    return problems


def main() -> int:
    verbose = "-v" in sys.argv or "--verbose" in sys.argv
    exceptions = membership_exceptions()

    bundles = [
        (
            "Pawmodoro.app",
            ROOT / "Pawmodoro" / "PrivacyInfo.xcprivacy",
            sources_for("Pawmodoro", []),
        ),
        (
            "PawmodoroWidgetsExtension.appex",
            ROOT / "PawmodoroWidgets" / "PrivacyInfo.xcprivacy",
            sources_for(
                "PawmodoroWidgets",
                exceptions.get("PawmodoroWidgetsExtension", []),
            ),
        ),
    ]

    problems: list[str] = []
    for name, manifest, paths in bundles:
        problems += check_bundle(name, manifest, paths, verbose)

    if problems:
        print("\ncheck_privacy: FAIL")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print(
        "check_privacy: OK — 2 bundles, manifests match the Swift, "
        "no tracking, no collection, no network"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
