#if DEBUG
import UIKit

/// Three sample photographs, for `-PawmodoroSeedScrapbook`.
///
/// The simulator has no camera and its photo library is three stock
/// wallpapers, so without this the whole feature is unreachable from a pane.
/// They are *generated* rather than bundled for two reasons: three flat
/// gradients are enough to judge a film stock by — a stock is a per-channel
/// transform and a flat field shows it more honestly than a photograph does —
/// and shipping real photographs inside the app would mean shipping somebody's
/// data in the binary.
///
/// Debug-only in the strongest sense: the whole file is compiled out of
/// Release, so there is no Release stand-in to keep in step. Nothing outside
/// `#if DEBUG` refers to it.
enum SnapshotSeed {

    static func fill(_ scrapbook: Scrapbook) {
        guard scrapbook.isEmpty, let directory = Scrapbook.directory else { return }
        let samples: [(UIColor, UIColor, Place, Weather, Int)] = [
            (UIColor(red: 0.86, green: 0.80, blue: 0.68, alpha: 1),
             UIColor(red: 0.55, green: 0.44, blue: 0.33, alpha: 1),
             .meadow, .clear, 25),
            (UIColor(red: 0.72, green: 0.78, blue: 0.84, alpha: 1),
             UIColor(red: 0.30, green: 0.36, blue: 0.44, alpha: 1),
             .harbor, .mist, 50),
            (UIColor(red: 0.90, green: 0.74, blue: 0.72, alpha: 1),
             UIColor(red: 0.42, green: 0.30, blue: 0.34, alpha: 1),
             .blossom, .golden, 40),
        ]

        for (index, sample) in samples.enumerated() {
            guard let data = card(sample.0, sample.1) else { continue }
            let file = "sample-\(index).jpg"
            guard (try? data.write(to: directory.appendingPathComponent(file))) != nil
            else { continue }
            scrapbook.add(Snapshot(
                date: Date().addingTimeInterval(-Double(index) * 86_400),
                file: file,
                place: sample.2.rawValue,
                buddy: Buddy.cat.rawValue,
                weather: sample.3.rawValue,
                minutes: sample.4
            ))
        }
    }

    /// A two-tone field with a soft edge — enough structure that a grade's
    /// effect on light and dark areas is both visible at once.
    private static func card(_ light: UIColor, _ dark: UIColor) -> Data? {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            light.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            dark.setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: -120, y: 620, width: 1140, height: 900)
            )
            UIColor(white: 1, alpha: 0.35).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: 540, y: 90, width: 260, height: 260)
            )
        }.jpegData(compressionQuality: 0.9)
    }
}
#endif
