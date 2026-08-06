"""Check the Crossing — that merging two devices' worlds loses nothing.

A bad merge is the worst bug this app could ship. Everything else here fails
loudly: a scene composes wrong and you can see it, a track doesn't loop and you
can hear it, a sighting never fires and the journal stays empty. A merge that
drops a species eats a memory somebody made in March, silently, on a device
they weren't holding, with no undo and nothing on screen that looks wrong. So
it gets a checker before it gets a transport.

There are three parts, in order of how much they actually prove.

**1. The law.** `Crossing.swift` is four lines of `union` and `max` for exactly
one reason: *nothing decays*. Every persistent store in this app is monotonic,
so "which of these two values is later" never has to be answered — the answer
is always both. That law is what makes the merge correct, and it lives in ten
other files, not this one. So this part walks every store class in the app and
fails on any shrinking operation that isn't on a written allowlist. Add a
wilting plant in two years and the merge silently becomes wrong; this is what
notices.

**2. Coverage.** Every key in `StorageKeys.all` is either merged in
`Crossing.swift` or named in `NEEDS_NO_MERGE` below with a reason. Same shape
as `check_post.py`'s `silentKinds`, for the same reason: forgetting to merge a
store is invisible — it just quietly stays local forever.

**3. The properties.** A Python port of the arithmetic, run over generated
worlds, asserting the three things a merge has to be: commutative, idempotent,
growing. The port is the weak half — a port can drift from the Swift — so it is
pinned: each Swift merge body's shape is fingerprinted against a stored table,
and changing the arithmetic fails here until the port is changed to match.
That is the lesson `check_touch.py` cost: a checker that restates what it
checks has proved nothing.

    python3 tools/check_crossing.py

Exits non-zero if anything fails.
"""
import itertools
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
CROSSING = os.path.join(MODEL, "Crossing.swift")
KEYS = os.path.join(ROOT, "Pawmodoro", "LaunchOptions.swift")


# ---------------------------------------------------------------- part 1: law

# Every class in the app that owns a persisted store. If a new one appears and
# isn't listed, part 2 catches it through its storage key.
STORES = {
    "SessionLog": "SessionLog.swift",
    "Journal": "Journal.swift",
    "DreamDiary": "Dream.swift",
    "Album": "Postcard.swift",
    "Chronicle": "Chronicle.swift",
    "Pouch": "Pouch.swift",
    "Shelf": "Keepsake.swift",
    "Scrapbook": "Snapshot.swift",
    "Stray": "Stray.swift",
}

# Anything that can make a store smaller.
#
# `= []` and `= [:]` are in here because assigning an empty collection is how
# you'd wipe one without ever calling a remove — the shape a decaying feature
# would most plausibly take is a reset, not a `removeAll`.
SHRINKS = [
    (r"\.removeAll\b", "removeAll"),
    (r"\.removeFirst\b", "removeFirst"),
    (r"\.removeLast\b", "removeLast"),
    (r"\.removeValue\b", "removeValue"),
    (r"\.remove\(", "remove("),
    (r"\.popLast\b", "popLast"),
    (r"\.subtract", "subtract"),
    (r"\.intersection\b", "intersection"),
    (r"\.symmetricDifference\b", "symmetricDifference"),
    (r"removeObject\(forKey", "removeObject"),
    # Files count. The Scrapbook's photographs are the one part of anybody's
    # history that lives outside `UserDefaults`, and deleting one is the most
    # irreversible thing this app can do.
    (r"removeItem\(", "removeItem"),
    (r"=\s*\[\]", "= []"),
    (r"=\s*\[:\]", "= [:]"),
]

