import SwiftUI

/// Three quick pages on first launch: what the app is, how the loop works,
/// and which buddy you want.
struct OnboardingView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false
    @State private var pageIndex = 0

    private let lastPage = 2

    var body: some View {
        ZStack {
            Theme.background(for: .focus).ignoresSafeArea()

            VStack {
                PagedDeck(index: $pageIndex, count: lastPage + 1) { page in
                    switch page {
                    case 0: welcomePage
                    case 1: howItWorksPage
                    default: buddyPage
                    }
                }

                // **The capsule is the button, not a picture behind one.**
                // Written with the frame, the padding and the `.background`
                // hung on the *outside* of the `Button`, only the label is a
                // control: the pink pill is dead pixels on both platforms, and
                // on macOS AppKit additionally drew its own 46×20 bordered
                // push button in the middle of it — a white rounded rect
                // reading "Next" floating inside our pill, on the first screen
                // anybody sees. Moving the styling into the label makes the
                // whole capsule the control, and an explicit `ButtonStyle` is
                // what stops AppKit adding chrome of its own.
                Button {
                    if pageIndex == lastPage {
                        finish()
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                } label: {
                    Text(pageIndex == lastPage ? "Let's focus" : "Next")
                        .font(.headline)
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Theme.blossom))
                        .contentShape(Capsule())
                }
                .buttonStyle(.squishy)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
    }

    private var welcomePage: some View {
        infoPage(
            title: "Welcome to Pawmodoro",
            message: "A cozy focus timer. Your buddy naps while you work and plays when you rest."
        ) {
            // The sleeping buddy says more about the app than any icon could.
            BuddySprite(buddy: engine.settings.buddy, sleeping: true, size: 132)
        }
    }

    private var howItWorksPage: some View {
        infoPage(
            title: "Focus, then rest",
            message: "Work for 25 minutes, take a short break, and after four sessions enjoy a long one. Every finished session earns a paw print."
        ) {
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { index in
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            index < 3 ? Theme.blossom : Theme.bark.opacity(0.18)
                        )
                }
            }
            .frame(height: 132)
        }
    }

    private var buddyPage: some View {
        @Bindable var engine = engine

        return VStack(spacing: 24) {
            Text("Pick your buddy")
                .font(.title.bold())
                .foregroundStyle(Theme.bark)

            // Only the buddies that ship with the app: a first launch is the
            // wrong moment to put a padlock in front of someone.
            Picker("Buddy", selection: $engine.settings.buddy) {
                ForEach(Buddy.starters) { buddy in
                    Text(engine.settings.displayName(for: buddy)).tag(buddy)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            BuddySprite(buddy: engine.settings.buddy, sleeping: false, size: 132)

            Text("You can change your mind any time in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    private func infoPage<Art: View>(
        title: String,
        message: String,
        @ViewBuilder art: () -> Art
    ) -> some View {
        VStack(spacing: 20) {
            art()
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Theme.bark)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.bark.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .padding(.top, 60)
    }

    private func finish() {
        NotificationManager.shared.requestPermissionIfNeeded()
        hasOnboarded = true
    }
}

#Preview {
    OnboardingView()
        .environment(TimerEngine())
        .fontDesign(.rounded)
}
