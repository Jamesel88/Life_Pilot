# TODO / release checklist

## Fast path: get into TestFlight

Code-side blockers are cleared. What's left is App Store Connect / Xcode
steps only I can't click through for you:

1. **Create the app record** in App Store Connect (appstoreconnect.apple.com)
   → My Apps → + → New App:
   - Bundle ID `com.jameslane.compartments` (register it in the Apple
     Developer portal first if it's not listed yet — Certificates,
     Identifiers & Profiles → Identifiers → +)
   - Check the name **"Compartments"** is available while you're there
   - Platform: iOS
2. **Archive**: in Xcode, select the **Life-Pilot** scheme → any real
   device or "Any iOS Device (arm64)" as the destination (archiving
   needs a device destination, not a simulator) → Product → Archive.
3. **Upload**: when the archive finishes, the Organizer opens →
   Distribute App → App Store Connect → Upload. Automatic signing should
   just work since your paid team is selected.
4. **TestFlight tab** in App Store Connect: once processing finishes
   (usually 15–60 min), add yourself under **Internal Testing** first —
   no review needed, available almost immediately. Add external testers
   later; that path needs a short Beta App Review (lighter than full
   App Store review, usually within a day).

### Fixed this session (were going to block the archive/upload)

- ~~macOS listed as a supported destination~~ — removed. The app is
  built entirely on UIKit (UIColor, UIImage, UIApplication), which
  doesn't exist on native macOS — that's what caused the 10-error
  macOS archive failure in App Store Connect. iOS and visionOS both
  have UIKit, which is why only those two succeeded. Mac support would
  need a real AppKit-compatibility pass later if you ever want it.
- ~~App Store icon had an alpha channel~~ — `icon-1024.png` (the
  default/"any" appearance icon used for the App Store listing) is
  re-saved as RGB with no alpha. Apple's validator hard-rejects any
  transparency on that specific icon slot, even fully-opaque RGBA.
  The dark/tinted home-screen variants correctly keep transparency —
  Apple's icon system supplies their backdrop itself.
- ~~Export compliance question~~ — added
  `ITSAppUsesNonExemptEncryption = NO` to the app target, since it only
  uses standard HTTPS/system crypto. Skips the encryption
  questionnaire on every submission.

## CloudKit sync — code done, two Xcode steps remain

The schema is CloudKit-compatible (all relationships optional with
proper inverses), bundle ID `com.jameslane.compartments`, app group
`group.com.jameslane.compartments`.

1. Life-Pilot target → Signing & Capabilities:
   - Paid team selected under Signing (both targets — automatic signing
     re-registers the app group)
   - **+ Capability → iCloud** → tick **CloudKit** → add container
     `iCloud.com.jameslane.compartments`
2. Flip `cloudKitSyncEnabled` to `true` in `HabitsTrackerApp.swift`
3. Build & run on a device signed into iCloud; confirm data appears on
   a second device/simulator with the same Apple ID

Note: the bundle ID change means the app installs as a NEW app on your
test devices — export a backup from the old install (Settings → Export
Backup) and import it into the new one, then delete the old app.

## Before public App Store release (not required for TestFlight)

- [ ] Privacy policy + support URLs (privacy story: "Data Not Collected")
- [ ] Screenshots (lead with compartment boxes + scan-a-list)
- [ ] A TestFlight round with real users, acting on their feedback

## AI agent — "I'm moving house, create me a compartment for the house
move"

Scoped, not built. Same shape as the photo list-scanner (Claude
proposes a subtask list, user reviews/edits/ticks off items before
anything is created) but from a typed description instead of a photo.
Needs one decision before building, since it changes cost and privacy:

- **Hosted key** (recommended): you run a small proxy holding an
  Anthropic API key; cost scales with usage across all users; works
  out of the box for everyone — what people expect from a paid app.
- **User-supplied key**: free to run, no server; each user pastes their
  own Anthropic API key into Settings; real friction for non-technical
  users, most won't set it up.
- **Stub first**: build the whole UX (prompt field, review screen,
  compartment creation) against a mock response now, wire in the real
  call once the hosting decision is made.

Revisit after TestFlight is underway.

## Later / v1.x

- Widgets for iPad sizes
- Apple Watch complications — WidgetKit runs on watchOS too, so the
  existing ring/tray widget code and App Group snapshot bridge are
  largely reusable. Needs a Watch App target created in Xcode's UI
  first (File → New → Target → Watch App) — same constraint as the
  original iPhone widget target, can't be hand-added to the project
  file safely. Once that target exists, build the complications against
  the existing snapshot format.
- EventKit overlay on the calendar view; NSCalendarsFullAccessUsageDescription
- Per-weekday habits and quantity goals ("8 glasses")
- Shared lists via CloudKit sharing
- Unit-test target for date/window logic (dueBucket, anchorDate, streaks)
- More Siri/Shortcuts via App Intents — `HabitIntents.swift` already
  exposes "Log [habit]" to Siri and Shortcuts; extend the same pattern
  to quick-add a task (reuse the quick-add date parser), mark a task
  done by name, and add a shopping list item. No new capability needed.
  Start with one or two, not all at once.