# The shrinking that is allowed, by (class, function, operation), each with the
# reason it is not a decay. Three reasons cover all of it, and a fourth would
# be a design conversation rather than a line added here.
#
#   cap    — a stored ceiling, evicting the oldest. Bounded storage, not decay:
#            the app has always done this and the merge copies the behaviour.
#   hand   — the user's own hand, on a surface that says so. Never automatic.
#   local  — a scratch collection inside a computed property, not a store.
ALLOWED = {
    ("SessionLog", "add", "removeFirst"): "cap",
    ("SessionLog", "clearHistory", "= []"): "hand",
    ("SessionLog", "clearHistory", "removeObject"): "hand",
    ("Journal", "clear", "= [:]"): "hand",
    ("DreamDiary", "clear", "= [:]"): "hand",
    ("Album", "add", "removeFirst"): "cap",
    ("Album", "clear", "= []"): "hand",
    ("Chronicle", "add", "removeFirst"): "cap",
    ("Chronicle", "clear", "= []"): "hand",
    ("Scrapbook", "add", "removeFirst"): "cap",
    ("Scrapbook", "remove", "removeAll"): "hand",
    ("Scrapbook", "clear", "= []"): "hand",
    # `prune` deletes files with no snapshot row pointing at them. It is the
    # only deletion here that isn't the user's hand, and it is allowed because
    # an orphan is unreachable storage rather than a memory: nothing in the app
    # can ever show it. If it ever deletes a file a row *does* point at, that
    # is a lost photograph and this line is wrong.
    ("Scrapbook", "prune", "removeItem"): "hand",
    ("Scrapbook", "removeFile", "removeItem"): "hand",
}

# Local scratch variables — a `var forgiven: [Date] = []` inside a computed
# property is not a store being emptied. Matched on the declaration keyword so
# that a store's `records = []` can never be mistaken for one.
LOCAL_DECL = re.compile(r"\b(var|let)\s+\w+\s*:\s*[^=]+=\s*\[:?\]")


# ----------------------------------------------------------- part 2: coverage

# Storage keys that are deliberately not merged, and why. Each one is a
# decision somebody made; the reason is the whole value of the table.
NEEDS_NO_MERGE = {
    "settings": "preferences, not history — the buddy, the theme, the phase "
                "lengths. Two devices genuinely may want different ones, and "
                "merging them would make changing a setting on the phone "
                "reach over and change the Mac.",
    "hasOnboarded": "a one-time flag about this install's first launch.",
    "hasPlus": "StoreKit owns this. Merging a purchase by hand would be both "
               "wrong and forgeable; the receipt is already account-wide.",
    "tipsGiven": "a private count behind the tip jar, shown nowhere and used "
                 "for nothing.",
    "longestDrift": "one number, and `max` of two is so obviously the answer "
                    "that a merge function would be longer than the fix. "
                    "Folded into the transport when there is one.",
    "postcards": "each card names a JPEG-less drawing the app regenerates, "
                 "but the *file* half of the scrapbook problem applies: "
                 "postcards are cheap to re-earn and their images are drawn "
                 "from the place and date they carry. Merged with the same "
                 "`ids` union when the transport lands; nothing new to test.",
    "snapshots": "photographs are files, and files need the transport this "
                 "phase deliberately doesn't have. The metadata merge is a "
                 "union by id like every other list here; it is left out "
                 "until there is something to move the JPEGs with, because a "
                 "row pointing at a file that isn't there is the one failure "
                 "`Scrapbook.prune()` cannot repair.",
    "strayFirstSeen": "a single date, and her whole arc counts back from it. "
                      "`min` of two, folded into the transport.",
    "strayJoined": "same — one date.",
}

# What each merged key is merged by, so a key can't be quietly pointed at the
# wrong function.
MERGED_BY = {
    "sessions": "sessions",
    "journal": "journal",
    "heard": "heard",
    "dreams": "ids",
    "chronicle": "chronicle",
    "owned": "ids",
    "keepsakes": "keepsakes",
}


# --------------------------------------------------------- part 3: properties

# The shape of each merge body, as a fingerprint.
#
# This is the pin between the Swift and the Python port below. It is the
# multiset of merge-shaped tokens the Swift body uses — the operations that
# decide whether the merge grows or shrinks. Change `+` to `max` in the journal
# merge and this table stops matching, which fails here and sends you to the
# port. It cannot notice a change that uses the same operators differently, so
# it is a tripwire rather than a proof; the properties below are what actually
# tests the behaviour.
FINGERPRINTS = {
    # `+` in three of these is `a + b`, concatenating the two devices' arrays
    # before de-duplicating. In `journal` its *absence* is the point: a `+`
    # appearing there means somebody has gone back to adding the counts, which
    # is the bug this whole file was rewritten for.
    "sessions": ["+", "removeFirst", "sorted"],
    "journal": ["max", "min"],
    "heard": ["merging", "min"],
    "ids": ["union"],
    "keepsakes": ["+", "max"],
    "chronicle": ["+", "removeFirst", "sorted"],
}

