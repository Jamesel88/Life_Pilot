import SwiftUI
import SwiftData
import UIKit
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

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appAppearance") private var appearance: AppAppearance = .dark
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    // Back up & restore state
    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: BackupFile?
    @State private var restoreSummary: BackupService.Summary?
    @State private var backupErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Settings")
        }
        .task {
            refreshNotificationStatus()
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
