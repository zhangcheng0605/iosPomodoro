"""Check the treats — that nobody is hungry, and that every buddy has an answer.

This is the feature in the app closest to a Tamagotchi, and a Tamagotchi guilt
loop is the single fastest way to ruin everything this app is. Three treats,
free and infinite, no meter behind them. Every one of the edits that would
turn that into a chore is small, reasonable-looking, and invisible in review:

    a `lastFed` date · a hunger value · a bond bump on a favourite ·
    an acorn cost · a notification when the bowl is empty

So the fences are code, scoped to the treat's own files rather than searched
across an app that has every right to contain a notification manager.

The table half is simpler and is the thing that would actually break by
accident:

**Every buddy has a favourite and a decline, and they are different.** A buddy
that both loves and refuses the same treat is a table edited in one place. And
every buddy needs a third treat left over — the ordinary `accepted` reception
— or one of the three lines can never be read for that animal.

**Every treat is somebody's favourite and somebody's refusal.** A treat nobody
wants is a sprite that exists to be declined, and a treat everybody wants is
not a preference.

**Nothing about a decline is unkind.** Twelve forbidden phrasings. The point of
preferences is personality, not a wrong answer to find.

    python3 tools/check_treats.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
TREAT = os.path.join(MODEL, "Treat.swift")
BUDDY = os.path.join(MODEL, "Buddy.swift")
ENGINE = os.path.join(ROOT, "Pawmodoro", "TimerEngine.swift")
TRAY = os.path.join(ROOT, "Pawmodoro", "Views", "TreatTray.swift")
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")

# A refusal that is unkind is a wrong answer, and a wrong answer turns a
# preference into a puzzle with a loser.
UNKIND = {
    r"\brefus": "a buddy declines; it does not refuse",
    r"\bhate": "no",
    r"\bdislike": "no",
    r"\bturned away\b": "reads as rejection rather than as not fancying it",
    r"\bignor": "same",
    r"\bspat\b": "same",
    r"\bwrong\b": "there is no wrong answer here",
    r"\bshould": "instructs",
    r"\bagain\b": "counts the attempts",
    r"\btry\b": "makes it a puzzle",
    r"\bwaste": "no",
    r"!": "no line in this app exclaims",
}

# Anything that would put a meter behind it. Scoped to the treat's own code.
FORBIDDEN = {
    "lastFed": "a 'last fed' date is a hunger clock with the numbers hidden",
    "hunger": "nothing in this app is hungry",
    "hungry": "same",
    "feedCount": "a treat is not counted",
    "Acorns": "treats are free — fence 6",
    "price": "same",
    "pouch.take": "same",
    "UNUserNotification": "no notification ever mentions this",
    "bond": "a treat does not raise the bond; if it did, somebody would work "
            "out the optimal feeding schedule inside a week",
    "rollSighting": "a treat does not make an animal likelier",
}


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_comments(text):
    out, i = [], 0
    while i < len(text):
        two = text[i:i + 2]
        if two == "//":
            while i < len(text) and text[i] != "\n":
                i += 1
        elif two == "/*":
            i += 2
            while i < len(text) and text[i:i + 2] != "*/":
                i += 1
            i += 2
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def arms(source, member):
    """`case .name: .value` pairs of one computed property."""
    block = re.search(r"var %s: \w+ \{\s*switch self \{(.*?)\n    \}" % member,
                      source, re.S)
    if not block:
        return {}
    found = {}
    for names, value in re.findall(r"case ([\w., ]+):\s*\.(\w+)",
                                   block.group(1)):
        for name in re.findall(r"\.(\w+)", names):
            found[name] = value
    return found


def lines_of(source, member):
    """`case .name: "text"` pairs, including `+`-joined continuations."""
    block = re.search(r"var %s: String \{\s*switch self \{(.*?)\n        \}"
                      % member, source, re.S)
    if not block:
        return {}
    found = {}
    for name, text in re.findall(r'case \.(\w+):\s*((?:"[^"]*"\s*\+?\s*)+)',
                                 block.group(1)):
        found[name] = " ".join(re.findall(r'"([^"]*)"', text))
    return found


def main():
    treat_source = strip_comments(read(TREAT))
    buddy_source = strip_comments(read(BUDDY))
    failures = []

    treats = re.findall(r"^    case (\w+)$",
                        treat_source.split("enum Treat")[1].split("var id")[0],
                        re.M)
    if not treats:
        raise SystemExit("Treat.swift: could not read the cases")
    buddies = re.findall(r"^    case (\w+)$",
                         buddy_source.split("enum Buddy")[1].split("var id")[0],
                         re.M)
    if not buddies:
        buddies = re.findall(r"\.(\w+)",
                             re.search(r"enum Buddy[^{]*\{\s*case ([\w, ]+)",
                                       buddy_source).group(1))
    if not buddies:
        raise SystemExit("Buddy.swift: could not read the cases")

    favourite = arms(treat_source, "favouriteTreat")
    declined = arms(treat_source, "declinedTreat")

    # --- 1. Every buddy has both, and they differ -------------------------
    for buddy in buddies:
        loves, hates = favourite.get(buddy), declined.get(buddy)
        if loves is None:
            failures.append(f"{buddy} has no favourite treat")
        if hates is None:
            failures.append(f"{buddy} has no declined treat")
        if loves and hates and loves == hates:
            failures.append(
                f"{buddy} both loves and declines the {loves} — a table edited "
                f"in one place. `reception(of:)` checks the favourite first, "
                f"so the decline is dead code and that buddy can never nudge "
                f"anything back")
        if loves and hates and len(treats) > 2:
            leftover = set(treats) - {loves, hates}
            if not leftover:
                failures.append(
                    f"{buddy} has no treat left over — the ordinary "
                    f"`accepted` line can never be read for it")

    # --- 2. Every treat is wanted by somebody and declined by somebody -----
    for treat in treats:
        if treat not in favourite.values():
            failures.append(
                f"nothing's favourite is the {treat} — a sprite that exists "
                f"only to be declined")
        if treat not in declined.values():
            failures.append(
                f"nobody declines the {treat} — a treat everybody accepts is "
                f"not a preference")

    # --- 3. No decline is unkind ------------------------------------------
    for member in ("nudgedLine", "takenLine", "acceptedLine"):
        for name, line in sorted(lines_of(treat_source, member).items()):
            for pattern, why in UNKIND.items():
                if re.search(pattern, line, re.I):
                    failures.append(
                        f"Treat.{name}.{member}: \"{line[:48]}…\" — {why}")

    # --- 4. Nothing behind it ---------------------------------------------
    scopes = [("Treat.swift", treat_source), ("TreatTray.swift",
                                              strip_comments(read(TRAY)))]
    engine = strip_comments(read(ENGINE))
    if "func offer(_ treat: Treat)" not in engine:
        failures.append("TimerEngine.offer is gone — the treats are not wired "
                        "up to anything")
    else:
        start = engine.index("func offer(_ treat: Treat)")
        scopes.append(("TimerEngine.offer", engine[start:start + 800]))
    for label, source in scopes:
        for needle, why in FORBIDDEN.items():
            if needle in source:
                failures.append(f"{label} mentions `{needle}` — {why}")

    # --- 5. It never appears during focus ---------------------------------
    content = strip_comments(read(os.path.join(
        ROOT, "Pawmodoro", "Views", "ContentView.swift")))
    if "TreatTray()" not in content:
        failures.append("TreatTray is never mounted")
    else:
        start = max(0, content.index("TreatTray()") - 400)
        guard = content[start:content.index("TreatTray()")]
        if "runState != .running" not in guard and "isBreak" not in guard:
            failures.append(
                "TreatTray is mounted without a guard on the run state — a "
                "treat offered mid-focus is a reason to touch the screen "
                "during the one stretch of time this app protects")

    # --- 6. The sprites exist ---------------------------------------------
    for treat in treats:
        path = os.path.join(ASSETS, f"treat_{treat}.imageset",
                            f"treat_{treat}.png")
        if not os.path.exists(path):
            failures.append(f"treat_{treat}: missing — run "
                            f"tools/generate_keepsakes.py")

    # --- 7. The accessible path survives ----------------------------------
    #
    # A drag target is unreachable by VoiceOver and by Switch Control, and
    # this is a gesture of affection — the last feature in the app that should
    # be dexterity-gated.
    tray = read(TRAY)
    if "onTapGesture" not in tray:
        failures.append(
            "TreatTray has lost its tap — the drag is the nice path and the "
            "tap is the only one VoiceOver and Switch Control can take")
    if "accessibilityLabel" not in tray:
        failures.append("TreatTray's treats are unlabelled")

    print(f"checked {len(treats)} treats across {len(buddies)} buddies, "
          f"{len(UNKIND)} phrasings and {len(FORBIDDEN)} forbidden mechanics")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
