"""Catch the build errors a compiler would, on a machine that hasn't got one.

Most of this app is written on Linux, where there is no Xcode and no Swift
toolchain, and then compiled days later on a Mac. That gap is the most
expensive thing about the project: every mistake made here costs Mac time,
which is the scarce resource, not Linux time.

This is not a type checker and cannot become one. What it does is close the
error classes that are *mechanical* — the ones a careful reader misses and a
compiler catches instantly — so that the first real build is spent on genuine
design problems rather than on typos:

  1. Unbalanced braces, parens and brackets.
  2. `#if DEBUG` / `#else` drift in LaunchOptions. Every flag needs a Release
     stand-in; forget one and the app builds fine in Debug and fails only in
     the Release build at the end of the session.
  3. Asset names that don't exist. Every "buddy_…"/"scene_…"/"stray_…" string
     is checked against the catalog, including the ones assembled by a
     `frame("…")` call in an enum arm.

The app is **two targets**, and both are walked: `Pawmodoro/` and
`PawmodoroWidgets/`, each against its own asset catalogue. It used to be one,
and the widget extension — its own source tree, its own `Assets.xcassets` —
was invisible to this file and to everything else in `tools/`. A mistyped
asset name there is the quietest bug the app can have: it builds, installs,
and draws a blank square on a home screen where there is no console and no
crash report.
  4. `StorageKeys` that aren't in `StorageKeys.all`, which silently breaks
     `-PawmodoroResetState`.
  5. `Theme.…` and `LaunchOptions.…` members that don't exist.
  6. Non-exhaustive switches over the app's own enums.

    python3 tools/check_swift.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Pawmodoro")
ASSETS = os.path.join(SOURCE, "Assets.xcassets")

# The app is two targets, and each carries its own asset catalogue.
#
# For a long time this file knew about one of them. `SOURCE` was the app, the
# walk started there, and `PawmodoroWidgets/` — its own source tree, its own
# `Assets.xcassets` — was invisible to the entire toolchain. An asset name
# typed wrong in a widget is the worst place in the app to hide one: the widget
# builds, installs, and draws a blank square on somebody's home screen, where
# there is no console, no crash, and nobody to notice but the owner of the
# phone. Nothing else in `tools/` looks at that folder either.
#
# The two catalogues are separate on purpose and must be checked separately.
# An extension cannot reach into the containing app's bundle for artwork, so
# `widget_nightcap` existing in `Pawmodoro/Assets.xcassets` would prove nothing
# about the widget — the sprites the widget needs are copied into its own
# catalogue, which is why `buddy_cat_awake` appears in both. Checking a widget
# string against the union of the two would pass exactly the bug this is here
# to catch.
#
# `macos` says whether the target builds for the Mac. The app does, so its
# UIKit fence is enforced; the widget extension is `platformFilter = ios` in
# the project file and imports UIKit plainly, which is correct there.
ROOTS = (
    {"name": "Pawmodoro", "source": SOURCE, "assets": ASSETS, "macos": True},
    {"name": "PawmodoroWidgets",
     "source": os.path.join(ROOT, "PawmodoroWidgets"),
     "assets": os.path.join(ROOT, "PawmodoroWidgets", "Assets.xcassets"),
     "macos": False},
)


def swift_files(root=None):
    """Every Swift file in one target, or in all of them."""
    for chosen in (ROOTS if root is None else (root,)):
        for folder, _, names in os.walk(chosen["source"]):
            if ".xcassets" in folder:
                continue
            for name in sorted(names):
                if name.endswith(".swift"):
                    yield os.path.join(folder, name)


def strip(source):
    """Remove comments and string bodies so brackets inside them don't count."""
    source = re.sub(r'"""(?:[^"\\]|\\.|"(?!""))*"""', '""', source, flags=re.S)
    source = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', source)
    source = re.sub(r"//[^\n]*", "", source)
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return source


def check_brackets(failures):
    for path in swift_files():
        code = strip(open(path).read())
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            if code.count(opener) != code.count(closer):
                failures.append(
                    f"{rel(path)}: {code.count(opener)} '{opener}' vs "
                    f"{code.count(closer)} '{closer}'"
                )


