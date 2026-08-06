import SwiftUI

extension View {
    /// The world's own light, applied to anything.
    ///
    /// Lived at the bottom of `ScrapbookView.swift` until the homestead
    /// wanted it too — a modifier two unrelated screens depend on has no
    /// business hiding under a third one's implementation.
    ///
    /// Both steps come from `FilmStock` rather than being typed here:
    /// saturation first for the press, then the per-channel affine that the
    /// scene generator grades palettes with. `tools/check_film.py` holds the
    /// numbers against the generators.
    @ViewBuilder
    func filmStock(_ stock: FilmStock) -> some View {
        let (scale, bias) = stock.matrix
        self
            .saturation(stock.desaturates ? 0 : 1)
            .colorMultiply(Color(red: scale.0, green: scale.1, blue: scale.2))
            .overlay(
                Color(red: bias.0, green: bias.1, blue: bias.2)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .compositingGroup()
    }
}
