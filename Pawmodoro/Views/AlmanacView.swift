import SwiftUI

/// Today, and what it's good for.
///
/// The app now knows a lot that the user doesn't: which species are possible
/// in this place at this hour, how far the next place is, what the real moon
/// is doing. This is the surface that says it out loud — the reason to open
/// the app on a morning you weren't otherwise going to focus, without a single
/// notification.
struct AlmanacView: View {
    @Environment(TimerEngine.self) private var engine

    private var dayPart: DayPart { LaunchOptions.forcedDayPart ?? DayPart.current() }
    private var place: Place { engine.settings.place }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            travelogue
            tide
            flyway
            aboutNow
            // Below what is about and above where else there is, because the
            // dial is not about today at all — it is the one thing on this
            // page that took months and cannot be hurried.
            ClockRingView()
            elsewhere
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
    }

    // MARK: Today

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Through WorldCalendar, so -PawmodoroDate moves the date printed
            // here along with the sky, the moon and the weather under it.
            Text(WorldCalendar.now
                .formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(Theme.bark)
            HStack(spacing: 6) {
                Image(systemName: moonSymbol)
                    .font(.caption)
                    .foregroundStyle(Theme.blossom)
                // The one place the weather is named in words. Everywhere else
                // it is a veil and some particles, which is the right weight
                // for it — but a thing with no name is a thing nobody can tell
                // you about, and this is meant to be worth mentioning.
                Text("\(MoonPhase.name()) · \(dayPart.almanacWord) · "
                     + engine.weather.name.lowercased())
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
            Text(engine.weather.line)
                .font(.footnote.italic())
                .foregroundStyle(Theme.bark.opacity(0.6))
            if MoonPhase.isFull() {
                Text("A good night for the water's edge.")
                    .font(.footnote.italic())
                    .foregroundStyle(Theme.blossom)
            }
            // Recorded, shown, and never challenged. There is no next tier and
            // nothing anywhere asks you to beat it.
            if let longest = longestDriftLine {
                Text(longest)
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.55))
            }
        }
    }

    /// Only once there has been one, and phrased as a fact rather than a
    /// record — "your longest" would make the open hour a thing to win.
    private var longestDriftLine: String? {
        let seconds = engine.log.longestDrift
        guard seconds >= 60 else { return nil }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "The longest you have drifted: \(minutes) minutes." }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0
            ? "The longest you have drifted: \(hours) hours."
            : "The longest you have drifted: \(hours)h \(rest)m."
    }

    private var moonSymbol: String {
        let age = MoonPhase.age()
        switch age {
        case ..<0.03, 0.97...: return "moonphase.new.moon"
        case ..<0.25: return "moonphase.waxing.crescent"
        case ..<0.30: return "moonphase.first.quarter"
        case ..<0.47: return "moonphase.waxing.gibbous"
        case ..<0.53: return "moonphase.full.moon"
        case ..<0.72: return "moonphase.waning.gibbous"
        case ..<0.78: return "moonphase.last.quarter"
        default: return "moonphase.waning.crescent"
        }
    }

    // MARK: The route

    /// The eight places on a dotted line, with a boat between the last one
    /// reached and the next. Turns a session count into a position, and
    /// positions ask to be advanced.
    private var travelogue: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The journey")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.8))

            HStack(spacing: 0) {
                ForEach(Array(Place.journey.enumerated()), id: \.element) { index, stop in
                    let reached = engine.hasReached(stop)
                    Circle()
                        .fill(reached ? Theme.blossom : Theme.bark.opacity(0.18))
                        .frame(width: stop == place ? 11 : 7, height: stop == place ? 11 : 7)
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.surface, lineWidth: stop == place ? 2 : 0)
                        )
                    if index < Place.journey.count - 1 {
                        Rectangle()
                            .fill(Theme.bark.opacity(0.18))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 2)

            Text(nextLine)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Journey. \(nextLine)")
    }

    private var nextLine: String {
        guard let next = Place.journey.first(where: { !engine.hasReached($0) }) else {
            return "Every place reached. The whole map is yours."
        }
        let remaining = engine.sessionsRemaining(to: next)
        return "\(remaining) session\(remaining == 1 ? "" : "s") to \(next.name)"
    }

    // MARK: What's about

    private var possibleHere: [Species] {
        Species.allCases.filter {
            $0.isEligible(
                place: place,
                dayPart: dayPart,
                focusMinutes: engine.settings.focusMinutes,
                moonIsFull: MoonPhase.isFull(),
                // Today's real sky here, so "about now" means about now. Half
                // the roster is weather-gated and a list that ignored that
                // would be a list of things that are not, in fact, about.
                weather: Weather.at(place)
            )
        }
    }

    private var aboutNow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About now — \(place.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.8))

            if possibleHere.isEmpty {
                Text("Nothing much is out at this hour. Try another time of day, or somewhere else.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            } else {
                HStack(spacing: 8) {
                    ForEach(possibleHere.prefix(6)) { species in
                        let seen = engine.journal.hasSeen(species)
                        Image(seen ? species.sketchAsset : species.ghostAsset)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 26)
                            .opacity(seen ? 1 : 0.35)
                    }
                    Spacer()
                }
                Text(aboutLine)
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.7))
            }
        }
    }

    private var aboutLine: String {
        let unseen = possibleHere.filter { !engine.journal.hasSeen($0) }.count
        if unseen == 0 {
            return "\(possibleHere.count) about — you've met them all here."
        }
        return "\(possibleHere.count) about, \(unseen) you haven't met."
    }

    // MARK: The tide

    /// What the water is doing, and a curve of the day it is doing it in.
    ///
    /// Only at Harbor Isle, because only Harbor Isle has a sea. Shown whether
    /// or not anything has been seen in it — unlike the flyway, which stays
    /// silent until you have met it. The difference is that a tide is not a
    /// *surprise*: it is the weather of the sea, it is there every day, and a
    /// tide table is a thing anybody standing at a harbour can read off a
    /// board. Hiding it would be hiding the ordinary.
    ///
    /// The one thing it never does is name what is out there. "Low water" is
    /// an observation; "the octopus pools are open" is an errand.
    @ViewBuilder
    private var tide: some View {
        if place == .harbor {
            let now = WorldCalendar.now
            let state = Tide.state(at: now)
            VStack(alignment: .leading, spacing: 5) {
                Text("The water — \(state.name.lowercased())"
                     + (Tide.isRising(at: now) ? ", coming in" : ", going out"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.8))
                TideCurveView(now: now, tint: Theme.blossom, line: Theme.bark)
                    .frame(height: 34)
                Text(state.line)
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.65))
                // The classic tide-table sentence, and the app quietly
                // teaching a real rhythm: high water is about fifty minutes
                // later every day, forever, and nobody ever tells you that.
                if let turn = Tide.nextTurn(after: now) {
                    Text("It turns around \(turn.formatted(date: .omitted, time: .shortened)).")
                        .font(.footnote.italic())
                        .foregroundStyle(Theme.bark.opacity(0.55))
                }
            }
        }
    }

    // MARK: The Flyway

    /// What is going over, and what already went.
    ///
    /// Two hard rules, both of them about what is *absent* — see `Passage` for
    /// why they are the whole design:
    ///
    /// 1. **A passage you have never seen is not mentioned.** No countdown, no
    ///    greyed-out row, no "opens in nine days". Every other locked thing in
    ///    this app shows a padlock; this is the one exception, for the same
    ///    reason Soot is: the surprise is the content. You find out there are
    ///    swans by looking up one February.
    /// 2. **Nothing is ever in the future tense here.** A passage is happening
    ///    or it has happened. The moment this section can say *the geese are
    ///    due next week*, the app has started making appointments for people,
    ///    and the next obvious step is a notification about one.
    private var flyway: some View {
        let seen = { (passage: Passage) in
            passage.species.map(engine.journal.hasSeen) ?? false
        }
        let open = Passage.open().filter(seen)
        let gone = Passage.closed().filter { seen($0.0) }
        return VStack(alignment: .leading, spacing: 4) {
            if !open.isEmpty || !gone.isEmpty {
                Text("On the flyway")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.8))
            }
            ForEach(open) { passage in
                VStack(alignment: .leading, spacing: 1) {
                    Text(passage.name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.bark)
                    Text(passage.line)
                        .font(.footnote)
                        .foregroundStyle(Theme.bark.opacity(0.65))
                }
            }
            // Past tense, and only the most recent — a list of six things that
            // already happened is an inventory, and the point of the afterword
            // is that the world went on while you were busy, not that you can
            // audit it.
            if let (passage, early) = gone.last, open.isEmpty {
                Text(passage.afterword(early: early))
                    .font(.footnote.italic())
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }
        }
    }

    // MARK: Everywhere else

    private var elsewhere: some View {
        let others = Place.journey.filter { $0 != place && engine.hasReached($0) }
        return VStack(alignment: .leading, spacing: 4) {
            if !others.isEmpty {
                Text("Elsewhere today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.8))
                ForEach(others, id: \.self) { other in
                    let count = Species.allCases.filter {
                        $0.isEligible(
                            place: other,
                            dayPart: dayPart,
                            focusMinutes: engine.settings.focusMinutes,
                            moonIsFull: MoonPhase.isFull(),
                            weather: Weather.at(other)
                        )
                    }.count
                    if count > 0 {
                        Text("\(other.name): \(count) about \(dayPart.almanacWhen)")
                            .font(.footnote)
                            .foregroundStyle(Theme.bark.opacity(0.62))
                    }
                }
            }
        }
    }
}

extension DayPart {
    var almanacWord: String {
        switch self {
        case .dawn: "dawn"
        case .day: "daylight"
        case .dusk: "dusk"
        case .night: "night"
        }
    }

    var almanacWhen: String {
        switch self {
        case .dawn: "at dawn"
        case .day: "in daylight"
        case .dusk: "at dusk"
        case .night: "after dark"
        }
    }
}