def check_launch_option_parity(failures):
    """Every debug flag needs a Release stand-in, and vice versa.

    A missing one compiles in Debug and only breaks the Release build, which
    is the last thing anybody runs.
    """
    source = open(os.path.join(SOURCE, "LaunchOptions.swift")).read()
    block = re.search(r"#if DEBUG\n(.*?)\n#else\n(.*?)\n#endif", source, re.S)
    if not block:
        failures.append("LaunchOptions.swift: could not find the #if DEBUG block")
        return set()

    def declared(text):
        return set(re.findall(r"^    static (?:let|var) (\w+)", text, re.M))

    debug, release = declared(block.group(1)), declared(block.group(2))
    for name in sorted(debug - release):
        failures.append(
            f"LaunchOptions.{name}: declared under #if DEBUG but has no "
            f"Release stand-in — this only fails the Release build"
        )
    for name in sorted(release - debug):
        failures.append(f"LaunchOptions.{name}: Release-only, never declared for Debug")
    return debug | release


def check_storage_keys(failures):
    source = open(os.path.join(SOURCE, "LaunchOptions.swift")).read()
    block = re.search(r"enum StorageKeys \{(.*?)\n\}", source, re.S)
    if not block:
        failures.append("could not find enum StorageKeys")
        return set()
    body = block.group(1)
    keys = set(re.findall(r"static let (\w+) = \"", body))
    listed = re.search(r"static let all = \[(.*?)\]", body, re.S)
    inside = set(re.findall(r"\w+", listed.group(1))) if listed else set()
    for name in sorted(keys - inside):
        failures.append(
            f"StorageKeys.{name} is not in StorageKeys.all — "
            f"-PawmodoroResetState will leave it behind"
        )
    return keys


def imagesets(root=None):
    """The imagesets one target's own catalogue has. Defaults to the app's."""
    folder = (root or ROOTS[0])["assets"]
    if not os.path.isdir(folder):
        return set()
    return {
        name[: -len(".imageset")]
        for name in os.listdir(folder)
        if name.endswith(".imageset")
    }


ASSET_PREFIXES = ("buddy_", "wild_", "scene_", "vignette_", "fx_", "stray_",
                  "dream_", "snail_", "widget_")


def check_assets(failures):
    """Literal asset names, plus the ones a `frame("…")` arm assembles.

    Each target is held to its **own** catalogue. The widget extension cannot
    read the app's, so a name that resolves in `Pawmodoro/Assets.xcassets` and
    nowhere else is a blank square on the home screen.
    """
    for root in ROOTS:
        have = imagesets(root)
        for path in swift_files(root):
            source = open(path).read()
            for name in re.findall(r'"([a-z0-9_]+)"', source):
                if name.startswith(ASSET_PREFIXES) and name not in have:
                    failures.append(
                        f"{rel(path)}: no imageset named '{name}' in "
                        f"{rel(root['assets'])}")

    have = imagesets()
    # `case .redpanda: frame("armsup")` -> buddy_redpanda_armsup. These are the
    # quirk tables, where a typo is invisible until the sprite doesn't appear.
    buddy = open(os.path.join(SOURCE, "Model", "Buddy.swift")).read()
    for labels, suffix in re.findall(
        r"case ((?:\.\w+,?\s*)+): frame\(\"(\w+)\"\)", buddy
    ):
        for species in re.findall(r"\.(\w+)", labels):
            asset = f"buddy_{species}_{suffix}"
            if asset not in have:
                failures.append(
                    f"Buddy.swift: .{species} refers to frame(\"{suffix}\") "
                    f"but there is no '{asset}'"
                )

    # `self == .capybara ? frame("soak") : nil`
    for species, suffix in re.findall(
        r"self == \.(\w+) \? frame\(\"(\w+)\"\)", buddy
    ):
        asset = f"buddy_{species}_{suffix}"
        if asset not in have:
            failures.append(
                f"Buddy.swift: .{species} refers to frame(\"{suffix}\") "
                f"but there is no '{asset}'"
            )


