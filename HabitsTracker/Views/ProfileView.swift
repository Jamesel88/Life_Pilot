import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import UserNotifications

enum AppAppearance: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Minimal FileDocument wrapper so the backup JSON can go through the
/// system "Save to Files" exporter.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// The avatar wherever the profile appears: photo if set, otherwise
/// initials on the brand tan, otherwise a person glyph.
struct AvatarView: View {
    var profile: UserProfile?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = profile?.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials = profile?.initials, !initials.isEmpty {
                Color.accentBoxes.opacity(0.25)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .semibold,
                                          design: .rounded))
                            .foregroundStyle(Color.accentBoxes)
                    )
            } else {
                Color.accentBoxes.opacity(0.18)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.45))
                            .foregroundStyle(Color.accentBoxes)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Profile and settings in one place, reached from the avatar button in
/// the Today page's top corner — no separate tab. No credentials either:
/// there's nothing to log into, since sync identity is the user's own
/// iCloud account.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("userName") private var legacyUserName = ""
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark
    @State private var pickerItem: PhotosPickerItem?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    // Back up & restore state
    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: BackupFile?
    @State private var restoreSummary: BackupService.Summary?
    @State private var backupErrorMessage: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    AvatarView(profile: profile, size: 96)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(profile?.photoData == nil ? "Add Photo" : "Change Photo")
                            .font(.subheadline)
                    }
                    if profile?.photoData != nil {
                        Button("Remove Photo", role: .destructive) {
                            profile?.photoData = nil
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Your name", text: nameBinding)
                    .textContentType(.name)
            } footer: {
                Text("Used for the greeting on your Today page. Your profile never leaves your device and iCloud — there's no account and nothing to sign into.")
            }

            Section {
                NavigationLink {
                    FAQView()
                } label: {
                    Label("Help & FAQ", systemImage: "questionmark.circle")
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Notifications") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(notificationStatusLabel)
                        .foregroundStyle(.secondary)
                }
                if notificationStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else if notificationStatus == .notDetermined {
                    Button("Enable Notifications") {
                        NotificationManager.requestPermission()
                        refreshNotificationStatus()
                    }
                }
            }

            Section {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup…", systemImage: "square.and.arrow.up")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Backup…", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Back up & restore")
            } footer: {
                Text("Save a backup file to Files or iCloud Drive before deleting the app, then import it after reinstalling. Importing replaces everything currently in the app.")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .monogramWatermark()
        .navigationTitle("Profile & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: migrateLegacyNameIfNeeded)
        .task {
            refreshNotificationStatus()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                // Store a sensible avatar size, not a 12MP original
                let resized = image.preparingThumbnail(
                    of: CGSize(width: 512, height: 512))
                ensureProfile().photoData = resized?.pngData() ?? data
            }
        }
        .fileExporter(isPresented: $showingExporter,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: backupFilename) { result in
            if case .failure(let error) = result {
                backupErrorMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                readBackup(at: url)
            case .failure(let error):
                backupErrorMessage = error.localizedDescription
            }
        }
        .alert("Replace all current data?",
               isPresented: Binding(get: { pendingRestore != nil },
                                    set: { if !$0 { pendingRestore = nil } })) {
            Button("Cancel", role: .cancel) { pendingRestore = nil }
            Button("Restore", role: .destructive) { applyPendingRestore() }
        } message: {
            if let backup = pendingRestore {
                Text("This backup from \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)) contains \(backup.tasks.count) tasks, \(backup.habits.count) habits, \(backup.boxes.count) boxes and \(backup.groups.count) groups. Everything currently in the app will be deleted first.")
            }
        }
        .alert("Backup restored",
               isPresented: Binding(get: { restoreSummary != nil },
                                    set: { if !$0 { restoreSummary = nil } })) {
            Button("OK") { restoreSummary = nil }
        } message: {
            if let summary = restoreSummary {
                Text("Restored \(summary.tasks) tasks, \(summary.habits) habits, \(summary.boxes) boxes and \(summary.groups) groups.")
            }
        }
        .alert("Backup problem",
               isPresented: Binding(get: { backupErrorMessage != nil },
                                    set: { if !$0 { backupErrorMessage = nil } })) {
            Button("OK") { backupErrorMessage = nil }
        } message: {
            Text(backupErrorMessage ?? "")
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { profile?.name ?? "" },
            set: { ensureProfile().name = $0 }
        )
    }

    @discardableResult
    private func ensureProfile() -> UserProfile {
        if let profile { return profile }
        let created = UserProfile(name: "")
        modelContext.insert(created)
        return created
    }

    /// Users from before profiles existed had a Settings name field —
    /// carry it over once
    private func migrateLegacyNameIfNeeded() {
        if profile == nil, !legacyUserName.trimmingCharacters(in: .whitespaces).isEmpty {
            modelContext.insert(UserProfile(name: legacyUserName))
        }
    }

    // MARK: - Back up & restore

    private var backupFilename: String {
        "Compartments Backup \(Date.now.formatted(.iso8601.year().month().day()))"
    }

    private func exportBackup() {
        do {
            exportDocument = BackupDocument(data: try BackupService.makeBackupData(context: modelContext))
            showingExporter = true
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func readBackup(at url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingRestore = try BackupService.decode(try Data(contentsOf: url))
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func applyPendingRestore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        do {
            restoreSummary = try BackupService.restore(backup, context: modelContext)
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        case .notDetermined: "Not set"
        @unknown default: "Unknown"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
}
