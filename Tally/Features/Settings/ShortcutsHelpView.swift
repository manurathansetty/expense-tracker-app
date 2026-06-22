import SwiftUI

/// Step-by-step guide for wiring up message capture. iOS forbids silently
/// reading the inbox, so capture is opt-in via a Shortcuts automation or the
/// share sheet — both fully on-device.
struct ShortcutsHelpView: View {
    var body: some View {
        List {
            Section {
                Text("iOS doesn't let any app read your messages in the background. Instead, you tell Apple's Shortcuts app to hand bank/UPI texts to π. Set it up once and it runs itself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Automatic (recommended)") {
                Step(number: 1, text: "Open the **Shortcuts** app → **Automation** tab → **＋**.")
                Step(number: 2, text: "Choose **Message** as the trigger.")
                Step(number: 3, text: "Set **Message Contains** → add words like *debited*, *spent*, *UPI*, *credited*.")
                Step(number: 4, text: "Turn on **Run Immediately** (or leave **Ask Before Running** for a confirmation).")
                Step(number: 5, text: "Add action **Log Transaction** (from π) and pass it the **Shortcut Input** (the message text).")
                Step(number: 6, text: "Done. Matching texts now log themselves into π.")
            }

            Section("Manual (anytime)") {
                Step(number: 1, text: "In **Messages**, select the transaction text.")
                Step(number: 2, text: "Tap **Share** → choose **Add to π**.")
                Step(number: 3, text: "π pre-fills the amount and merchant — confirm to save.")
            }

            Section {
                Label("Everything is parsed and stored on your device. Nothing is sent anywhere.",
                      systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Auto-add from messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(DS.accent))
            Text(.init(text))
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
