import SwiftUI
import SwiftData
import PhotosUI

/// Photo-of-a-list → tasks. Pick a photo, on-device OCR reads the lines,
/// each becomes a proposed task (with any written date recognised — lines
/// without one default to today). Review, untick strays, edit titles,
/// then add the lot in one tap.
struct ScanListView: View {
    @Environment(\.dismiss) private var dismiss

    /// Caption for lines with no recognised date — "Today" when scanning
    /// into tasks, "No date" when scanning into a compartment box.
    var undatedCaption: String = "Today"
    /// Receives the ticked proposals; the caller decides what to create.
    var onConfirm: ([ListScanner.ScannedTask]) -> Void

    private enum Phase {
        case pick, processing, review, failed(String)
    }

    @State private var phase: Phase = .pick
    @State private var pickerItem: PhotosPickerItem?
    @State private var scannedImage: UIImage?
    @State private var proposals: [ListScanner.ScannedTask] = []

    private var includedCount: Int {
        proposals.filter {
            $0.isIncluded && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .pick:
                    pickView
                case .processing:
                    ProgressView("Reading your list…")
                case .review:
                    reviewList
                case .failed(let message):
                    failedView(message)
                }
            }
            .navigationTitle("Scan a List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .review = phase {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(includedCount)") { addTasks() }
                            .disabled(includedCount == 0)
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                process(item)
            }
        }
    }

    // MARK: - Phases

    private var pickView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentTasks)
            Text("Turn a photo into tasks")
                .font(.headline)
            Text("Snap or choose a photo of any written list. Items with a date — \"Dentist 20/7\", \"Mum's card by Friday\" — get scheduled; everything else lands on today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentTasks)
        }
    }

    private var reviewList: some View {
        List {
            if let scannedImage {
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: scannedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach($proposals) { $task in
                    HStack(alignment: .top) {
                        CompletionToggleButton(isCompleted: task.isIncluded,
                                               tint: .accentTasks,
                                               itemTitle: task.title) {
                            task.isIncluded.toggle()
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            TextField("Task", text: $task.title)
                            Text(dateCaption(for: task))
                                .font(.caption)
                                .foregroundStyle(task.matchedDate
                                                 ? Color.accentTasks : .secondary)
                        }
                        .opacity(task.isIncluded ? 1 : 0.4)
                    }
                }
            } header: {
                Text("Tasks to add (\(includedCount))")
            } footer: {
                Text("Untick anything that isn't a task, and edit titles as needed.")
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Nothing found", systemImage: "text.viewfinder")
        } description: {
            Text(message)
        } actions: {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Try Another Photo")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentTasks)
        }
    }

    // MARK: - Actions

    private func process(_ item: PhotosPickerItem) {
        phase = .processing
        pickerItem = nil
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                phase = .failed("Couldn't load that photo.")
                return
            }
            scannedImage = image
            do {
                let lines = try await ListScanner.recognizeLines(in: image)
                let tasks = ListScanner.proposedTasks(from: lines)
                if tasks.isEmpty {
                    phase = .failed(ListScanner.ScanError.noText.localizedDescription)
                } else {
                    proposals = tasks
                    phase = .review
                }
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func dateCaption(for task: ListScanner.ScannedTask) -> String {
        guard task.matchedDate || task.hasTime else { return undatedCaption }
        let calendar = Calendar.current
        var caption: String
        if calendar.isDateInToday(task.dueDate) {
            caption = "Today"
        } else if calendar.isDateInTomorrow(task.dueDate) {
            caption = "Tomorrow"
        } else {
            caption = task.dueDate.formatted(.dateTime.weekday(.abbreviated).day().month())
        }
        if task.hasTime {
            caption += " at \(task.dueDate.formatted(.dateTime.hour().minute()))"
        }
        return caption
    }

    private func addTasks() {
        let included = proposals.filter {
            $0.isIncluded && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty
        }
        onConfirm(included)
        dismiss()
    }
}
