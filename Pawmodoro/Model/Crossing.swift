import Foundation

/// Merging two of these worlds.
///
/// The law, in one sentence: **the merge of two worlds is the world where
/// everything happened.**
///
/// That is not a design decision made here — it is a consequence of one made
/// three eras ago and kept ever since. *Nothing decays.* Every store in this
/// app is monotonic: the session log only gains records, the journal's counts
/// only rise, the dream diary and the heard list only grow, the pouch only
/// gains ids, the shelf only gains keepsakes. A store that could go *down*
/// would make merging genuinely hard — you would have to know which of two
/// disagreeing values was later, and be wrong sometimes. Because nothing goes
/// down, "later" never has to be decided: the answer is always *both*.
///
/// So this file is short, and it is short on purpose. If it ever starts
/// growing conflict-resolution rules, something has stopped being monotonic
/// and that is the bug — not this.
///
/// ### What is deliberately not here
///
/// **The transport.** No CloudKit, no `NSUbiquitousKeyValueStore`, no network
/// of any kind. This is the arithmetic only, and it is written and tested
/// first because it is the half that can be got wrong silently: a bad merge
/// eats somebody's history and there is no undo. `tools/check_crossing.py`
/// runs it against generated worlds and asserts the properties below. The
/// transport is a Mac-and-account sitting and ships behind a Settings toggle,
/// off by default, like every migration this app has survived.
///
/// ### The three properties a merge has to have
///
/// - **Commutative.** `merge(a, b) == merge(b, a)`. Which device syncs first
///   cannot change the result.
/// - **Idempotent.** `merge(a, a) == a`. Syncing twice does nothing the
///   second time, which is what makes a retry safe.
/// - **Growing.** Nothing in the result is smaller than in either input. This
///   is *nothing decays*, restated as an invariant a test can check.
enum Crossing {

    // MARK: The session log

    /// Union by record identity.
    ///
    /// `SessionRecord` carries a `UUID`, so the same session written on two
    /// devices is one record and two different sessions that happened to end
    /// in the same second are two. Sorted by date afterwards so the merged log
    /// reads like a history rather than like two histories stapled together.
    ///
    /// The cap is applied last and from the *front*, exactly as `SessionLog`
    /// does it — merging two nearly-full logs can exceed it, and dropping the
    /// oldest is the behaviour the app already has.
    ///
    /// Two records sharing an id but differing in content cannot happen — a
    /// session is written once and never edited — but "cannot happen" is not
    /// the same as "the code does something sensible if it does". The
    /// tie-break below picks the longer session, then the earlier one, which
    /// is a decision that does not depend on which argument came first. The
    /// alternative, last-writer-wins, would make the merge *not commutative*
    /// on exactly the input a test would think to try.
    static func merge(sessions a: [SessionRecord], _ b: [SessionRecord],
                      limit: Int) -> [SessionRecord] {
        var byID: [UUID: SessionRecord] = [:]
        for record in a + b {
            if let seen = byID[record.id], prefer(seen, over: record) { continue }
            byID[record.id] = record
        }
        var merged = byID.values.sorted(by: inOrder)
        if merged.count > limit {
            merged.removeFirst(merged.count - limit)
        }
        return merged
    }

    /// A total order on sessions, so that a merged log is in the same order on
    /// both devices rather than in whatever order a dictionary happened to
    /// enumerate. `Dictionary.values` has no order at all, and two devices
    /// running the same build do not agree about it.
    private static func inOrder(_ x: SessionRecord, _ y: SessionRecord) -> Bool {
        if x.endedAt != y.endedAt { return x.endedAt < y.endedAt }
        if x.minutes != y.minutes { return x.minutes < y.minutes }
        return x.id.uuidString < y.id.uuidString
    }

    private static func prefer(_ x: SessionRecord, over y: SessionRecord) -> Bool {
        if x.minutes != y.minutes { return x.minutes > y.minutes }
        return x.endedAt <= y.endedAt
    }

    // MARK: The journal

