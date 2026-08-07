"""Check the Sunday Post — that it covers what it should, and sounds like this app.

The letter is the Deep Time plan's **aggregation surface**: the design is that
small systems get a weekly *sentence* instead of a screen of their own. That
only works if adding a system actually gets it a sentence, and forgetting is
completely invisible — the letter simply never mentions it, forever, and reads
perfectly well without it. Nothing else in the toolchain can see the absence of
a sentence.

So this asserts two things.

**Coverage.** Every `ChronicleEvent.Kind` is either handled in `eventLines` or
named in `SundayPost.silentKinds` with a reason next to it. Adding a kind now
fails here until somebody decides which it is.

**Voice.** The letter is the one surface in the app addressed *to* the reader,
which makes it the one most likely to drift into the register this app spends
its whole design avoiding. Every sentence is checked against a list of things
it may not do: congratulate, instruct, exclaim, or mention a week that did not
happen. The list is short and specific on purpose — this is not a style
checker, it is a fence around five or six sentences that would each be a small
betrayal.

    python3 tools/check_post.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
POST = os.path.join(MODEL, "SundayPost.swift")
CHRONICLE = os.path.join(MODEL, "Chronicle.swift")

# Things a letter from an animal who likes you does not say.
#
# Each is paired with what it would actually be doing. These are not banned
# words in general — "goal" is fine in a plan document — they are banned in
# the four hundred characters a week that this app puts in somebody's hands.
FORBIDDEN = {
    r"\bstreak\b": "makes the letter about a counter that can break",
    r"\bgoal\b": "the app does not have goals and must not invent one",
    r"\btarget\b": "same",
    r"\byou should\b": "instructing",
    r"\btry to\b": "instructing",
    r"\bkeep it up\b": "congratulating",
    r"\bwell done\b": "congratulating",
    r"\bgreat job\b": "congratulating",
    r"\bproud\b": "congratulating",
    r"\byou missed\b": "mentions an absence, which the letter never does",
    r"\bonly \d": "makes a small week sound small",
    r"\blast week\b": "comparison with another week",
    r"\bmore than\b": "comparison",
    r"\bbetter\b": "comparison",
    r"!": "no letter in this app exclaims",
}


def sentences():
    """Every user-facing string literal in SundayPost.swift.

    Interpolations are left in as `\\(...)` and simply skipped by the word
    checks, which is right: what is being checked is the writing around them.
    """
    source = open(POST).read()
    # Skip doc comments, which talk *about* the rules using the banned words.
    code = re.sub(r"^\s*//.*$", "", source, flags=re.M)
    found = []
    for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', code):
        text = match.group(1)
        # Only prose: anything without a space is an identifier or a format.
        if " " in text and len(text) > 8:
            found.append((source[:match.start()].count("\n") + 1, text))
    return found


def main():
    failures = []

    # 1. Coverage: every Chronicle kind handled or explicitly silent.
    chronicle = open(CHRONICLE).read()
    block = re.search(r"enum Kind: String, Codable, CaseIterable \{(.*?)\n    \}",
                      chronicle, re.S)
    if not block:
        print("could not find ChronicleEvent.Kind", file=sys.stderr)
        return 1
    kinds = set(re.findall(r"^\s*case (\w+)$", block.group(1), flags=re.M))

    post = open(POST).read()
    handled = set(re.findall(r"\$0\.kind == \.(\w+)", post))
    silent_block = re.search(r"silentKinds: \[ChronicleEvent\.Kind\] = \[(.*?)\]",
                             post, re.S)
    silent = set(re.findall(r"\.(\w+)", silent_block.group(1))) if silent_block else set()

    for kind in sorted(kinds - handled - silent):
        failures.append(
            f"ChronicleEvent.Kind.{kind} has no sentence in the Sunday Post "
            f"and is not in SundayPost.silentKinds — the letter is the "
            f"aggregation surface, so a kind with neither gets no surface at all"
        )
    for kind in sorted(silent & handled):
        failures.append(
            f"ChronicleEvent.Kind.{kind} is in silentKinds but is also "
            f"handled — one of the two is stale"
        )
    for kind in sorted((silent | handled) - kinds):
        failures.append(f"the Sunday Post refers to a kind '{kind}' that no "
                        f"longer exists")

    # 2. Voice.
    lines = sentences()
    for line_number, text in lines:
        for pattern, why in FORBIDDEN.items():
            if re.search(pattern, text, re.I):
                failures.append(
                    f"SundayPost.swift:{line_number}: \"{text[:56]}…\" — "
                    f"{why}"
                )

    print(f"checked {len(kinds)} chronicle kinds and {len(lines)} written "
          f"lines against {len(FORBIDDEN)} rules")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
