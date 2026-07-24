import SwiftUI

/// A lasting reference for every feature — broader than the one-time
/// onboarding tour, since this needs to answer questions long after that
/// tour is gone. Ends with a way to replay the tour itself.
struct FAQView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showingReplayConfirmation = false

    var body: some View {
        List {
            Section("Tasks") {
                faqRow("What does quick add understand?",
                       "Type naturally — \"tomorrow\", \"friday\", \"3pm\", \"next week\" — and the date and time fill in on their own. Anything left over becomes the task's title.")
                faqRow("What does \"Mark as urgent\" do?",
                       "Urgent tasks get a red edge stripe and appear in their own banner on the Today page, above the streak. Everything else (due today, this week, this month, this year) is set from the When section.")
                faqRow("What can a task link to?",
                       "Another task, a whole compartment box, or one specific subtask inside a box — tap \"Link a task or box\" on the task's edit screen. Picking a box offers a choice between linking the whole thing or just one subtask.")
                faqRow("Can I turn a photo of a list into tasks?",
                       "Yes — tap the scan icon on the Tasks tab, choose a photo of any written list, and each line becomes a task. Lines with a date get scheduled for it; everything else lands on today.")
            }

            Section("Compartments") {
                faqRow("How do compartment boxes work?",
                       "Each subtask or linked task fills one compartment. The lid stays open while work remains and seals shut once everything inside is done.")
                faqRow("Can a subtask have its own due date or photos?",
                       "Yes — open any subtask to add a due date, notes, or photos, and to link it to tasks, boxes, or other subtasks, same as a task can.")
                faqRow("Can I scan a list straight into a box?",
                       "Yes — when creating a box, once it's named, a \"Scan a list of subtasks\" option appears; each line of the photo becomes a compartment.")
            }

            Section("Habits") {
                faqRow("How does the streak work?",
                       "Your current streak counts consecutive days where every active habit was completed. An unfinished today doesn't break it — there's still time.")
                faqRow("What do Daily, Weekly, and Monthly mean?",
                       "Daily needs a completion that day; Monthly needs one that month; Weekly needs a set number of days completed somewhere in the week, which you choose when creating the habit.")
            }

            Section("Shopping & Calendar") {
                faqRow("Where's the shopping list?",
                       "Tap the cart icon on the Tasks tab. It's deliberately simple — no dates or priorities, just add, tick off, and clear.")
                faqRow("Is there a calendar view?",
                       "Yes — the calendar icon on the Tasks tab shows a month grid with a coloured dot per day that has tasks due; tap a day to see and edit them.")
            }

            Section("Insights & Links") {
                faqRow("What's on the Insights page?",
                       "Task completions over the last 14 days, your current and best habit streaks with a week/month/year history, habit consistency over the last 30 days, and how your compartment boxes are progressing.")
                faqRow("What is the Links page?",
                       "A map of everything you've linked — tasks, boxes, and subtasks — that you can pan and pinch-zoom. Freshly linked, lightly-connected items stay near the middle; the more you link into something, the further out it spreads. Tap any item to open it.")
            }

            Section("Backup & Widgets") {
                faqRow("How do I back up my data?",
                       "In Profile & Settings, tap Export Backup to save a file to Files or iCloud Drive. After reinstalling, tap Import Backup and pick that file — this replaces everything currently in the app, so only do it right after a fresh install.")
                faqRow("Does this sync between my devices?",
                       "There's no account or server — everything stays on your device (and, once enabled, your own iCloud). Backup files are the way to move data between devices today.")
                faqRow("Are there home screen widgets?",
                       "Yes — Today's Progress (your compartment tray, shopping, and habit streak) and Compartment Boxes, in small, medium, and large sizes, plus lock screen versions of the first.")
            }

            Section {
                Button {
                    showingReplayConfirmation = true
                } label: {
                    Label("Replay the welcome tour", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .monogramWatermark()
        .navigationTitle("Help & FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Replay the welcome tour?",
               isPresented: $showingReplayConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Replay") { hasCompletedOnboarding = false }
        } message: {
            Text("Shows the first-launch walkthrough again. Nothing you've already created is affected.")
        }
    }

    @ViewBuilder
    private func faqRow(_ question: String, _ answer: String) -> some View {
        DisclosureGroup(question) {
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
