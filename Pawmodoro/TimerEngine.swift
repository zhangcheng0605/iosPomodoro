import Foundation
import Observation
import UIKit

/// The Pomodoro state machine.
///
/// Remaining time is always derived from an absolute end `Date`, never from
/// accumulated ticks: iOS suspends backgrounded apps, so a tick-based countdown
/// drifts or stalls entirely. `syncAfterWake()` recomputes on foreground and
/// finishes the phase if it elapsed while the app was away.
@Observable
final class TimerEngine {

    enum Phase: String, Codable, CaseIterable {
        case focus
        case shortBreak
        case longBreak

        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }

        var isBreak: Bool {
            switch self {
            case .focus: false
            case .shortBreak, .longBreak: true
            }
        }
    }

    enum RunState {
        case idle      // nothing started, or a phase just finished
        case running
        case paused
    }

    var settings: PomodoroSettings
    private(set) var phase: Phase = .focus
    private(set) var runState: RunState = .idle
    private(set) var remaining: TimeInterval
    /// Focus sessions finished inside the current cycle, reset after a long break.
    private(set) var focusInCycle: Int = 0

    /// Set when a phase runs out on its own, and left set until something
    /// clears it. The engine stays free of any UI: views watch this and put on
    /// whatever celebration they like.
    var completion: PhaseCompletion?

    /// The wildlife appearance scheduled for this focus phase, if the roll went
    /// that way. Cleared whenever the phase stops for any reason.
    private(set) var sighting: Sighting?

    /// Whether the last second of this break slips the pounce — the rare
    /// variant, decided at break start like any other roll.
    private(set) var pounceEscape = false

    /// A gentle thumb on the sighting scales. One seam, several clients:
    /// the fortune slip presses it for a day, a returned traveler for one
    /// session, a blooming flower for as long as it blooms. Never displayed,
    /// never stacked into certainty — the ordinary queue always runs after.
    struct SightingBias: Equatable {
        /// Who is pressing — one bias per source, replaced on re-press.
        let source: String
        let species: Species
        /// Where it applies, or nil for anywhere.
        let place: Place?
        /// Multiplier on the species' own chance, capped well below sure.
        let weight: Double
        /// Whether firing spends it (a traveler's tip) or it stands (a
        /// fortune's whole day).
        let oneShot: Bool
    }

    private(set) var biases: [SightingBias] = []

    func setBias(_ bias: SightingBias) {
        biases.removeAll { $0.source == bias.source }
        biases.append(bias)
    }

    func clearBias(source: String) {
        biases.removeAll { $0.source == source }
    }

    /// The day's slips, drawn and archived.
    let fortunes: FortuneTeller
    /// The freshly drawn slip, for the caption to read out once.
    private(set) var drawnSlip: Fortune?
    /// Who is away, and every letter that ever came home.
    let travels: Travels
    /// The newest homecoming, for the caption to announce once.
    private(set) var arrivedLetter: Letter?
    /// The window-box, seeded by dreams and watered by showing up.
    let garden: Garden

    /// Whether Soot is doing her rounds this phase.
    ///
    /// Her one quirk, and the only one that shows while somebody else is the
    /// buddy: a cat who spent a fortnight deciding to come in doesn't stop
    /// being a cat afterwards. Rolled once per phase for the same reason a
    /// sighting is — a per-frame decision would have her flicker.
    private(set) var strayCameo = false

    /// What the buddy is dreaming this focus phase, if the roll went that way.
    /// A session gets a dream *or* a sighting, never both competing for the
    /// same quiet middle stretch.
    private(set) var dream: Dream?

    let log: SessionLog
    let journal: Journal
    let album: Album
    let stray: Stray
    let dreams: DreamDiary
    let pantry: Pantry
    let fives: FiveCounter
    let tuckIn: TuckIn
    let doorstep: Doorstep
    let drawer: KeepsakeDrawer
    let repertoire: Repertoire
    let memories: Anniversaries

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?
    /// Which whole second the closing heartbeat last fired on.
    @ObservationIgnored private var lastHeartbeatSecond: Int?
    /// Seconds of this phase spent with rain playing — the rainbow's condition.
    @ObservationIgnored private var rainSeconds: TimeInterval = 0

    init(
        settings: PomodoroSettings? = nil,
        log: SessionLog = SessionLog(),
        journal: Journal = Journal(),
        album: Album = Album(),
        stray: Stray = Stray(),
        dreams: DreamDiary = DreamDiary(),
        pantry: Pantry = Pantry(),
        fives: FiveCounter = FiveCounter(),
        tuckIn: TuckIn = TuckIn(),
        doorstep: Doorstep = Doorstep(),
        drawer: KeepsakeDrawer = KeepsakeDrawer(),
        repertoire: Repertoire = Repertoire(),
        memories: Anniversaries = Anniversaries(),
        fortunes: FortuneTeller = FortuneTeller(),
        travels: Travels = Travels(),
        garden: Garden = Garden()
    ) {
        let resolved = settings ?? PomodoroSettings.load()
        self.settings = resolved
        self.log = log
        self.journal = journal
        self.album = album
        self.stray = stray
        self.dreams = dreams
        self.pantry = pantry
        self.fives = fives
        self.tuckIn = tuckIn
        self.doorstep = doorstep
        self.drawer = drawer
        self.repertoire = repertoire
        self.memories = memories
        self.fortunes = fortunes
        self.travels = travels
        self.garden = garden
        self.remaining = resolved.duration(for: .focus)
        ThemeManager.shared.theme = resolved.theme
        HapticsDirector.shared.isEnabled = resolved.hapticsEnabled
        if let forced = LaunchOptions.forcedPlace {
            self.settings.place = forced
        }
        if let forced = LaunchOptions.forcedBuddy {
            self.settings.buddy = forced
        }
        if let forced = LaunchOptions.forcedTheme {
            self.settings.theme = forced
            ThemeManager.shared.theme = forced
        }
        if LaunchOptions.fillJournal {
            journal.fillForDebug(count: LaunchOptions.fillJournalCount)
        }
        stray.seedForDebug()
        if let forced = LaunchOptions.forcedTrack, MusicCatalog.track(id: forced) != nil {
            self.settings.music = forced
        }
        if let raw = LaunchOptions.forcedSnack, let snack = Snack(rawValue: raw) {
            pantry.forceSill(snack)
        }
        if LaunchOptions.fillTastes {
            pantry.fillForDebug()
        }
        if let count = LaunchOptions.fiveCount {
            fives.seedForDebug(count)
        }
        if LaunchOptions.tuckedYesterday {
            tuckIn.seedYesterdayForDebug()
        }
        // The night caller reads what the pantry's own init sweep took.
        resolveNightVisit()
        if let raw = LaunchOptions.nightCaller {
            let species = Species(rawValue: raw) ?? .tanuki
            journal.addNightKnown(species)
            nightVisit = NightCaller.Visit(species: species, snack: .sardine, memento: nil)
        }
        // The doorstep decides once per calendar day, at the first open.
        // After the forced place and buddy above, so a forced morning is
        // the morning it would have been there. The forced flags below then
        // override whatever the day rolled.
        doorstep.arrive(
            place: self.settings.place, buddy: self.settings.buddy,
            season: Season.current()
        )
        if let raw = LaunchOptions.forcedHello, let hello = Hello(rawValue: raw) {
            doorstep.forceHello(hello)
        }
        if let raw = LaunchOptions.forcedFind, let find = Keepsake(rawValue: raw) {
            doorstep.forceFind(find)
        }
        if let raw = LaunchOptions.forcedBurr, let burr = Burr(rawValue: raw) {
            doorstep.forceBurr(burr)
        }
        if LaunchOptions.fillDrawer {
            drawer.fillForDebug()
        }
        // Whatever was practiced before today has been slept on.
        repertoire.consolidate()
        // And the buddy checks its calendar of the two of you.
        memories.lookBack(log: log, journal: journal, stray: stray)
        // A slip drawn earlier today keeps pressing after a relaunch.
        if let slip = fortunes.today {
            applyFortuneBias(slip)
        }
        if let row = LaunchOptions.forcedFortune {
            drawFortuneIfDue(row: row)
        }
        if let forced = LaunchOptions.forcedJourney {
            let parts = forced.split(separator: ".").map(String.init)
            if parts.count == 2, let buddy = Buddy(rawValue: parts[0]),
               let place = Place(rawValue: parts[1]) {
                travels.seedForDebug(buddy: buddy, place: place)
            }
        }
        if LaunchOptions.returnNow {
            travels.hurryAllForDebug()
        }
        if let raw = LaunchOptions.forcedSeed, let kind = PlantKind(rawValue: raw) {
            garden.offerForDebug(kind: kind)
        }
        if LaunchOptions.forceBloom {
            garden.bloomForDebug()
        }
        // Anyone whose hidden clock ran out while the app was closed.
        resolveJourneys()
        // The garden's standing effects: blooms press the bias seam, and a
        // carrying berrybush restocks a bare sill once a day.
        tendGarden()
        if let days = LaunchOptions.rememberDaysAgo {
            memories.forceForDebug(daysAgo: days, journal: journal)
        }
        if let forced = LaunchOptions.forcedTrick {
            let parts = forced.split(separator: ".").map(String.init)
            if let first = parts.first, let trick = Trick(rawValue: first) {
                let tier = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
                repertoire.seedForDebug(trick, tier: tier, buddy: self.settings.buddy)
                forcedTrickPreview = (trick, tier)
            }
        }
    }

    /// Set by `-PawmodoroTrick`, played by `BuddyView` shortly after launch —
    /// drawing a clean circle through the simulator pane's input latency is
    /// exactly the class of gesture the walk table calls unverifiable.
    @ObservationIgnored var forcedTrickPreview: (trick: Trick, tier: Int)?

    /// Draw the day's slip if this is the first focus start of the day, and
    /// press its luck into the bias seam. Idempotent past the first call.
    private func drawFortuneIfDue(row: Int? = nil) {
        guard phase == .focus || row != nil else { return }
        guard let slip = fortunes.drawIfDue(
            log: log, journal: journal, place: settings.place,
            buddy: settings.buddy, moonIsFull: MoonPhase.isFull(),
            season: Season.current(), row: row
        ) else { return }
        applyFortuneBias(slip)
        drawnSlip = slip
    }

    /// The standing fortune bias — re-applied on launch too, so a slip
    /// drawn this morning still presses after an afternoon relaunch.
    private func applyFortuneBias(_ slip: Fortune) {
        guard let raw = slip.biasSpecies, let species = Species(rawValue: raw)
        else { return }
        setBias(SightingBias(
            source: "fortune", species: species,
            place: slip.biasPlace.flatMap(Place.init(rawValue:)),
            weight: 4, oneShot: false
        ))
    }

    // MARK: Little journeys

    /// See a buddy off. If the sill holds a snack, the first traveler of
    /// the day packs it — knotted into the furoshiki, one caption's worth
    /// of provisions.
    func sendOnJourney(_ buddy: Buddy, to place: Place) {
        guard buddy != settings.buddy, !travels.isAway(buddy) else { return }
        let packed = pantry.packForRoad()
        travels.send(buddy, to: place, packing: packed)
    }

    /// Resolve every journey that is due — including a traveler recalled by
    /// being picked for duty, who comes straight home when called. Letters
    /// compose here, where the journal and the drawer live.
    func resolveJourneys(now: Date = Date()) {
        for journey in travels.due(now: now, selected: settings.buddy) {
            guard let buddy = Buddy(rawValue: journey.buddy),
                  let place = Place(rawValue: journey.destination)
            else {
                // A record from a future version this build can't read:
                // leave it be rather than eat it.
                continue
            }
            let season = Season.current()
            let snack = journey.snack.flatMap(Snack.init(rawValue:))
            // The tip: a species the journal is missing at that place.
            let gap = Species.allCases.first {
                !journal.hasSeen($0) && !$0.isPhenomenon
                    && $0.places.contains(place) && $0.rarity != .mythic
            }
            let keepsake = Keepsake.find(
                at: place, season: season,
                day: Snack.dayNumber(for: journey.returnsAt)
            )
            let text = LetterPress.compose(
                buddyName: settings.displayName(for: buddy), place: place,
                season: season, snack: snack,
                snackReaction: snack.map { buddy.reaction(to: $0) }, gap: gap
            )
            let letter = Letter(
                id: UUID(), date: now, buddy: journey.buddy,
                place: journey.destination, text: text,
                keepsake: keepsake.rawValue, reportedSpecies: gap?.rawValue
            )
            drawer.add(keepsake, place: place, finder: buddy, on: now)
            if let gap {
                setBias(SightingBias(
                    source: "journey.\(journey.buddy)", species: gap,
                    place: place, weight: 6, oneShot: true
                ))
            }
            travels.complete(journey, letter: letter)
            arrivedLetter = letter
        }
    }

    /// The homecoming announcement, read out once by the caption.
    func claimArrivedLetter() -> Letter? {
        defer { arrivedLetter = nil }
        return arrivedLetter
    }

    // MARK: The window-box

    /// Plant the offered seed. The garden mutates; the engine re-presses
    /// whatever the blooms are calling for.
    func plantSeed(in slot: Int) {
        garden.plantOffered(in: slot)
        tendGarden()
    }

    /// Pick an open bloom: the pocket returns to soil and the plant hands
    /// over what it was holding — berries to the sill, a keepsake to the
    /// drawer for the others.
    func pickBloom(at slot: Int) {
        guard let picked = garden.pick(slot: slot, log: log) else { return }
        switch PlantKind(rawValue: picked.kind) {
        case .berrybush:
            pantry.stock(.cloudberry)
        case .callflower:
            drawer.add(.sprig, place: settings.place, finder: settings.buddy)
        case .moonbell:
            drawer.add(.snowdrop, place: settings.place, finder: settings.buddy)
        case nil:
            break
        }
        tendGarden()
    }

    /// The garden's standing effects, re-derived whenever anything could
    /// have changed: blooming callflowers and moonbells press the bias
    /// seam; a carrying berrybush restocks a bare sill once a day.
    private func tendGarden() {
        biases.removeAll { $0.source.hasPrefix("garden.") }
        for bloom in garden.blooms(log: log) {
            let species: Species? = switch PlantKind(rawValue: bloom.pocket.kind) {
            case .callflower: bloom.pocket.species.flatMap(Species.init(rawValue:))
            case .moonbell: .moth
            case .berrybush, nil: nil
            }
            if let species {
                setBias(SightingBias(
                    source: "garden.\(bloom.slot)", species: species,
                    place: nil, weight: 5, oneShot: false
                ))
            }
        }
        if garden.claimDailyYield(log: log), pantry.sill == nil {
            pantry.stock(.cloudberry)
        }
    }

    /// Last night's sill visitor, waiting for the morning's first look.
    private(set) var nightVisit: NightCaller.Visit?

    func claimNightVisit() -> NightCaller.Visit? {
        defer { nightVisit = nil }
        return nightVisit
    }

    /// If the sweep just took an overnight snack, resolve who came for it.
    /// The evidence is banked immediately — the caption is presentation,
    /// the visit is fact.
    private func resolveNightVisit() {
        guard nightVisit == nil,
              let swept = pantry.claimSweptOvernight(),
              let visit = NightCaller.visit(
                snack: swept.snack, sweptFrom: swept.from,
                moonIsFull: MoonPhase.isFull()
              )
        else { return }
        journal.addNightKnown(visit.species)
        if let memento = visit.memento {
            drawer.add(memento, place: settings.place, finder: settings.buddy)
        }
        nightVisit = visit
    }

    /// A drawn cue landed on the scene. The bond gates the vocabulary — a
    /// slot not yet open simply doesn't answer, which is indistinguishable
    /// from not having found the cue, so nothing ever reads as refused.
    func cueTrick(_ trick: Trick) {
        guard runState != .running || phase.isBreak else { return }
        guard bond >= trick.requiredBond else { return }
        repertoire.cue(trick, buddy: settings.buddy)
    }

    // MARK: Derived values

    var phaseDuration: TimeInterval { settings.duration(for: phase) }

    /// 0 at the start of a phase, 1 when it completes.
    var progress: Double {
        let duration = phaseDuration
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var remainingText: String {
        let total = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var isRunning: Bool { runState == .running }

    var pawsPerCycle: Int { max(1, settings.sessionsPerLongBreak) }

    /// What the current buddy is called — the user's name for it, if any.
    var buddyName: String { settings.displayName(for: settings.buddy) }

    /// Paw prints to show as earned in the current cycle.
    var filledPaws: Int { min(focusInCycle, pawsPerCycle) }

    /// How well you and your buddy know each other, counted out of the log.
    var bond: Bond { Bond.level(at: log.totalSessions) }

    /// How far the stray has come. Counted out of the log every time it's read
    /// rather than stored, which is what makes it impossible to get out of step
    /// with the history it describes.
    var strayStage: Stray.Stage { stray.stage(log: log) }

    // MARK: Controls

    func start() {
        guard runState != .running else { return }
        if runState == .idle || remaining <= 0 {
            remaining = phaseDuration
        }
        // Rolled once per fresh focus phase — resuming from a pause keeps
        // whatever was already scheduled rather than buying another ticket.
        if runState == .idle {
            rainSeconds = 0
            // The slip is drawn as the day's first session *starts* — before
            // the rolls, so its luck applies to this very session.
            drawFortuneIfDue()
            rollSighting()
            rollDream()
            rollHeard()
            rollEncounter()
            rollStrayCameo()
            // The break's closing pounce: one second in seven gets away.
            // Rolled here like everything else, so the chase is pure
            // f(remaining) afterwards.
            pounceEscape = phase.isBreak
                && (LaunchOptions.pounceEscapes || Int.random(in: 0..<7) == 0)
        }

        let end = Date().addingTimeInterval(remaining)
        endDate = end
        runState = .running
        lastHeartbeatSecond = nil
        NotificationManager.shared.schedulePhaseEnd(
            for: phase, buddyName: buddyName, at: end
        )
        // Started fresh or moved on in place: one card per run, not one per
        // phase. A no-op until the widget extension exists.
        if settings.liveActivityEnabled {
            LiveActivityController.shared.startOrUpdate(
                phase: phase, buddyName: buddyName, endDate: end
            )
        }
        HapticsDirector.shared.start()
        refreshAmbience()
        startTicker()
    }

    func pause() {
        guard runState == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        runState = .paused
        endDate = nil
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        refreshAmbience()
    }

    func toggle() {
        if runState == .running {
            pause()
        } else {
            NotificationManager.shared.requestPermissionIfNeeded()
            start()
        }
    }

    /// Restart the current phase from the top.
    func reset() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        endDate = nil
        sighting = nil
        dream = nil
        scheduledSound = nil
        encounter = nil
        runState = .idle
        remaining = phaseDuration
        refreshAmbience()
    }

    /// Jump to the next phase without earning credit for this one.
    func skipPhase() {
        stopTicker()
        NotificationManager.shared.cancelPending()
        LiveActivityController.shared.end()
        endDate = nil
        // Whatever was out there simply leaves, and whatever was being dreamed
        // is not kept. Nothing is logged and nothing is said about it —
        // abandoning a session is not punished here.
        sighting = nil
        dream = nil
        scheduledSound = nil
        encounter = nil
        advance(natural: false)
    }

    /// Start the whole cycle over, clearing earned paw prints.
    func resetCycle() {
        focusInCycle = 0
        phase = .focus
        reset()
    }

    /// Call when the app returns to the foreground.
    func syncAfterWake() {
        // Overnight housekeeping first: a snack left out is gone by morning,
        // and an app re-entered on a new day gets its doorstep moment.
        pantry.sweep()
        resolveNightVisit()
        doorstep.arrive(
            place: settings.place, buddy: settings.buddy, season: Season.current()
        )
        repertoire.consolidate()
        memories.lookBack(log: log, journal: journal, stray: stray)
        resolveJourneys()
        tendGarden()
        guard runState == .running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            completePhase()
        }
    }

    /// Persist settings and apply anything that takes effect immediately.
    func settingsDidChange() {
        settings.save()
        ThemeManager.shared.theme = settings.theme
        HapticsDirector.shared.isEnabled = settings.hapticsEnabled
        if runState == .idle {
            remaining = phaseDuration
        }
        // Picking a buddy who is away recalls it: the traveler comes
        // straight home when called, letter and all.
        resolveJourneys()
        refreshAmbience()
    }

    /// Falls back to the free content if Pawmodoro Plus isn't (or is no longer)
    /// owned — a refund or a family-sharing change can revoke it after the fact,
    /// and the app should never be left playing a sound the user can't pick again.
    func applyEntitlement(hasPlus: Bool) {
        guard !hasPlus else { return }
        var changed = false
        if settings.buddy.isPlus {
            settings.buddy = .cat
            changed = true
        }
        if settings.ambience.isPlus {
            settings.ambience = .off
            changed = true
        }
        if settings.theme.isPlus {
            settings.theme = .sakura
            changed = true
        }
        if let track = currentTrack, track.gate.requiresPlus {
            // A Plus track falls back to the opener rather than to silence:
            // losing Plus shouldn't leave the app quieter than a fresh install.
            settings.music = MusicCatalog.opener.id
            changed = true
        }
        if settings.place.isPlus {
            // Back to the furthest free place already earned, not all the way
            // home: losing Plus shouldn't undo the journey.
            settings.place = furthestFreePlace
            changed = true
        }
        if changed {
            settingsDidChange()
        }
    }

    // MARK: Music

    /// Whether a mixtape (or a single track) has been earned. Arrival gates ask
    /// the journey, which is already tracked — the almanac adds no new state.
    func isUnlocked(_ gate: MusicGate, hasPlus: Bool) -> Bool {
        if LaunchOptions.unlockMusic { return true }
        switch gate {
        case .free: return true
        case .arrival(let place): return hasReached(place)
        case .plus: return hasPlus
        }
    }

    /// The track currently chosen, if it still exists in the catalogue.
    var currentTrack: MusicTrack? {
        settings.music.flatMap { MusicCatalog.track(id: $0) }
    }

    /// Music follows the timer the same way ambience does: it plays while a
    /// phase is running and rests otherwise, so a forgotten app is silent.
    func refreshMusic(hasPlus: Bool = true) {
        MusicPlayer.shared.volume = Float(settings.musicVolume)
        let radio = settings.radioMode && (hasPlus || LaunchOptions.unlockMusic)
        MusicPlayer.shared.nextForRadio = radio ? { [weak self] in self?.radioPick() } : nil

        guard runState == .running else {
            MusicPlayer.shared.stop()
            return
        }
        if radio {
            MusicPlayer.shared.play(MusicPlayer.shared.current ?? radioPick() ?? MusicCatalog.opener)
        } else if let track = currentTrack {
            MusicPlayer.shared.play(track)
        } else {
            MusicPlayer.shared.stop()
        }
    }

    /// The auto-DJ. Prefers tracks belonging to where you are, and matches
    /// energy to the hour — brighter by day, quieter after dark.
    private func radioPick() -> MusicTrack? {
        let hasPlus = LaunchOptions.unlockMusic || storeHasPlus
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        let wanted: ClosedRange<Int> = (part == .dawn || part == .day) ? 2...3 : 1...2

        let available = MusicCatalog.tracks.filter { isUnlocked($0.gate, hasPlus: hasPlus) }
        guard !available.isEmpty else { return nil }

        let here = available.filter { $0.collection == settings.place.rawValue }
        let pool = here.isEmpty ? available : here
        let matched = pool.filter { wanted.contains($0.energy) }
        let choices = (matched.isEmpty ? pool : matched)
            .filter { $0.id != MusicPlayer.shared.current?.id }
        return (choices.isEmpty ? pool : choices).randomElement()
    }

    /// Radio needs to know the entitlement without owning a StoreManager.
    var storeHasPlus: Bool = false

    // MARK: Sightings

    /// Decide whether anything turns up during this focus phase, and when.
    ///
    /// Rolled up front rather than moment to moment so the whole appearance is
    /// a pure function of `progress` afterwards — no timer, no state machine,
    /// and the animal is guaranteed to be gone before the chime.
    private func rollSighting() {
        sighting = nil
        guard phase == .focus else { return }

        // A forced dream must actually appear: a rolled sighting would
        // preempt it (the two are exclusive by design), which made the debug
        // flag lose a coin toss in any place with common wildlife about.
        if LaunchOptions.forcedDream != nil, LaunchOptions.forcedSighting == nil {
            return
        }

        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        if let forced = LaunchOptions.forcedSighting {
            sighting = Sighting(species: forced)
            return
        }

        let eligible = Species.allCases.filter {
            $0.isEligible(
                place: settings.place,
                dayPart: part,
                focusMinutes: settings.focusMinutes,
                moonIsFull: MoonPhase.isFull()
            )
        }
        guard !eligible.isEmpty else { return }

        // The first session somewhere new always shows you something: the
        // whole system is invisible until it has happened once.
        if !journal.hasSeenAnything(at: settings.place),
           let welcome = eligible.filter({ $0.rarity == .common }).randomElement() {
            sighting = Sighting(species: welcome)
            return
        }

        // Whatever the day's small thumbs are pressing for gets first
        // refusal at boosted odds; the ordinary queue runs unchanged after.
        for bias in biases where bias.place == nil || bias.place == settings.place {
            guard eligible.contains(bias.species) else { continue }
            let odds = min(0.85, bias.species.rarity.chance * bias.weight)
            if Double.random(in: 0..<1) < odds {
                sighting = Sighting(species: bias.species)
                if bias.oneShot { clearBias(source: bias.source) }
                return
            }
        }

        // A mythic's conditions are its rarity — if one is eligible at all,
        // the night is already unusual, so it goes to the front of the queue.
        let ordered = eligible.filter { $0.rarity == .mythic }.shuffled()
            + eligible.filter { $0.rarity != .mythic }.shuffled()
        for species in ordered where Double.random(in: 0..<1) < species.rarity.chance {
            sighting = Sighting(species: species)
            return
        }
    }

    // MARK: Micro-encounters

    /// The tiny thing visiting this phase, if one is. Never recorded anywhere:
    /// it happens, and then it has happened.
    private(set) var encounter: MicroEncounter?

    /// On screen right now, or nil.
    var visibleEncounter: (encounter: MicroEncounter, phase: Double)? {
        guard isRunning, phase == .focus, let encounter else { return nil }
        let window = encounter.window
        guard window.contains(progress) else { return nil }
        let span = window.upperBound - window.lowerBound
        guard span > 0 else { return nil }
        return (encounter, (progress - window.lowerBound) / span)
    }

    private func rollEncounter() {
        encounter = nil
        guard phase == .focus else { return }

        if let forced = LaunchOptions.forcedEncounter {
            encounter = forced
            return
        }

        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        let season = Season.current()

        let possible = MicroEncounter.allCases.filter {
            $0.isPossible(place: settings.place, dayPart: part, season: season)
        }
        guard let candidate = possible.randomElement(),
              Double.random(in: 0..<1) < MicroEncounter.chance
        else { return }
        encounter = candidate
    }

    // MARK: Things heard

    /// A sound scheduled for this phase, and the point in it where it lands.
    ///
    /// Stored as a progress fraction for the same reason a sighting is: the
    /// tick already knows how far through the phase it is, so this needs no
    /// timer of its own and cannot drift.
    @ObservationIgnored private var scheduledSound: (sound: Heard, at: Double)?

    /// Decide whether anything is audible this phase, and when.
    ///
    /// Rolled independently of the sighting and the dream — a sound isn't
    /// competing for the screen, and hearing a whale while watching a stag is
    /// a better session, not a busier one.
    private func rollHeard() {
        scheduledSound = nil
        guard phase == .focus else { return }
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()

        // Somewhere in the middle: the opening belongs to settling in and the
        // last stretch belongs to the countdown.
        let at = Double.random(in: 0.25...0.75)
        if let forced = LaunchOptions.forcedHeard {
            scheduledSound = (forced, at)
            return
        }
        let eligible = Heard.allCases.filter {
            $0.isEligible(place: settings.place, dayPart: part)
        }
        guard let sound = eligible.randomElement(),
              Double.random(in: 0..<1) < sound.spec.chance
        else { return }
        scheduledSound = (sound, at)
    }

    /// Fires once, when the phase reaches the scheduled point.
    private func playHeardIfDue() {
        guard let scheduled = scheduledSound, progress >= scheduled.at else { return }
        scheduledSound = nil
        SoundPlayer.shared.playHeard(scheduled.sound)
        // Logged on play, not on completion: unlike a sighting there is
        // nothing to stay for. You either heard it or you didn't.
        journal.addHeard(scheduled.sound)
    }

    // MARK: Dreams

    /// The slice of a focus phase a dream is on screen for. Overlaps nothing:
    /// a sighting owns 0.32–0.70 and the two are mutually exclusive anyway.
    static let dreamWindow: ClosedRange<Double> = 0.40...0.70

    /// The dream on screen right now, if there is one. `BuddyView` adds the
    /// last condition — the buddy has to actually be asleep — which is what
    /// makes Luna dream through her daytime naps rather than her night watch,
    /// with no special case anywhere.
    var visibleDream: Dream? {
        guard isRunning, phase == .focus, let dream else { return nil }
        return Self.dreamWindow.contains(progress) ? dream : nil
    }

    /// Decide whether the buddy dreams this phase, and of what.
    ///
    /// Only when nothing else is turning up: a dream and a sighting in the same
    /// session would be two quiet things competing, and the sighting is the
    /// rarer one.
    private func rollDream() {
        dream = nil
        guard phase == .focus, sighting == nil else { return }

        // Luna keeps watch through a night focus — awake creatures don't
        // dream. Without this, the roll still happened and the diary quietly
        // recorded dreams she never showed: the display was gated on the
        // napping pose, but the keep wasn't.
        let part = LaunchOptions.forcedDayPart ?? DayPart.current()
        if settings.buddy.isNocturnal, part == .night { return }

        if let forced = LaunchOptions.forcedDream {
            dream = Dream.from(id: forced) ?? pool().first { $0.id.hasPrefix(forced) }
            return
        }
        // The blanket's whole promise: the day after a tucked night, the
        // dream isn't left to its odds — it simply happens.
        if tuckIn.blessing() {
            dream = pool().randomElement()
            return
        }
        guard Double.random(in: 0..<1) < 0.25 else { return }
        dream = pool().randomElement()
    }

    /// Weighted memory > travel > surreal, by simple repetition — a species you
    /// actually saw is three times likelier than a fish holding a balloon. The
    /// surreal six are always in the pool so that a brand-new buddy, whose
    /// journal is empty, still has something to dream about.
    private func pool() -> [Dream] {
        var pool: [Dream] = []
        for species in Species.allCases where journal.hasSeen(species) {
            pool.append(contentsOf: repeatElement(.memory(species), count: 3))
        }
        for place in Place.journey where hasReached(place) {
            if let vignette = place.vignette {
                pool.append(contentsOf: repeatElement(.travel(vignette), count: 2))
            }
        }
        pool.append(contentsOf: Dream.Surreal.allCases.map(Dream.surreal))
        return pool
    }

    /// How long ago you met the thing being dreamed about, so the diary can
    /// write the relationship rather than just the fact.
    private func daysSinceMeeting(_ dream: Dream) -> Int? {
        guard case .memory(let species) = dream,
              let record = journal.record(for: species)
        else { return nil }
        return Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: record.firstSeen),
            to: Calendar.current.startOfDay(for: Date())
        ).day
    }

    /// Roughly one phase in four, once she lives here and somebody else is on
    /// duty. Never while she *is* the buddy — she can't do her rounds and keep
    /// you company at the same time.
    private func rollStrayCameo() {
        strayCameo = stray.hasJoined
            && settings.buddy != .stray
            && Double.random(in: 0..<1) < 0.25
    }

    // MARK: The journey

    /// Whether a place has been reached, ignoring Plus. Entitlement is checked
    /// separately so progress and purchase stay independent.
    func hasReached(_ place: Place) -> Bool {
        LaunchOptions.unlockPlaces || log.totalSessions >= place.requiredSessions
    }

    /// Sessions still to go before this place opens.
    func sessionsRemaining(to place: Place) -> Int {
        max(0, place.requiredSessions - log.totalSessions)
    }

    private var furthestFreePlace: Place {
        Place.journey.last { !$0.isPlus && hasReached($0) } ?? .meadow
    }

    /// The place a just-finished session has newly opened up, if any.
    ///
    /// Called after the log has been written, so `totalSessions` already counts
    /// the session being celebrated. Returns nil for the very first place,
    /// which is where everyone starts.
    func newlyReachedPlace() -> Place? {
        guard let reached = Place.journey.last(where: { hasReached($0) }),
              reached.requiredSessions > 0,
              log.totalSessions == reached.requiredSessions
        else { return nil }
        return reached
    }

    /// Ambience follows the timer: it plays while running and rests otherwise.
    func refreshAmbience() {
        SoundPlayer.shared.setAmbience(runState == .running ? settings.ambience : .off)
        SoundPlayer.shared.ambienceVolume = Float(settings.ambienceVolume)
        refreshMusic()
    }

    // MARK: Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        // .common keeps the countdown updating while the user scrolls a sheet.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if settings.ambience == .rain { rainSeconds += 0.25 }
        playHeardIfDue()
        pulseIfClosing()
        if remaining <= 0 {
            completePhase()
        }
    }

    /// One soft heartbeat per second over the last ten, tightening as the phase
    /// closes. Driven off the existing ticker rather than a timer of its own.
    private func pulseIfClosing() {
        let window: TimeInterval = 10
        guard remaining > 0, remaining <= window else { return }
        let second = Int(remaining.rounded(.up))
        guard second != lastHeartbeatSecond else { return }
        lastHeartbeatSecond = second
        HapticsDirector.shared.heartbeat(progress: 1 - remaining / window)
    }

    private func completePhase() {
        stopTicker()
        LiveActivityController.shared.end()
        endDate = nil
        remaining = 0
        lastHeartbeatSecond = nil

        let finished = phase
        HapticsDirector.shared.complete()
        SoundPlayer.shared.playChime()

        var arrival: Place?
        var seen: Species?
        var figure: Constellation?
        var bond: Bond?
        if finished == .focus {
            // Read either side of the write, so a figure can only be announced
            // by the one session that actually finished it.
            let nightsBefore = log.nightSessions
            let sessionsBefore = log.totalSessions
            log.add(minutes: settings.focusMinutes,
                    place: settings.place, buddy: settings.buddy)
            bond = Bond.justReached(before: sessionsBefore, after: log.totalSessions)
            figure = ConstellationAtlas.justCompleted(
                before: nightsBefore, after: log.nightSessions
            )
            // Checked after the log is written, so the session that just
            // finished counts toward the week she is deciding about. She only
            // ever starts watching off the back of a session you completed.
            stray.noticeIfReady(log: log)
            // A rainbow is not rolled: it is earned by a session that
            // actually ran rain for at least half its length, which is only
            // knowable now. Deterministic, so it feels given rather than won.
            if sighting == nil,
               rainSeconds >= phaseDuration / 2,
               (LaunchOptions.forcedDayPart ?? DayPart.current()) == .day,
               Species.rainbow.spec.places.contains(settings.place) {
                sighting = Sighting(species: .rainbow)
            }
            // Same rule as a sighting: leave early and the dream just fades,
            // unrecorded. Dreams are like that.
            if let dream {
                dreams.add(dream, daysAfter: daysSinceMeeting(dream))
                // And a kept dream drops a seed by the windowsill — the
                // garden grows what the dreams dreamed.
                garden.offerSeed(from: dream)
            }
            // You only keep what you stayed for.
            if let sighting {
                seen = sighting.species
                journal.add(
                    sighting.species,
                    at: settings.place,
                    dayPart: LaunchOptions.forcedDayPart ?? DayPart.current()
                )
            }
            // The session's warm epilogue: the world sets out one snack for
            // the buddy. The sill holds one at most, so this never stacks.
            pantry.setOut(for: settings.place, season: Season.current())
            // Checked after the log is written, so this session counts toward
            // the threshold it might have just crossed.
            arrival = newlyReachedPlace()
            if let arrival, !arrival.isPlus {
                // Free arrivals move you there; the Far Isles wait behind the
                // paywall rather than switching to a place you can't keep.
                settings.place = arrival
            }
        }
        advance(natural: true)

        // Published after `advance`, so the paw count and the phase it reports
        // are the ones the UI is about to draw.
        // A card for the two moments worth keeping: getting somewhere new,
        // and closing a cycle. Both are rare enough that the album stays a
        // record rather than a feed.
        if finished == .focus, arrival != nil || (phase == .longBreak) {
            album.add(Postcard(
                id: UUID(),
                date: Date(),
                place: settings.place.rawValue,
                dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                buddy: settings.buddy.rawValue,
                occasion: arrival != nil ? .arrival : .cycle,
                sessions: log.todaySessions,
                sighting: seen?.rawValue
            ))
        }

        completion = PhaseCompletion(
            finished: finished,
            pawsEarned: filledPaws,
            pawsPerCycle: pawsPerCycle,
            isCycleComplete: finished == .focus && phase == .longBreak,
            arrivedAt: arrival,
            saw: seen,
            completedFigure: figure,
            dreamed: finished == .focus ? dream : nil,
            bondReached: bond
        )
        sighting = nil
        dream = nil
    }

    private func advance(natural: Bool) {
        switch phase {
        case .focus:
            if natural {
                focusInCycle += 1
            }
            phase = focusInCycle >= pawsPerCycle ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .focus
        case .longBreak:
            focusInCycle = 0
            phase = .focus
        }

        runState = .idle
        remaining = phaseDuration
        refreshAmbience()

        if natural && settings.autoStartNextPhase {
            start()
        }
    }
}