TOKENS = [
    (r"\.union\b", "union"),
    (r"\.merging\b", "merging"),
    (r"\bmax\(", "max"),
    (r"\bmin\(", "min"),
    (r"\.removeFirst\b", "removeFirst"),
    (r"\.sorted\b", "sorted"),
    (r"(?<![\w)\]])(?<!\+)\+(?!\+)", "+"),
]


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_comments(text):
    """Comments and string literals out, so prose can't match a rule.

    Written out rather than regexed away line by line: `//` inside a string is
    not a comment and a `+` inside one is not an operator.
    """
    out = []
    i = 0
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
        elif text[i] == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            out.append('""')
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def functions(text):
    """Every `func name(...)` in a file, with its body, by walking braces.

    The same walk `check_swift.py` settled on, and for the same reason: a regex
    that stops at the first `}` folds a nested closure's end into the function's
    end and reports whatever follows as part of it.
    """
    found = []
    for match in re.finditer(r"\bfunc\s+(\w+)\s*[(<]", text):
        name = match.group(1)
        start = text.find("{", match.end())
        if start < 0:
            continue
        depth = 0
        i = start
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        found.append((name, text[start:i + 1]))
    return found


def check_law():
    """Part 1 — no store shrinks except where somebody wrote down why."""
    failures = []
    used = set()
    checked = 0
    for cls, filename in sorted(STORES.items()):
        path = os.path.join(MODEL, filename)
        if not os.path.exists(path):
            failures.append(f"{filename} is gone but {cls} is still listed "
                            f"in check_crossing.py's STORES")
            continue
        source = strip_comments(read(path))
        # Only the class's own body — a file can hold the struct, the class and
        # a view helper, and the law is about the class.
        opening = re.search(r"\bfinal class %s\b[^{]*\{" % cls, source)
        if not opening:
            failures.append(f"{filename}: no `final class {cls}` — the store "
                            f"was renamed and this checker went blind")
            continue
        depth = 0
        i = opening.end() - 1
        while i < len(source):
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = source[opening.end() - 1:i + 1]

        for name, code in functions(body):
            checked += 1
            for line in code.splitlines():
                if LOCAL_DECL.search(line):
                    continue
                for pattern, label in SHRINKS:
                    if not re.search(pattern, line):
                        continue
                    key = (cls, name, label)
                    if key in ALLOWED:
                        used.add(key)
                    else:
                        failures.append(
                            f"{filename}: {cls}.{name}() shrinks a store "
                            f"({label}) — nothing in this app decays. If it "
                            f"genuinely must, add it to ALLOWED in "
                            f"check_crossing.py with the reason, and then go "
                            f"and fix Crossing.swift, because the merge "
                            f"assumes this is impossible"
                        )
    for key in sorted(set(ALLOWED) - used):
        failures.append(f"ALLOWED has a stale exception for "
                        f"{key[0]}.{key[1]}() ({key[2]}) — it no longer "
                        f"shrinks anything")
    return failures, checked


def check_coverage(merges):
    """Part 2 — every storage key is merged or excused."""
    failures = []
    source = strip_comments(read(KEYS))
    block = re.search(r"enum StorageKeys\s*\{(.*?)\n\}", source, re.S)
    if not block:
        return ["LaunchOptions.swift: StorageKeys not found"], set()
    keys = set(re.findall(r"static let (\w+)\s*=", block.group(1)))
    keys.discard("all")

    for key in sorted(keys):
        merged = MERGED_BY.get(key)
        excused = key in NEEDS_NO_MERGE
        if merged and excused:
            failures.append(f"StorageKeys.{key} is both merged and in "
                            f"NEEDS_NO_MERGE — one of the two is stale")
        elif not merged and not excused:
            failures.append(
                f"StorageKeys.{key} is neither merged in Crossing.swift nor "
                f"named in NEEDS_NO_MERGE. Decide which: a store that is "
                f"quietly never merged stays on one device forever and "
                f"nothing on screen ever looks wrong"
            )
        elif merged and merged not in merges:
            failures.append(f"StorageKeys.{key} claims to be merged by "
                            f"Crossing.merge({merged}:) which does not exist")
    for key in sorted(set(MERGED_BY) | set(NEEDS_NO_MERGE)):
        if key not in keys:
            failures.append(f"check_crossing.py refers to StorageKeys.{key}, "
                            f"which no longer exists")
    return failures, keys


def merge_bodies():
    """Every `Crossing.merge(label:...)` body, by its first argument label."""
    source = strip_comments(read(CROSSING))
    bodies = {}
    for match in re.finditer(r"\bstatic func merge\(\s*(\w+)\s+", source):
        label = match.group(1)
        start = source.find("{", match.end())
        depth = 0
        i = start
        while i < len(source):
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        bodies[label] = source[start:i + 1]
    return bodies