def check_dream_ids(failures):
    """`Dream.id` and `Dream.from(id:)` must name the same set of prefixes.

    The diary is a dictionary keyed on `Dream.id`, and `from(id:)` is what
    turns those keys back into dreams. Add a case, write its `id`, forget its
    arm in `from(id:)`, and the compiler is perfectly happy: every entry of
    that kind simply stops decoding, and the only symptom is a dream quietly
    missing from a page nobody can count. Nothing else in the toolchain can
    see it.
    """
    path = os.path.join(SOURCE, "Model", "Dream.swift")
    source = open(path).read()

    # `case .memory(let species): "memory.\(species.rawValue)"`. The literal
    # dot is what separates these from the `asset` switch two properties
    # down, whose arms build `dream_heard_\(…)` with no dot at all — the
    # first version of this rule left it out and matched nothing, which it
    # announced by failing on every prefix at once.
    written = set(re.findall(r'case \.\w+\(let \w+\): "(\w+)\.\\\(', source))
    read = set(re.findall(r'case "(\w+)": return ', source))

    for prefix in sorted(written - read):
        failures.append(
            f"Dream.swift: id() writes '{prefix}.…' but from(id:) has no arm "
            f"for it — every dream of that kind would stop decoding"
        )
    for prefix in sorted(read - written):
        failures.append(
            f"Dream.swift: from(id:) reads '{prefix}.…' but id() never "
            f"writes it"
        )


def check_dream_assets(failures, enums):
    """`case .sound(let sound): "dream_heard_\\(sound.rawValue)"` -> one
    imageset per case of `Heard`.

    The associated type comes from the case's own declaration, so this stays
    true when a case is added: the arm names the case, the declaration names
    the enum, and `enum_cases()` names its members. Nothing is hardcoded.

    Worth its own rule because a missing dream sprite fails the way art always
    fails — silently. The bubble draws, and what is inside it is nothing, on a
    screen that takes a hundred and fifty sessions and five seasons to fill.
    """
    have = imagesets()
    path = os.path.join(SOURCE, "Model", "Dream.swift")
    source = open(path).read()
    # `    case sound(Heard)` — one associated type per Dream case.
    types = dict(re.findall(r"\n    case (\w+)\((\w+)\)", source))

    for case, prefix, suffix in re.findall(
        r'case \.(\w+)\(let \w+\): "([a-z0-9_]*)\\\(\w+\.rawValue\)([a-z0-9_]*)"',
        source,
    ):
        owner = types.get(case)
        if owner not in enums:
            failures.append(
                f"Dream.swift: .{case} builds an asset name out of "
                f"{owner or 'an unknown type'}, which is not a CaseIterable "
                f"enum the checker can enumerate"
            )
            continue
        for name in enums[owner]:
            asset = f"{prefix}{name}{suffix}"
            if asset not in have:
                failures.append(
                    f"Dream.swift: .{case} of {owner}.{name} wants "
                    f"'{asset}', which has no imageset"
                )


def check_platform_guards(failures):
    """Every `import UIKit` must be behind a `canImport` or an `os(macOS)` fence.

    The app builds for two platforms now, and an unguarded UIKit import is the
    single most likely way to break the Mac target — it compiles perfectly on
    iOS, so nothing on this side of the build notices. `Platform.swift` is the
    one file allowed to import it plainly, because it *is* the fence.

    The same goes for the UIKit-only types the app still names: `UIImage`,
    `UIColor` and the feedback generators all have `Platform*` aliases now, and
    reaching for the concrete one is how the aliases quietly stop being used.

    Only the targets that build for the Mac are held to this. The widget
    extension is iOS-only in the project file and has no `Platform.swift` of
    its own; `import UIKit` there is not a portability bug, and reporting it as
    one would be a false failure in the file whose whole job is to be believed.
    """
    allowed = {"Pawmodoro/Platform/Platform.swift"}
    banned = ("UIImage", "UIColor", "UIScreen", "UIApplication", "UIDevice",
              "UIImpactFeedbackGenerator", "UINotificationFeedbackGenerator",
              "UIGraphicsImageRenderer")

    for path in (p for r in ROOTS if r["macos"] for p in swift_files(r)):
        name = rel(path)
        if name in allowed:
            continue
        source = open(path).read()
        stripped = strip(source)
        guarded = "#if canImport(UIKit)" in source or "#if os(macOS)" in source \
            or "#if os(iOS)" in source
        for index, line in enumerate(stripped.splitlines(), start=1):
            if re.match(r"^import UIKit\s*$", line) and not guarded:
                failures.append(
                    f"{name}:{index}: `import UIKit` with no #if guard — this "
                    f"compiles on iOS and breaks the Mac target, which nothing "
                    f"on this side of the build can notice")
        if guarded:
            continue
        for symbol in banned:
            if re.search(rf"\b{symbol}\b", stripped):
                failures.append(
                    f"{name}: uses `{symbol}` with no platform guard — there is "
                    f"a `Platform`-prefixed alias for it in Platform.swift")
                break


