import SwiftUI

/// The hours you have ever been here for.
///
/// Twenty-four candles on two shelves, midnight at the left. One lights the
/// first time a session ever ends in that hour, and then it stays lit — this
/// is the app's one true collection, and the only thing it collects is having
/// been somewhere at some point.
///
/// There is no count anywhere on this view, on purpose. The unlit candles are
/// the hours you were asleep, and a number telling you how many of those there
/// are would turn a picture of a life into a chore list.
struct ShelfOfHoursView: View {
    @Environment(TimerEngine.self) private var engine

    private var candles: [ShelfOfHours.Candle] {
        ShelfOfHours.build(from: engine.log.records)
    }

    /// Two rows of twelve: midnight to noon, then noon to midnight. Twenty-four
    /// across would be four points wide on a small phone.
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2), count: 12
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The shelf of hours")
                .font(.headline)
                .foregroundStyle(Theme.bark)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(candles) { candle in
                    view(for: candle)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface.opacity(0.55))
            )

            if let line = litCaption {
                Text(line)
                    .font(.footnote.italic())
                    .foregroundStyle(Theme.bark.opacity(0.55))
            }
        }
    }

    private var caption: String {
        candles.contains(where: \.isLit)
            ? "One lights the first time you finish a session in that hour."
            : "Finish a session and the hour you finished it in lights up here."
    }

    /// One caption at a time, for the strangest hour that is lit — so the
    /// shelf has something to say without listing anything. Ordered from the
    /// small hours outward, because 3 a.m. is more worth remarking on than
    /// noon, and noon is more worth remarking on than nothing.
    private var litCaption: String? {
        let interesting = [3, 4, 5, 0, 23, 21, 17, 12]
        for hour in interesting {
            if ShelfOfHours.isLit(hour, in: candles),
               let caption = candles.first(where: { $0.hour == hour })?.caption {
                return "\(hourLabel(hour)) — \(caption)."
            }
        }
        return nil
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "Midnight"
        case 12: "Noon"
        case 1...11: "\(hour) a.m."
        default: "\(hour - 12) p.m."
        }
    }

    private func view(for candle: ShelfOfHours.Candle) -> some View {
        VStack(spacing: 2) {
            Image(candle.isLit ? "fx_candle_lit" : "fx_candle_out")
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                // Lit candles carry the theme's warm accent; unlit ones are
                // barely there. Never red, never a warning — an hour you have
                // not met is not a problem to solve.
                .foregroundStyle(candle.isLit
                                 ? Theme.sunshine
                                 : Theme.bark.opacity(0.16))

            Text(candle.label)
                .font(.system(size: 8))
                .monospacedDigit()
                .foregroundStyle(Theme.bark.opacity(candle.isLit ? 0.6 : 0.28))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(for: candle))
    }

    private func accessibility(for candle: ShelfOfHours.Candle) -> String {
        guard let first = candle.firstLit else {
            // Deliberately not "not yet" — there is no "yet" here, because
            // there is nothing anybody is supposed to be working toward.
            return "\(hourLabel(candle.hour)): unlit."
        }
        let day = first.formatted(.dateTime.day().month(.abbreviated).year())
        var line = "\(hourLabel(candle.hour)): lit, first on \(day)."
        if let caption = candle.caption { line += " \(caption)." }
        return line
    }
}