def check_fingerprints(bodies):
    """Part 3a — the Swift's arithmetic still has the shape the port assumes."""
    failures = []
    for label, expected in sorted(FINGERPRINTS.items()):
        body = bodies.get(label)
        if body is None:
            failures.append(f"Crossing.merge({label}:) is gone — the port "
                            f"below still implements it")
            continue
        seen = sorted({name for pattern, name in TOKENS
                       if re.search(pattern, body)})
        if seen != sorted(expected):
            failures.append(
                f"Crossing.merge({label}:) changed shape: expected "
                f"{sorted(expected)}, found {seen}. The Python port in this "
                f"file no longer describes it — change the port, re-derive "
                f"this row, and only then believe the properties below"
            )
    for label in sorted(set(bodies) - set(FINGERPRINTS)):
        failures.append(f"Crossing.merge({label}:) is new and untested — add "
                        f"a port and a fingerprint row")
    return failures


# The port. One function per Swift merge, deliberately written to read like it.
def merge_sessions(a, b, limit):
    by_id = {}
    for record in a + b:
        seen = by_id.get(record["id"])
        if seen is not None and prefer(seen, record):
            continue
        by_id[record["id"]] = record
    merged = sorted(by_id.values(), key=session_order)
    return merged[len(merged) - limit:] if len(merged) > limit else merged


def session_order(record):
    return (record["endedAt"], record["minutes"], record["id"])


def prefer(x, y):
    if x["minutes"] != y["minutes"]:
        return x["minutes"] > y["minutes"]
    return x["endedAt"] <= y["endedAt"]


def merge_journal(a, b):
    merged = dict(a)
    for species, incoming in b.items():
        existing = merged.get(species)
        if existing is None:
            merged[species] = incoming
            continue
        if existing["firstSeen"] != incoming["firstSeen"]:
            earlier = existing if existing["firstSeen"] < incoming["firstSeen"] \
                else incoming
        else:
            earlier = existing if story(existing) <= story(incoming) \
                else incoming
        merged[species] = {
            "firstSeen": min(existing["firstSeen"], incoming["firstSeen"]),
            "lastSeen": max(existing["lastSeen"], incoming["lastSeen"]),
            "count": max(existing["count"], incoming["count"]),
            "place": earlier["place"],
            "dayPart": earlier["dayPart"],
            "weather": earlier["weather"],
        }
    return merged


def story(record):
    return "%s|%s|%s" % (record["place"], record["dayPart"],
                         record["weather"] or "")


def merge_heard(a, b):
    merged = dict(a)
    for key, date in b.items():
        merged[key] = min(merged[key], date) if key in merged else date
    return merged


def merge_ids(a, b):
    return set(a) | set(b)


KEEPSAKE_ORDER = ["leaf", "feather", "pebble", "ribbon", "bottlecap", "stick"]


def merge_keepsakes(a, b):
    counts = {}
    for kind in set(a) | set(b):
        counts[kind] = max(a.count(kind), b.count(kind))
    return [kind for kind in KEEPSAKE_ORDER
            for _ in range(counts.get(kind, 0))]


def merge_chronicle(a, b, limit):
    by_id = {}
    for event in a + b:
        seen = by_id.get(event["id"])
        if seen is not None and event_order(seen) < event_order(event):
            continue
        by_id[event["id"]] = event
    merged = sorted(by_id.values(), key=event_order)
    return merged[len(merged) - limit:] if len(merged) > limit else merged


def event_order(event):
    return (event["at"], event["kind"], event["subject"], event["id"])


def check_keepsake_order():
    """The port's rebuild order is `Keepsake.allCases`, read from the Swift."""
    source = strip_comments(read(os.path.join(MODEL, "Keepsake.swift")))
    block = re.search(r"enum Keepsake[^{]*\{(.*?)\n\}", source, re.S)
    if not block:
        return ["Keepsake.swift: enum Keepsake not found"]
    cases = re.findall(r"^\s*case (\w+)\s*$", block.group(1), re.M)
    if cases != KEEPSAKE_ORDER:
        return [f"Keepsake.allCases is {cases}, the port rebuilds shelves in "
                f"{KEEPSAKE_ORDER} — two devices would show the same shelf in "
                f"different orders"]
    return []