def check_debug_only_symbols(failures):
    """A type declared inside `#if DEBUG` must not be named outside one.

    `LaunchOptions` flags all have Release stand-ins, so a branch guarded by
    one folds away — but the *symbol* on the other side of it still has to
    exist. A whole file wrapped in `#if DEBUG` has no Release stand-in by
    design, so naming it from ordinary code builds perfectly in Debug and
    fails only in Release.

    Found the hard way: `SnapshotSeed.fill(scrapbook)` sat behind
    `if LaunchOptions.seedScrapbook`, which is a `false` constant in Release
    — and Release still failed, because a constant `false` stops the branch
    running, not the name being resolved.
    """
    debug_only = {}
    for path in swift_files():
        source = open(path).read()
        if not source.lstrip().startswith("#if DEBUG"):
            continue
        # The whole file is Debug-only: collect the types it declares.
        for kind, name in re.findall(
                r"^(enum|struct|final class|class) (\w+)", strip(source), re.M):
            debug_only[name] = rel(path)
    if not debug_only:
        return

    for path in swift_files():
        name = rel(path)
        source = open(path).read()
        if source.lstrip().startswith("#if DEBUG"):
            continue
        stripped = strip(source)
        # Which line ranges are inside a #if DEBUG fence?
        guarded_lines = set()
        depth = 0
        for index, line in enumerate(stripped.splitlines(), start=1):
            bare = line.strip()
            if re.match(r"#if\s+DEBUG", bare):
                depth += 1
            elif bare.startswith("#if"):
                if depth:
                    depth += 1
            elif bare.startswith("#endif") and depth:
                depth -= 1
            if depth:
                guarded_lines.add(index)
        for index, line in enumerate(stripped.splitlines(), start=1):
            if index in guarded_lines:
                continue
            for symbol, home in debug_only.items():
                if re.search(rf"\b{symbol}\b", line):
                    failures.append(
                        f"{name}:{index}: names `{symbol}`, which is declared "
                        f"inside `#if DEBUG` in {home} — this builds in Debug "
                        f"and fails the Release build")


def check_members(failures, launch_options):
    """`Theme.x` and `LaunchOptions.x` that were never declared."""
    theme = open(os.path.join(SOURCE, "Theme.swift")).read()
    known_theme = set(re.findall(r"static (?:let|var|func) (\w+)", theme))

    for path in swift_files():
        source = strip(open(path).read())
        for name in set(re.findall(r"\bTheme\.(\w+)", source)):
            if name not in known_theme:
                failures.append(f"{rel(path)}: Theme.{name} does not exist")
        for name in set(re.findall(r"\bLaunchOptions\.(\w+)", source)):
            if name not in launch_options | {"minute", "applyAtLaunch"}:
                failures.append(f"{rel(path)}: LaunchOptions.{name} does not exist")


def check_duplicate_enums(failures, duplicates):
    """Two enums with the same simple name make this file blind.

    `enum_cases` keys on the bare name, so `Grove.Stage` and `Stray.Stage`
    merge into one case list — and every `switch self` over either is then
    checked against the union. That produces confident, wrong failures in one
    direction and silent blindness in the other, which is worse. Renaming one
    is a two-minute fix and the alternative is a checker nobody believes.
    """
    for name, owners in sorted(duplicates.items()):
        failures.append(
            f"two enums are both called '{name}' ({', '.join(sorted(owners))})"
            f" — check_swift.py matches on the simple name, so it cannot tell "
            f"their switches apart. Rename one."
        )


