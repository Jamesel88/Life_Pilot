# TODO / later development

## Enable CloudKit sync

Right now the app is local-only (`ModelConfiguration` in `HabitsTrackerApp.swift`
has no `cloudKitDatabase`). To turn on cross-device sync:

1. In Xcode, select the `HabitsTracker` target → **Signing & Capabilities** →
   **+ Capability** → add **iCloud** → check **CloudKit**. This registers an
   iCloud container against your Apple Developer account and regenerates the
   entitlements file automatically — don't hand-write it, let Xcode do it.
2. In `HabitsTrackerApp.swift`, change the `sharedModelContainer`'s
   `ModelConfiguration(schema: schema)` to
   `ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)`.
3. Build once on a device signed into iCloud to confirm the container
   provisions correctly (CloudKit containers can take a few minutes to
   appear as "ready" after first creation).

Note: this was attempted once already (entitlements file + `CODE_SIGN_ENTITLEMENTS`
build setting) and reverted, because doing it outside Xcode's own capability
flow risks a code-signing failure — the entitlement has to be paired with an
Apple Developer Portal registration, which only Xcode's signed-in flow can do.

## Other things noted during the market-comparison review, not yet done

- Widgets (home/lock screen) — needs a Widget Extension target created in
  Xcode first (can't be done from the CLI/agent side); once that exists, the
  ring-based visuals here are a natural fit for a widget.
- Subtasks / checklists on tasks — user has a separate idea for this, not
  scoped yet.
