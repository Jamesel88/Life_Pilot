# TODO / release checklist

## CloudKit sync — code DONE, two Xcode steps remain

The schema is CloudKit-compatible (all relationships optional with proper
inverses), the bundle ID is now `com.jameslane.compartments`, and the app
group is `group.com.jameslane.compartments`. To turn sync on:

1. In Xcode select the **Life-Pilot** target → Signing & Capabilities:
   - Make sure your PAID developer team is selected under Signing (both
     targets). Automatic signing will re-register the app group.
   - **+ Capability → iCloud** → tick **CloudKit** → add container
     `iCloud.com.jameslane.compartments`.
2. In `HabitsTrackerApp.swift`, flip `cloudKitSyncEnabled` to `true`.
3. Build & run on a device signed into iCloud; give the first sync a few
   minutes. Verify data appears on a second device/simulator with the
   same Apple ID.

Note: the bundle ID change means the app installs as a NEW app on your
test devices — export a backup from the old install (Settings → Export
Backup) and import it into the new one, then delete the old app.

## Remaining before App Store submission

- [ ] Check the name "Compartments" is free in App Store Connect; create
      the app record with bundle ID com.jameslane.compartments
- [ ] Privacy policy + support URLs (privacy story: "Data Not Collected")
- [ ] `ITSAppUsesNonExemptEncryption = NO` in target build settings
- [ ] Screenshots (lead with compartment boxes + scan-a-list)
- [ ] TestFlight round with real users before public release

## Later / v1.x

- Widgets for iPad sizes; watch app
- EventKit overlay on the calendar view; NSCalendarsFullAccessUsageDescription
- Per-weekday habits and quantity goals ("8 glasses")
- AI "unpack this box" (decision pending: hosted key vs user-supplied)
- Shared lists via CloudKit sharing
- Unit-test target for date/window logic (dueBucket, anchorDate, streaks)
