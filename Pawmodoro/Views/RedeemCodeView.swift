import SwiftUI

/// Somewhere to type a code in.
///
/// A quiet corner rather than a feature: no artwork, no celebration, no
/// counter of attempts. Getting a code wrong is the most likely thing to
/// happen on this screen, so the wrong-code line is written first and the
/// right-code line is written to match it.
struct RedeemCodeView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var typed = ""
    @State private var checking = false
    @State private var result: StoreManager.RedeemOutcome?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("If somebody gave you a code, this is where it goes.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.bark.opacity(0.75))

                    field
                    redeemButton

                    if let result {
                        resultLine(for: result)
                    }

                    Text("Codes are kept on this device. Redeeming one changes "
                         + "nothing about your Apple Account, and it can't be "
                         + "taken back.")
                        .font(.caption2)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Redeem a code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { fieldFocused = true }
    }

    /// Nothing to check: an empty field, or a check already running.
    private var idle: Bool {
        checking || PromoCodes.normalize(typed).isEmpty
    }

    // MARK: Pieces

    private var field: some View {
        TextField("Your code", text: $typed)
            .font(.title3.monospaced())
            .foregroundStyle(Theme.bark)
            .autocorrectionDisabled()
            .focused($fieldFocused)
            .submitLabel(.go)
            .onSubmit { check() }
            // Typing clears the last answer rather than leaving a stale "that
            // isn't a code" sitting under a field somebody is fixing.
            .onChange(of: typed) { _, _ in result = nil }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface.opacity(0.8))
            )
            .accessibilityLabel("Redemption code")
            .accessibilityHint("Capitals and spaces don't matter.")
    }

    private var redeemButton: some View {
        Button {
            check()
        } label: {
            Group {
                if checking {
                    ProgressView()
                } else {
                    Text("Redeem").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            // Dimmed while it does nothing. A filled capsule keeps its colour
            // when disabled, so without this the button looks tappable with an
            // empty field and simply ignores you.
            .background(Capsule().fill(Theme.blossom.opacity(idle ? 0.45 : 1)))
            .foregroundStyle(Theme.onAccent)
        }
        .disabled(idle)
    }

    @ViewBuilder
    private func resultLine(for outcome: StoreManager.RedeemOutcome) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: outcome))
                .foregroundStyle(accepted(outcome) ? Theme.blossom : Theme.bark.opacity(0.45))
                .frame(width: 20)
            Text(message(for: outcome))
                .font(.subheadline)
                .foregroundStyle(Theme.bark.opacity(accepted(outcome) ? 0.9 : 0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.6)))
        // The line is announced as well as shown — the padlocks disappearing
        // behind this sheet is a change VoiceOver has no other way to notice.
        .accessibilityElement(children: .combine)
    }

    private func accepted(_ outcome: StoreManager.RedeemOutcome) -> Bool {
        switch outcome {
        case .opened, .alreadyOpen: return true
        case .notRecognised: return false
        }
    }

    private func icon(for outcome: StoreManager.RedeemOutcome) -> String {
        switch outcome {
        case .opened: return "checkmark.seal.fill"
        case .alreadyOpen: return "checkmark.seal"
        case .notRecognised: return "questionmark.circle"
        }
    }

    /// The three things this screen can say.
    ///
    /// None of them congratulates anybody and none of them scolds. A wrong
    /// code is treated as a typo, because it nearly always is.
    private func message(for outcome: StoreManager.RedeemOutcome) -> String {
        switch outcome {
        case .opened(let code):
            return code.welcome
        case .alreadyOpen:
            return "That code is already redeemed on this device. Everything "
                 + "it opened is still open."
        case .notRecognised:
            return "That isn't a code this app knows. Worth another look at "
                 + "the spelling; capitals and spaces don't matter. Nothing "
                 + "has changed either way, and you can try as often as you like."
        }
    }

    // MARK: Checking

    private func check() {
        guard !checking else { return }
        checking = true
        let entered = typed
        Task {
            let outcome = await store.redeem(entered)
            checking = false
            result = outcome
            if accepted(outcome) { fieldFocused = false }
            AccessibilityNotification.Announcement(message(for: outcome)).post()
        }
    }
}

#Preview {
    RedeemCodeView()
        .environment(StoreManager())
        .fontDesign(.rounded)
}
