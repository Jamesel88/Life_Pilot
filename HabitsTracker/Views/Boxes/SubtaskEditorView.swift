import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit one subtask inside a box: title, optional due date, and
/// photo attachments. Pass `subtask: nil` to create a new one.
struct SubtaskEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let box: TaskBox
    var subtask: BoxSubtask?

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var photosData: [Data]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewerPhoto: PhotoViewerItem?

    init(box: TaskBox, subtask: BoxSubtask? = nil) {
        self.box = box
        self.subtask = subtask
        _title = State(initialValue: subtask?.title ?? "")
        _notes = State(initialValue: subtask?.notes ?? "")
        _hasDueDate = State(initialValue: subtask?.dueDate != nil)
        _dueDate = State(initialValue: subtask?.dueDate ?? .now)
        let existing = subtask?.photos.sorted { $0.createdAt < $1.createdAt } ?? []
        _photosData = State(initialValue: existing.map(\.data))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subtask") {
                    TextField("What needs doing?", text: $title)
                }

                Section("Extra info") {
                    TextField("Anything else worth noting?",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("When") {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate,
                                   displayedComponents: [.date])
                    }
                }

                Section("Photos") {
                    if !photosData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(photosData.enumerated()), id: \.offset) { index, data in
                                    photoThumbnail(data, index: index)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: 10,
                                 matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                    }
                }
            }
            .navigationTitle(subtask == nil ? "New Subtask" : "Edit Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(subtask == nil ? "Add" : "Done") {
                        save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photosData.append(data)
                        }
                    }
                    pickerItems = []
                }
            }
            .sheet(item: $viewerPhoto) { item in
                PhotoViewerSheet(data: item.data)
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ data: Data, index: Int) -> some View {
        // Decode at thumbnail size (2x for retina) — full-resolution photos
        // would otherwise each hold megabytes of decoded bitmap for a 72pt cell.
        if let image = UIImage(data: data)?
            .preparingThumbnail(of: CGSize(width: 144, height: 144)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture { viewerPhoto = PhotoViewerItem(data: data) }
                .overlay(alignment: .topTrailing) {
                    Button {
                        photosData.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                }
        }
    }

    private func save() {
        let target: BoxSubtask
        if let subtask {
            target = subtask
        } else {
            target = BoxSubtask(title: "")
            target.box = box
            modelContext.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dueDate = hasDueDate ? dueDate : nil

        // Reconcile attachments against the current selection: keep
        // unchanged photos, delete removed ones, insert only new ones —
        // so untouched image blobs aren't rewritten on every save.
        var pending = photosData
        for photo in target.photos.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let index = pending.firstIndex(of: photo.data) {
                pending.remove(at: index)
            } else {
                modelContext.delete(photo)
            }
        }
        for data in pending {
            let photo = SubtaskPhoto(data: data)
            photo.subtask = target
            modelContext.insert(photo)
        }
    }
}

struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let data: Data
}

/// Full-size view of one attached photo.
struct PhotoViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("Couldn't load photo",
                        systemImage: "photo")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