def enum_cases():
    """Every CaseIterable enum the app owns, and its cases.

    Returns the map and, separately, any name declared more than once — see
    `check_duplicate_enums`, which turns that into a failure rather than
    letting the two quietly merge.
    """
    found = {}
    duplicates = {}
    for path in swift_files():
        lines = open(path).read().splitlines()
        for index, line in enumerate(lines):
            header = re.match(r"^([ ]*)enum (\w+):([^{]*)\{", line)
            if not header or "CaseIterable" not in header.group(3):
                continue
            outer, name = header.group(1), header.group(2)
            indent = outer + "    "
            # Walked line by line rather than matched with one regex, because
            # a regex has to choose between two failures and there is no third
            # option. Stopping at the first closing brace folds a nested
            # enum's cases into its parent — `Accessory` came back owning
            # `.head` and `.neck` from its own `Slot`, and the checker reported
            # four confident, wrong non-exhaustive switches. Stopping at the
            # *matching* brace instead swallows the nested enum whole, because
            # `finditer` will not return overlapping matches: `Species.Rarity`
            # silently stopped being checked at all. Walking sees both.
            cases = []
            for row in lines[index + 1:]:
                if row.startswith(outer + "}"):
                    break
                arm = re.match(re.escape(indent) + r"case (\w+)(?: = .*)?$", row)
                if arm:
                    cases.append(arm.group(1))
                    continue
                listed = re.match(
                    re.escape(indent) + r"case (\w+(?:, \w+)+)$", row)
                if listed:
                    cases.extend(n.strip() for n in listed.group(1).split(","))
            if cases:
                if name in found and found[name] != cases:
                    duplicates.setdefault(name, set()).add(rel(path))
                found[name] = cases
    return found, duplicates


def blank(source):
    """Comments and string bodies replaced by spaces, keeping every offset.

    Same idea as `strip`, but length-preserving, so brace positions found here
    still point at the right place in the original text.
    """
    out = list(source)
    i, n = 0, len(source)
    while i < n:
        two = source[i:i + 2]
        if two == "//":
            while i < n and source[i] != "\n":
                out[i] = " "
                i += 1
        elif two == "/*":
            while i < n and source[i:i + 2] != "*/":
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            for j in range(i, min(i + 2, n)):
                out[j] = " "
            i += 2
        elif source[i] == '"':
            out[i] = " "
            i += 1
            while i < n and source[i] != '"':
                if source[i] == "\\":
                    out[i] = " "
                    i += 1
                if i < n and source[i] != "\n":
                    out[i] = " "
                i += 1
            if i < n:
                out[i] = " "
                i += 1
        else:
            i += 1
    return "".join(out)


def enclosing_scopes(code):
    """Every `enum X { … }` and `extension X { … }`'s extent, innermost last
    when sorted by start.

    Needed because enums nest: `Dream` declares `Surreal` inside itself, and a
    naive "most recent enum seen" rule blames the inner one for every switch in
    the outer one after it. That produced six false failures, which is worse
    than none — a checker nobody believes is a checker nobody runs.

    Extensions count because half the app's tables live in one — `Buddy`'s
    dream lines, `Heard`'s and `Season`'s, `Place`'s. Before this they were
    invisible here: a new buddy broke four switches and the checker reported
    three of them, which reads as "you're done" and is the worst answer a
    checker can give.
    """
    scopes = []
    for match in re.finditer(r"\b(?:enum|extension) (\w+)\b[^\n{]*\{", code):
        start = match.end() - 1
        depth = 0
        for index in range(start, len(code)):
            if code[index] == "{":
                depth += 1
            elif code[index] == "}":
                depth -= 1
                if depth == 0:
                    scopes.append((match.group(1), start, index))
                    break
    return scopes


