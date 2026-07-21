import SwiftUI
import SwiftData
import PhotosUI

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

/// Edit the profile: photo and name. No credentials — there's nothing to
/// log into; sync identity is the user's iCloud account.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("userName") private var legacyUserName = ""
    @State private var pickerItem: PhotosPickerItem?

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
        }
        .monogramWatermark()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: migrateLegacyNameIfNeeded)
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
}