    /// Per species: the count is the larger, the first-seen is the earlier,
    /// the last-seen is the later.
    ///
    /// The count taking the **maximum** rather than the sum is the one
    /// judgement call in this file, and it was made the other way round first.
    /// Adding reads as obviously right — two devices used on different days
    /// have genuinely seen the heron that many times between them, and taking
    /// the max quietly drops the overlap. But adding is **not idempotent**:
    /// merge the same two worlds twice, which is exactly what a sync that
    /// retries after a dropped connection does, and every count in the journal
    /// doubles. `tools/check_crossing.py` failed on the first run for this and
    /// nothing else.
    ///
    /// So the choice is between a bounded undercount and an unbounded
    /// overcount, and it is not close. Max never shows a number lower than the
    /// one that device last showed — which is *nothing decays*, held exactly —
    /// and it never invents a sighting. Adding lies upward, compounds every
    /// time the network hiccups, and there is no repair once it has.
    ///
    /// The genuinely correct answer is a per-device counter — keep a count per
    /// install, merge by taking the max of each, and sum for display. That is
    /// a change to `SightingRecord`'s stored shape and a new per-install id,
    /// and it belongs to the phase that builds the transport, where it can
    /// actually be exercised. **If you are that person: this is the note.**
    ///
    /// The place, hour and weather of the first meeting come from whichever
    /// record has the earlier `firstSeen`, so the memory stays coherent: it
    /// was one afternoon, and it keeps all of that afternoon's facts.
    static func merge(journal a: [String: SightingRecord],
                      _ b: [String: SightingRecord]) -> [String: SightingRecord] {
        var merged = a
        for (species, incoming) in b {
            guard let existing = merged[species] else {
                merged[species] = incoming
                continue
            }
            // Whichever met it first keeps the story of the meeting — and
            // when both met it in the same second, the story that sorts first
            // does. That tie-break looks like pedantry and is not: two devices
            // that saw a species for the first time at the same instant and
            // in different places would otherwise keep whichever record the
            // merge happened to be handed first, so the phone and the Mac
            // would each remember a different afternoon. Arbitrary is fine
            // here; disagreeing is not.
            let earlier: SightingRecord
            if existing.firstSeen != incoming.firstSeen {
                earlier = existing.firstSeen < incoming.firstSeen
                    ? existing : incoming
            } else {
                earlier = story(of: existing) <= story(of: incoming)
                    ? existing : incoming
            }
            merged[species] = SightingRecord(
                firstSeen: min(existing.firstSeen, incoming.firstSeen),
                lastSeen: max(existing.lastSeen, incoming.lastSeen),
                count: max(existing.count, incoming.count),
                place: earlier.place,
                dayPart: earlier.dayPart,
                weather: earlier.weather
            )
        }
        return merged
    }

    /// The facts of a first meeting, as one comparable string. Only ever used
    /// to break a tie — never shown, never stored.
    private static func story(of record: SightingRecord) -> String {
        "\(record.place)|\(record.dayPart)|\(record.weather ?? "")"
    }

    /// Things heard: union, keeping the earlier date for anything on both.
    ///
    /// Five other stores turned out to be this exact shape — an id, and the
    /// first date that thing happened — so they use this rather than five more
    /// copies of one line. The clock ring (two devices each sitting through a
    /// different small hour end up having sat through both), the species known
    /// only from their night visits to the sill, the ones seen once in the
    /// pale coat, the timetabled events you personally caught happening, and
    /// the weekend setlist's stamps.
    ///
    /// `min` is right for every one of them because every one of them is a
    /// *first*: the earliest claim is the true one, and a device that has
    /// never seen the thing at all has no claim to make. A later date winning
    /// anywhere here would move somebody's first meeting forward, which is the
    /// only way a store of firsts can lie.
    static func merge(heard a: [String: Date], _ b: [String: Date]) -> [String: Date] {
        a.merging(b) { min($0, $1) }
    }

    // MARK: Tiers, and anything else counted per key

    /// A per-key monotonic counter: the larger of the two, key by key.
    ///
    /// The trick repertoire is what needs it today. A tier rises overnight
    /// from a day's practice and never falls, so two devices that each taught
    /// the buddy something end up with a buddy that knows both — and a trick
    /// mastered on the phone can never read as unlearned on the Mac, which is
    /// what *nothing decays* means once there are two screens.
    ///
    /// `max` rather than a sum, for the reason `merge(journal:)` sets out at
    /// length: a sum is not idempotent, and a sync that retried after a
    /// dropped connection would level every trick twice.
    ///
    /// The transport projects the store into this shape and back, the way it
    /// does for the clock ring. `Skill`'s other two fields deliberately do not
    /// travel: `practicedOn` is the day *this* device practiced, which its own
    /// overnight rise consumes, and `grew` is a one-shot flag owed to the next
    /// caption on the device that earned it. Carrying either would either
    /// spend a night's practice twice or announce a growth nobody saw.
    static func merge(tiers a: [String: Int], _ b: [String: Int]) -> [String: Int] {
        a.merging(b) { max($0, $1) }
    }

