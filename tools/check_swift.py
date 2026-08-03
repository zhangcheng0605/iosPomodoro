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


def swift_files():
    for folder, _, names in os.walk(SOURCE):
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


def imagesets():
    return {
        name[: -len(".imageset")]
        for name in os.listdir(ASSETS)
        if name.endswith(".imageset")
    }


ASSET_PREFIXES = ("buddy_", "wild_", "scene_", "vignette_", "fx_", "stray_")


def check_assets(failures):
    """Literal asset names, plus the ones a `frame("…")` arm assembles."""
    have = imagesets()

    for path in swift_files():
        source = open(path).read()
        for name in re.findall(r'"([a-z0-9_]+)"', source):
            if name.startswith(ASSET_PREFIXES) and name not in have:
                failures.append(f"{rel(path)}: no imageset named '{name}'")

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


def enum_cases():
    """Every CaseIterable enum the app owns, and its cases."""
    found = {}
    for path in swift_files():
        source = open(path).read()
        for match in re.finditer(
            r"enum (\w+):[^\n{]*CaseIterable[^\n{]*\{(.*?)\n(?:    )?\}",
            source, re.S,
        ):
            name, body = match.group(1), match.group(2)
            cases = []
            for line in body.splitlines():
                arm = re.match(r"\s*case (\w+)(?: = .*)?$", line)
                if arm:
                    cases.append(arm.group(1))
                else:
                    listed = re.match(r"\s*case (\w+(?:, \w+)+)$", line)
                    if listed:
                        cases.extend(n.strip() for n in listed.group(1).split(","))
            if cases:
                found[name] = cases
    return found


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
    """Every `enum X { … }`'s extent, innermost last when sorted by start.

    Needed because enums nest: `Dream` declares `Surreal` inside itself, and a
    naive "most recent enum seen" rule blames the inner one for every switch in
    the outer one after it. That produced six false failures, which is worse
    than none — a checker nobody believes is a checker nobody runs.
    """
    scopes = []
    for match in re.finditer(r"\benum (\w+)\b[^\n{]*\{", code):
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
    enums = enum_cases()
    check_switch_exhaustiveness(failures, enums)
    check_constellation_links(failures)

    files = list(swift_files())
    print(f"checked {len(files)} Swift files, {len(imagesets())} imagesets, "
          f"{len(enums)} CaseIterable enums "
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
