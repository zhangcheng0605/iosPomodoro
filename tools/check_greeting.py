"""Check the greeting — that it never gets colder, and never mentions the gap.

This is a four-line feature with one property, and the property is the entire
reason it exists:

    **Return is always celebrated. Absence is never mentioned.**

Every retention system ever built does the opposite. The pull toward the
opposite is constant and it is *reasonable-sounding* every single time — "it's
been a while", "we missed you", a slightly sadder pose after a month away.
Each of those is one small edit, each would look fine in review, and together
they turn the one screen in this app that says hello into the one that makes
you feel bad for having a life. So the fence is code.

**Warmth never decreases.** Walked over every gap from zero to a thousand days:
a longer absence must never earn a *cooler* greeting than a shorter one. That
is checked against the real thresholds and lines parsed out of `Greeting.swift`
— not restated here, which is the trap this repo has paid for three times.

**No line refers to the gap, to the reader, or to a failure.** Fifteen
patterns, each one a sentence somebody would write in good faith. "It's been
a while" is the one this exists for.

**Nothing about it is announced.** No `UNUserNotificationCenter` anywhere near
it, ever — a push saying the buddy is waiting is the single most effective
retention message this app could send and the single most damaging.

**And nothing is granted.** A greeting that dropped an acorn would make
opening the app a chore with a payout, and the next obvious step is a reason
to open it twice.

    python3 tools/check_greeting.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
GREETING = os.path.join(MODEL, "Greeting.swift")
ENGINE = os.path.join(ROOT, "Pawmodoro", "TimerEngine.swift")
BUDDYVIEW = os.path.join(ROOT, "Pawmodoro", "Views", "BuddyView.swift")

# Things a hello does not say.
#
# Each is a sentence somebody would write meaning well. That is what makes
# them worth a fence rather than a code review: none of these looks like a
# mistake, and every one of them changes what the app is.
FORBIDDEN = {
    r"\bit'?s been\b": "refers to the gap",
    r"\bwhile\b": "'it's been a while' is the exact sentence this file exists for",
    r"\bmissed\b": "mentions absence",
    r"\bmiss(es|ing)?\b": "mentions absence",
    r"\bfinally\b": "makes returning late a punchline",
    r"\bat last\b": "same",
    r"\bwhere (have )?you\b": "asks the reader to account for themselves",
    r"\bback again\b": "counts the returns",
    r"\bwelcome back\b": "wrong for somebody who has never been here, "
                         "and a receipt for everybody else",
    r"\blonely\b": "makes the buddy a hostage",
    r"\bwaiting for you\b": "same — the idle caption may say it, a greeting "
                            "may not",
    r"\bsad\b": "no",
    r"\bworried\b": "no",
    r"\bagain\b": "counts",
    r"\bdays?\b": "names the gap in units",
    r"\bweeks?\b": "names the gap in units",
    r"\bmonths?\b": "names the gap in units",
    # Added after a break test walked straight through: "counted the quiet
    # mornings" names the absence without using any of the words above, and it
    # is exactly the sentence somebody would write meaning to be tender.
    r"\bmornings?\b": "counts the gap in mornings, which is still counting",
    r"\bnights?\b": "same",
    r"\bcount(ed|ing|s)?\b": "a hello does not keep score",
    r"\bsince\b": "measures from something",
    r"\bquiet\b": "the quiet is the absence, described kindly, which is "
                   "still describing it",
    r"\blast time\b": "compares with a previous visit",
    r"!": "no line in this app exclaims",
}

# Anything that would turn a hello into a transaction, anywhere in the
# greeting's own code.
FORBIDDEN_CALLS = {
    "UNUserNotification": "a greeting must never be announced",
    "UNMutableNotificationContent": "same",
    "scheduleNotification": "same",
    "pouch.take": "a greeting grants nothing",
    "Acorns.": "a greeting grants nothing",
    "streak": "a greeting is not a counter",
}


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_comments(text):
    """Comments out, string literals kept — the literals are what is checked."""
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


def parse_warmths():
    """The cases, thresholds and lines, out of `Greeting.swift`."""
    source = strip_comments(read(GREETING))
    block = re.search(r"enum Warmth[^{]*\{(.*?)\n        \}\n\n        /// The caption",
                      source, re.S)
    cases = re.findall(r"^\s*case (\w+)\s*$",
                       source.split("enum Warmth")[1].split("var reachedAt")[0],
                       re.M)
    if not cases:
        raise SystemExit("Greeting.swift: could not read Warmth's cases")

    reached = {}
    arms = re.search(r"var reachedAt: Int \{\s*switch self \{(.*?)\n        \}",
                     source, re.S)
    if not arms:
        raise SystemExit("Greeting.swift: could not read reachedAt")
    for name, value in re.findall(r"case \.(\w+): ([\w.]+)", arms.group(1)):
        reached[name] = 10 ** 9 if value == "Int.max" else int(value)

    lines = {}
    body = re.search(r"var line: String \{\s*switch self \{(.*?)\n        \}",
                     source, re.S)
    for name, text in re.findall(r'case \.(\w+):\s*((?:"[^"]*"\s*\+?\s*)+)',
                                 body.group(1)):
        lines[name] = " ".join(re.findall(r'"([^"]*)"', text))

    seconds = {}
    hold = re.search(r"var seconds: TimeInterval \{\s*switch self \{(.*?)\n        \}",
                     source, re.S)
    for name, value in re.findall(r"case \.(\w+): ([\d.]+)", hold.group(1)):
        seconds[name] = float(value)

    missing = set(cases) - set(reached) | set(cases) - set(lines)
    if missing:
        raise SystemExit(f"Greeting.Warmth {sorted(missing)} are missing a "
                         f"threshold or a line — this checker would have gone "
                         f"half-blind rather than failing")
    return cases, reached, lines, seconds


def main():
    cases, reached, lines, seconds = parse_warmths()
    failures = []

    # --- 1. Warmth never decreases -----------------------------------------
    #
    # The `for(daysAway:hasSat:)` walk, ported: warmest first, first match
    # wins. Rank is the order the cases are declared in, which is the order the
    # enum is written to read in.
    rank = {name: index for index, name in enumerate(cases)}

    def chosen(days):
        for name in sorted(cases, key=lambda n: -reached[n]):
            # `first` is unreachable by gap — Int.max — and is picked from the
            # absence of history instead.
            if reached[name] >= 10 ** 9:
                continue
            if days >= reached[name]:
                return name
        return cases[0]

    previous, previous_days = None, 0
    for days in range(0, 1001):
        got = chosen(days)
        if previous is not None and rank[got] < rank[previous]:
            failures.append(
                f"a {days}-day absence earns '{got}' while a "
                f"{previous_days}-day one earned '{previous}' — the greeting "
                f"got COLDER for staying away longer, which is the one thing "
                f"this feature may never do")
            break
        previous, previous_days = got, days

    # Every reachable warmth is actually reached by some gap. A tier nobody
    # can earn is a line nobody will ever read.
    seen = {chosen(days) for days in range(0, 1001)}
    for name in cases:
        if reached[name] >= 10 ** 9:
            continue
        if name not in seen:
            failures.append(
                f"Warmth.{name} is never chosen for any gap from 0 to 1000 "
                f"days — its threshold is shadowed by another arm")

    # --- 2. The thresholds go up, in declaration order ---------------------
    ordered = [reached[name] for name in cases if reached[name] < 10 ** 9]
    if ordered != sorted(ordered):
        failures.append(
            f"the thresholds are {ordered}, which is not increasing — the "
            f"table is meant to read in the direction it is written in")

    # --- 3. And so does the hold -------------------------------------------
    held = [seconds.get(name, 0) for name in cases if reached[name] < 10 ** 9]
    if held != sorted(held):
        failures.append(
            f"the greetings hold for {held} seconds — a warmer one that is on "
            f"screen for *less* time is a warmth the reader cannot see")

    # --- 4. Nothing any line says ------------------------------------------
    for name, line in sorted(lines.items()):
        for pattern, why in FORBIDDEN.items():
            if re.search(pattern, line, re.I):
                failures.append(
                    f"Warmth.{name}: \"{line[:52]}…\" — {why}")

    # --- 5. Nothing it does ------------------------------------------------
    #
    # Scoped to the greeting's own code: the model file, the engine's greeting
    # members, and the view's greeting helper. A blanket search of the app
    # would trip on the notification manager it has every right to contain.
    engine = strip_comments(read(ENGINE))
    view = strip_comments(read(BUDDYVIEW))
    scopes = [("Greeting.swift", strip_comments(read(GREETING)))]
    for label, source, anchor in (("TimerEngine.greetIfOwed", engine,
                                   "func greetIfOwed()"),
                                  ("BuddyView.playGreetingIfOwed", view,
                                   "func playGreetingIfOwed()")):
        if anchor not in source:
            failures.append(f"{label} is gone — the greeting is not wired up")
            continue
        start = source.index(anchor)
        scopes.append((label, source[start:start + 900]))

    for label, source in scopes:
        for needle, why in FORBIDDEN_CALLS.items():
            if needle in source:
                failures.append(f"{label} mentions `{needle}` — {why}")

    # --- 6. It never interrupts a session ----------------------------------
    if "func greetIfOwed()" in engine:
        start = engine.index("func greetIfOwed()")
        body = engine[start:start + 700]
        if "runState == .idle" not in body:
            failures.append(
                "greetIfOwed no longer checks that nothing is running — "
                "saying good morning over a focus session is the app talking "
                "across the thing it exists to protect")

    print(f"checked {len(cases)} warmths over 1001 gaps against "
          f"{len(FORBIDDEN)} forbidden phrasings and "
          f"{len(FORBIDDEN_CALLS)} forbidden calls")
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