    // MARK: Everything that is just a set

    /// The pouch, the shelf's marks, the dream diary's keys.
    ///
    /// A purchase is never lost — that is fence 2 of the Hearth era, and here
    /// it is one line: the union of two sets of owned ids contains every id
    /// either device ever had. Somebody who bought the fox on their phone
    /// finds it on the Mac, and nothing anywhere can take it back.
    ///
    /// Three later stores are the same one line, and the reason is worth
    /// separating from the reason above — those are things *bought*, these are
    /// things *done*, and a set union is right for both because neither can be
    /// undone:
    ///
    /// - the anniversaries already surfaced, so the Mac cannot open with a
    ///   thought the phone already had. This is the one place the union is
    ///   load-bearing rather than merely tidy: an un-merged `surfaced` means
    ///   the same six-months-since-you-met-the-heron arrives twice, and a
    ///   memory that repeats stops being one.
    /// - the pantry's tastes, one union per buddy — who has tried what,
    ///   which is the whole of the Tastes card. The sill and the day's
    ///   appetite beside them do *not* travel: a snack sitting on one
    ///   device's windowsill is furniture in that room, and `fedCount` is
    ///   today's, spent by tonight.
    /// - the anthology's quoted set, which rides alongside `merge(poems:)`
    ///   below for the same reason `surfaced` rides here — a line quoted back
    ///   on one device must not be offered as fresh on the other.
    static func merge(ids a: Set<String>, _ b: Set<String>) -> Set<String> {
        a.union(b)
    }

    /// Keepsakes, which are a *list* rather than a set — two pebbles is two
    /// pebbles. Merged by taking the longer run of each kind, so syncing twice
    /// cannot duplicate a shelf while genuinely different shelves still add up.
    static func merge(keepsakes a: [String], _ b: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for kind in Set(a + b) {
            counts[kind] = max(a.filter { $0 == kind }.count,
                               b.filter { $0 == kind }.count)
        }
        // Rebuilt in the fixed order `Keepsake.allCases` uses, so the shelf
        // reads the same on both devices rather than in arrival order, which
        // the two devices do not agree about.
        return Keepsake.allCases.flatMap { keepsake in
            Array(repeating: keepsake.rawValue, count: counts[keepsake.rawValue] ?? 0)
        }
    }

    // MARK: The chronicle

    /// Union by event id, re-sorted, re-capped.
    ///
    /// Events carry a `UUID` for the same reason sessions do, so the same
    /// sighting recorded once is one event however many times it syncs. The
    /// same-id-different-content note on the session merge applies here too,
    /// and is resolved the same way: by a rule, not by argument order.
    static func merge(chronicle a: [ChronicleEvent], _ b: [ChronicleEvent],
                      limit: Int) -> [ChronicleEvent] {
        var byID: [UUID: ChronicleEvent] = [:]
        for event in a + b {
            if let seen = byID[event.id], inOrder(seen, event) { continue }
            byID[event.id] = event
        }
        var merged = byID.values.sorted(by: inOrder)
        if merged.count > limit {
            merged.removeFirst(merged.count - limit)
        }
        return merged
    }

    /// A total order on events, for the reason `inOrder(_:_:)` above exists.
    private static func inOrder(_ x: ChronicleEvent, _ y: ChronicleEvent) -> Bool {
        if x.at != y.at { return x.at < y.at }
        if x.kind != y.kind { return x.kind.rawValue < y.kind.rawValue }
        if x.subject != y.subject { return x.subject < y.subject }
        return x.id.uuidString < y.id.uuidString
    }