# --------------------------------------------------------- generating a world

def world(rng, size=14):
    """A plausible device's worth of state.

    Two details in here are load-bearing. Ids are drawn from a **shared pool**,
    so two generated worlds overlap the way two real devices do — a merge over
    disjoint worlds is a concatenation and tests nothing. And they are drawn
    **without replacement within one world**, because a device cannot hold the
    same session twice; a world that did would fail idempotence for a reason
    that is about the generator rather than about the merge.
    """
    ids = [f"{n:08x}" for n in range(60)]
    events = [f"e{n:08x}" for n in range(60)]
    species = ["heron", "stag", "fox", "owl", "hare", "kite"]
    return {
        "sessions": sorted(
            ({"id": one, "endedAt": rng.randrange(0, 400),
              "minutes": rng.choice([15, 25, 50])}
             for one in rng.sample(ids, rng.randrange(0, size))),
            key=session_order,
        ),
        "journal": {
            name: {
                "firstSeen": (first := rng.randrange(0, 400)),
                "lastSeen": first + rng.randrange(0, 200),
                "count": rng.randrange(1, 9),
                "place": rng.choice(["woods", "harbor", "onsen"]),
                "dayPart": rng.choice(["dawn", "day", "dusk", "night"]),
                "weather": rng.choice(["clear", "mist", None]),
            }
            for name in rng.sample(species, rng.randrange(0, len(species)))
        },
        "heard": {
            name: rng.randrange(0, 400)
            for name in rng.sample(species, rng.randrange(0, len(species)))
        },
        "ids": {f"id{rng.randrange(0, 20)}" for _ in range(rng.randrange(0, 9))},
        "keepsakes": [rng.choice(KEEPSAKE_ORDER)
                      for _ in range(rng.randrange(0, 7))],
        # Sorted, like the sessions and for the same reason: both stores are
        # appended to in time order on a real device, so a world holding them
        # shuffled is a world that cannot exist. The merge re-sorts, which made
        # every shuffled world look like an idempotence failure on the first
        # run of this checker — a fault in the generator reported as a fault in
        # the code under test, which is the most expensive kind.
        "chronicle": sorted(
            ({"id": one, "at": rng.randrange(0, 400),
              "kind": rng.choice(["sighting", "dream", "trade"]),
              "subject": rng.choice(["heron", "fox", "igloo"])}
             for one in rng.sample(events, rng.randrange(0, size))),
            key=event_order,
        ),
    }


def merge_worlds(a, b, limit=1000):
    return {
        "sessions": merge_sessions(a["sessions"], b["sessions"], limit),
        "journal": merge_journal(a["journal"], b["journal"]),
        "heard": merge_heard(a["heard"], b["heard"]),
        "ids": merge_ids(a["ids"], b["ids"]),
        "keepsakes": merge_keepsakes(a["keepsakes"], b["keepsakes"]),
        "chronicle": merge_chronicle(a["chronicle"], b["chronicle"], limit),
    }


def canonical(state):
    """A comparable form — *contents*, not arrangement.

    Dictionaries and sets have no order and two devices that disagree only
    about enumeration order have not disagreed. The shelf is sorted here for a
    sharper reason: the merge deliberately **normalises** it into
    `Keepsake.allCases` order, so a local shelf in arrival order is reordered
    by its own first merge. That is not a loss and comparing it as a list would
    report it as one — which it did, on the first run of this checker. Shelf
    *order* is asserted separately, by `check_shelf_order`, which is where it
    belongs.
    """
    return (
        [tuple(sorted(r.items())) for r in state["sessions"]],
        sorted((k, tuple(sorted(v.items(), key=str)))
               for k, v in state["journal"].items()),
        sorted(state["heard"].items()),
        sorted(state["ids"]),
        sorted(state["keepsakes"]),
        [tuple(sorted(e.items())) for e in state["chronicle"]],
    )


def check_shelf_order(rng, rounds=60):
    """A merged shelf is in `Keepsake.allCases` order on both devices.

    Arrival order is the one thing two devices genuinely cannot agree about —
    they saw the same six keepsakes in different weeks — so the merge picks an
    order neither of them had. Worth an assertion of its own: if it stopped
    normalising, the shelves would still contain the same objects and would
    still pass every property above, while reading differently on each device.
    """
    rank = {kind: index for index, kind in enumerate(KEEPSAKE_ORDER)}
    for _ in range(rounds):
        merged = merge_keepsakes(world(rng)["keepsakes"],
                                 world(rng)["keepsakes"])
        ranks = [rank[kind] for kind in merged]
        if ranks != sorted(ranks):
            return [f"a merged shelf came out in {merged}, which is not "
                    f"Keepsake.allCases order — two devices would show the "
                    f"same shelf arranged differently"]
    return []