def check_switch_exhaustiveness(failures, enums):
    """A `switch self` with no `default` must name every case.

    Adding a case to an enum and missing one of its tables is the single most
    likely way this codebase fails to build, because the tables are spread
    across a file rather than gathered in one place.
    """
    for path in swift_files():
        source = open(path).read()
        code = blank(source)
        scopes = enclosing_scopes(code)

        for match in re.finditer(r"switch self \{", code):
            start = match.end() - 1
            depth = 0
            end = None
            for index in range(start, len(code)):
                if code[index] == "{":
                    depth += 1
                elif code[index] == "}":
                    depth -= 1
                    if depth == 0:
                        end = index
                        break
            if end is None:
                continue

            # Innermost enum containing this switch.
            containing = [s for s in scopes if s[1] < start and end < s[2]]
            if not containing:
                continue
            owner = max(containing, key=lambda s: s[1])[0]
            body = source[start:end]
            if owner not in enums or re.search(r"\bdefault\s*:", body):
                continue

            # `[^:]+?` rather than `[^:\n]+`: a long case list wraps onto the
            # next line, and requiring the colon on the same line as `case`
            # silently skipped every one of them. That is a false *negative*
            # dressed as a false positive — the rule looked strict and was
            # blind to exactly the arms most likely to go stale.
            named = set()
            for arm in re.findall(r"\bcase\s+([^:]+?):", blank(body)):
                named.update(re.findall(r"\.(\w+)", arm))
            missing = [c for c in enums[owner] if c not in named]
            if missing:
                line = source[:start].count("\n") + 1
                failures.append(
                    f"{rel(path)}:{line}: switch over {owner} is missing "
                    f"{', '.join('.' + m for m in missing)}"
                )


def check_constellation_links(failures):
    """A link naming a star that doesn't exist is an index-out-of-range crash
    the moment that figure is drawn, and the compiler cannot see it — the
    counts only exist at runtime.
    """
    path = os.path.join(SOURCE, "Model", "Constellation.swift")
    if not os.path.exists(path):
        return
    source = open(path).read()
    for match in re.finditer(
        r'id: "(\w+)",.*?stars: \[(.*?)\],\s*\n\s*links: \[(.*?)\]\s*\n\s*\)',
        source, re.S,
    ):
        name, stars, links = match.groups()
        count = len(re.findall(r"CGPoint\(", stars))
        pairs = [
            (int(a), int(b)) for a, b in re.findall(r"\((\d+), *(\d+)\)", links)
        ]
        for a, b in pairs:
            if a >= count or b >= count:
                failures.append(
                    f"Constellation.swift: '{name}' has {count} stars but a "
                    f"link joins ({a}, {b}) — that is a crash when it is drawn"
                )
        if a_self := [p for p in pairs if p[0] == p[1]]:
            failures.append(
                f"Constellation.swift: '{name}' links a star to itself {a_self}"
            )


def rel(path):
    return os.path.relpath(path, ROOT)


def main():
    failures = []
    check_brackets(failures)
    launch_options = check_launch_option_parity(failures)
    check_storage_keys(failures)
    check_assets(failures)
    check_members(failures, launch_options)
    check_platform_guards(failures)
    check_debug_only_symbols(failures)
    enums, duplicate_enums = enum_cases()
    check_duplicate_enums(failures, duplicate_enums)
    # An ambiguous name is dropped rather than checked against a merged case
    # list. Reporting "switch over Stage is missing .home" in a file that has
    # never heard of the stray is a confident wrong answer, and a wall of them
    # buries the one message that says what to actually do.
    for name in duplicate_enums:
        enums.pop(name, None)
    check_dream_ids(failures)
    check_dream_assets(failures, enums)
    check_switch_exhaustiveness(failures, enums)
    check_constellation_links(failures)

    files = list(swift_files())
    targets = ", ".join(
        f"{r['name']} {len(list(swift_files(r)))} files/"
        f"{len(imagesets(r))} imagesets" for r in ROOTS)
    print(f"checked {len(files)} Swift files across {len(ROOTS)} targets "
          f"({targets}), {len(enums)} CaseIterable enums "
          f"({', '.join(f'{k}:{len(v)}' for k, v in sorted(enums.items()))})")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass — note this is not a type checker; it cannot see "
          "argument labels, inference or SwiftUI misuse")
    return 0


if __name__ == "__main__":
    sys.exit(main())