    // MARK: The lists of things that happened once
    //
    // Three stores are the same shape and get the same short body each: the
    // drawer of trinkets carried home, the shelf of photographs, and the poems
    // somebody sat on a bench and chose a line at a time. Every record in all
    // three is minted with a fresh `UUID` at the moment it is written and
    // never edited afterwards, so the merge is a union by that id, sorted into
    // one order both devices agree on, and there is nothing to resolve.
    //
    // Where two copies of an id somehow do meet, the earlier date wins. That
    // is the whole tie-break, and unlike the session log's it does not need a
    // second tier: with the same id *and* the same date there is no third
    // field that could differ, because nothing in the app ever rewrites one of
    // these records. (`PhotoAlbum.developNowForDebug` does, and it is a debug
    // flag re-dating today's photo — which the earlier-date rule resolves.)
    //
    // These are three bodies rather than one generic function on purpose.
    // `tools/check_crossing.py` fingerprints each merge by the operators its
    // body uses; a generic has one body serving three stores, so all three
    // would share a single tripwire and a change made for the drawer would
    // silently redefine the poems. Three bodies, three fingerprints, one
    // Python port — the port is shared because the arithmetic genuinely is.

    /// Everything the buddy ever carried home, with its provenance.
    ///
    /// Uncapped, because the store is: one trinket on the days you were away
    /// long enough is a few hundred kilobytes in a decade, and the drawer is
    /// the era's one collection surface — a grid with holes in it on the Mac
    /// would read as things having been lost, which is exactly the thing this
    /// app promises cannot happen.
    static func merge(drawer a: [KeepsakeRecord],
                      _ b: [KeepsakeRecord]) -> [KeepsakeRecord] {
        var byID: [UUID: KeepsakeRecord] = [:]
        for record in a + b {
            if let seen = byID[record.id], seen.date <= record.date { continue }
            byID[record.id] = record
        }
        return byID.values.sorted { left, right in
            if left.date != right.date { return left.date < right.date }
            return left.id.uuidString < right.id.uuidString
        }
    }

    /// The photographs — the parameter records, which is all a photograph is
    /// here. Nothing on disk, so this is not the deferred problem `snapshots`
    /// has: a `PhotoRecord` is two hundred bytes of what was true, and the
    /// same views redraw it anywhere.
    ///
    /// Capped from the front like the album itself, because merging two full
    /// shelves can exceed the ceiling and the oldest are the ones that go.
    static func merge(photos a: [PhotoRecord], _ b: [PhotoRecord],
                      limit: Int) -> [PhotoRecord] {
        var byID: [UUID: PhotoRecord] = [:]
        for record in a + b {
            if let seen = byID[record.id], seen.date <= record.date { continue }
            byID[record.id] = record
        }
        var merged = byID.values.sorted { left, right in
            if left.date != right.date { return left.date < right.date }
            return left.id.uuidString < right.id.uuidString
        }
        if merged.count > limit {
            merged.removeFirst(merged.count - limit)
        }
        return merged
    }

    /// The anthology. The one store in this file whose contents somebody
    /// *wrote*: three lines picked out of nine, on a particular bench, on a
    /// particular evening. Everything else here can be earned again by using
    /// the app; a poem cannot, and there is nowhere else it exists.
    ///
    /// The quoted set travels beside it through `merge(ids:)`, so a middle
    /// line already read back on one device is not offered again as new on
    /// the other.
    static func merge(poems a: [Haiku], _ b: [Haiku], limit: Int) -> [Haiku] {
        var byID: [UUID: Haiku] = [:]
        for poem in a + b {
            if let seen = byID[poem.id], seen.date <= poem.date { continue }
            byID[poem.id] = poem
        }
        var merged = byID.values.sorted { left, right in
            if left.date != right.date { return left.date < right.date }
            return left.id.uuidString < right.id.uuidString
        }
        if merged.count > limit {
            merged.removeFirst(merged.count - limit)
        }
        return merged
    }

    // MARK: The acorns, which need nothing

    /// There is no acorn merge and there must never be one.
    ///
    /// The balance is derived — lifetime minutes over the earn rate, minus the
    /// price of what is owned — so merging the *log* and the *pouch* merges
    /// the balance for free and exactly. A stored balance would need a
    /// conflict rule, and every possible rule is wrong: take the max and
    /// somebody spends the same acorn twice, take the min and somebody loses
    /// an afternoon. This is the clearest payoff of `Acorns` being derived and
    /// it is worth the note.
    static let acornsNeedNoMerge = true
}
