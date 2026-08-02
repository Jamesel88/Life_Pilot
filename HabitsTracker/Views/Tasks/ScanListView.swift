import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// What a scan is populating — drives every piece of copy in this view so
/// the same scanner reads correctly whether it's filling the Tasks tab, a
/// compartment box's subtasks, or the shopping list.
enum ScanKind: Equatable {
    case tasks, subtasks, shoppingItems

    var singular: String {
        switch self {
        case .tasks: "task"
        case .subtasks: "subtask"
        case .shoppingItems: "item"
        }
    }

    var headline: String {
        switch self {
        case .tasks: "Turn a photo into tasks"
        case .subtasks: "Turn a photo into subtasks"
        case .shoppingItems: "Turn a photo into a shopping list"
        }
    }

    var introDescription: String {
        switch self {
        case .tasks, .subtasks:
            "Snap or choose a photo of any written list. Items with a date — \"Dentist 20/7\", \"Mum's card by Friday\" — get scheduled; everything else lands on today."
        case .shoppingItems:
            "Snap or choose a photo of any written list — a shopping list, a note, anything with one item per line."
        }
    }

    /// Caption for lines with no recognised date.
    var undatedCaption: String {
        switch self {
        case .tasks: "Today"
        case .subtasks: "No date"
        case .shoppingItems: "Item"
        }
    }

    func reviewHeader(count: Int) -> String {
        switch self {
        case .tasks: "Tasks to add (\(count))"
        case .subtasks: "Subtasks to add (\(count))"
        case .shoppingItems: "Items to add (\(count))"
        }
    }

    var reviewFooter: String {
        "Untick anything that isn't a \(singular), and edit titles as needed."
    }
}

/// Photo-of-a-list → tasks, subtasks, or shopping items. Pick a photo,
/// on-device OCR reads the lines, each becomes a proposed item (with any
/// written date recognised where dates are relevant — lines without one
/// default to today). Review, untick strays, edit titles, then add the
/// lot in one tap.
struct ScanListView: View {
    @Environment(\.dismiss) private var dismiss

    var kind: ScanKind = .tasks
    /// Receives the ticked proposals; the caller decides what to create.
    var onConfirm: ([ListScanner.ScannedTask]) -> Void

    private enum Phase {
        case pick, processing, review, failed(String)
    }

    @State private var phase: Phase = .pick
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPhotosPicker = false
    @State private var showingCamera = false
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
            .photosPicker(isPresented: $showingPhotosPicker, selection: $pickerItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { image in
                    showingCamera = false
                    if let image {
                        process(cameraImage: image)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Phases

    private var pickView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentTasks)
            Text(kind.headline)
                .font(.headline)
            Text(kind.introDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            choosePhotoMenu {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        }
    }

    /// One entry point, two sources — offered as a pop-out menu since
    /// there's no room for two separate buttons in either layout this
    /// appears in.
    @ViewBuilder
    private func choosePhotoMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            Button {
                showingPhotosPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentTasks)
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
                            TextField(kind.singular.capitalized, text: $task.title)
                            if kind != .shoppingItems {
                                Text(dateCaption(for: task))
                                    .font(.caption)
                                    .foregroundStyle(task.matchedDate
                                                     ? Color.accentTasks : .secondary)
                            }
                        }
                        .opacity(task.isIncluded ? 1 : 0.4)
                    }
                }
            } header: {
                Text(kind.reviewHeader(count: includedCount))
            } footer: {
                Text(kind.reviewFooter)
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Nothing found", systemImage: "text.viewfinder")
        } description: {
            Text(message)
        } actions: {
            choosePhotoMenu {
                Text("Try Another Photo")
            }
        }
    }

    // MARK: - Actions

    private func process(cameraImage image: UIImage) {
        phase = .processing
        Task {
            await recognizeAndPropose(image)
        }
    }

    private func process(_ item: PhotosPickerItem) {
        phase = .processing
        pickerItem = nil
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                phase = .failed("Couldn't load that photo.")
                return
            }
            await recognizeAndPropose(image)
        }
    }

    private func recognizeAndPropose(_ image: UIImage) async {
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

    private func dateCaption(for task: ListScanner.ScannedTask) -> String {
        guard task.matchedDate || task.hasTime else { return kind.undatedCaption }
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

/// Wraps UIImagePickerController's camera source — PhotosPicker only
/// reaches the photo library, and SwiftUI has no native "take a photo"
/// view of its own.
private struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