def grew(result, side):
    """Nothing in `result` is smaller than in `side`. This is *nothing decays*
    written as something a test can check."""
    problems = []
    if len(result["sessions"]) < len(side["sessions"]):
        problems.append("sessions")
    for name, record in side["journal"].items():
        got = result["journal"].get(name)
        if got is None:
            problems.append(f"journal lost {name}")
        elif (got["count"] < record["count"]
              or got["firstSeen"] > record["firstSeen"]
              or got["lastSeen"] < record["lastSeen"]):
            problems.append(f"journal shrank {name}")
    for name, date in side["heard"].items():
        if name not in result["heard"] or result["heard"][name] > date:
            problems.append(f"heard lost {name}")
    if not side["ids"] <= result["ids"]:
        problems.append("owned ids lost")
    for kind in set(side["keepsakes"]):
        if result["keepsakes"].count(kind) < side["keepsakes"].count(kind):
            problems.append(f"shelf lost a {kind}")
    if len(result["chronicle"]) < len(side["chronicle"]):
        problems.append("chronicle")
    return problems


def check_properties(rounds=400):
    """Part 3b — commutative, idempotent, growing, and associative enough."""
    failures = []
    rng = random.Random(20260806)
    for round_number in range(rounds):
        a = world(rng)
        b = world(rng)
        ab = merge_worlds(a, b)
        ba = merge_worlds(b, a)

        if canonical(ab) != canonical(ba):
            failures.append(f"round {round_number}: not commutative — which "
                            f"device syncs first changed the result")
            break
        if canonical(merge_worlds(a, a)) != canonical(a):
            failures.append(f"round {round_number}: not idempotent — syncing "
                            f"the same world twice changed it, so a retry "
                            f"after a dropped connection is not safe")
            break
        if canonical(merge_worlds(ab, ab)) != canonical(ab):
            failures.append(f"round {round_number}: not idempotent on an "
                            f"already-merged world")
            break
        for label, side in (("a", a), ("b", b)):
            lost = grew(ab, side)
            if lost:
                failures.append(f"round {round_number}: merging lost "
                                f"something that was on {label}: "
                                f"{', '.join(lost[:3])}")
                break
        if failures:
            break
        # Re-merging the result with either input must be a no-op: this is what
        # a device that syncs, then syncs again before the other one has moved,
        # actually does. It is the property a naive `count += count` fails.
        if canonical(merge_worlds(ab, a)) != canonical(ab):
            failures.append(f"round {round_number}: re-merging the result "
                            f"with one of its own inputs changed it — a "
                            f"second sync would double-count")
            break
    return failures


def check_cap():
    """The cap evicts the *oldest*, like `SessionLog.add` does, and the limit
    is read from the Swift rather than typed here."""
    failures = []
    source = strip_comments(read(os.path.join(MODEL, "SessionLog.swift")))
    match = re.search(r"maxRecords\s*=\s*(\d+)", source)
    if not match:
        failures.append("SessionLog.maxRecords not found")
        return failures
    limit = int(match.group(1))
    a = [{"id": f"a{n}", "endedAt": n, "minutes": 25} for n in range(limit)]
    b = [{"id": f"b{n}", "endedAt": n + limit, "minutes": 25}
         for n in range(limit)]
    merged = merge_sessions(a, b, limit)
    if len(merged) != limit:
        failures.append(f"merging two full logs gave {len(merged)} records, "
                        f"cap is {limit}")
    if merged and merged[0]["endedAt"] < limit:
        failures.append("the cap dropped the newest sessions, not the oldest")
    return failures


def main():
    failures = []

    law, functions_checked = check_law()
    failures += law

    bodies = merge_bodies()
    coverage, keys = check_coverage(bodies)
    failures += coverage
    failures += check_fingerprints(bodies)
    failures += check_keepsake_order()
    failures += check_properties()
    failures += check_shelf_order(random.Random(11))
    failures += check_cap()

    print(f"checked {functions_checked} functions across {len(STORES)} stores, "
          f"{len(keys)} storage keys, {len(bodies)} merges, "
          f"400 pairs of worlds")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
