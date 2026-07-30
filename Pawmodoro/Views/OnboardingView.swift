import SwiftUI

/// Three quick pages on first launch: what the app is, how the loop works,
/// and which buddy you want.
struct OnboardingView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage("pawmodoro.hasOnboarded") private var hasOnboarded = false
    @State private var pageIndex = 0

    private let lastPage = 2

    var body: some View {
        ZStack {
            Theme.background(for: .focus).ignoresSafeArea()

            VStack {
                TabView(selection: $pageIndex) {
                    welcomePage.tag(0)
                    howItWorksPage.tag(1)
                    buddyPage.tag(2)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(pageIndex == lastPage ? "Let's focus" : "Next") {
                    if pageIndex == lastPage {
                        finish()
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                }
                .font(.headline)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Theme.blossom))
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
        }
    }

    private var welcomePage: some View {
        infoPage(
            emoji: "🐾",
            title: "Welcome to Pawmodoro",
            message: "A cozy focus timer. Your buddy naps while you work and plays when you rest."
        )
    }

    private var howItWorksPage: some View {
        infoPage(
            emoji: "⏳",
            title: "Focus, then rest",
            message: "Work for 25 minutes, take a short break, and after four sessions enjoy a long one. Every finished session earns a paw print."
        )
    }

    private var buddyPage: some View {
        @Bindable var engine = engine

        return VStack(spacing: 24) {
            Text("Pick your buddy")
                .font(.title.bold())
                .foregroundStyle(Theme.bark)

            Picker("Buddy", selection: $engine.settings.buddy) {
                ForEach(Buddy.allCases) { buddy in
                    Text(buddy.name).tag(buddy)
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

    private func infoPage(emoji: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Text(emoji)
                .font(.system(size: 84))
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
