import SwiftUI

/// The Tasks tab's single corner menu: a scrim + sliding sidebar replacing
/// what used to be four separate toolbar icons (view filter, edit groups,
/// scan, calendar, shopping). Each destination gets its own row with a
/// one-line description instead of being guessed from an icon alone.
struct TasksMenuOverlay: View {
    @Binding var isPresented: Bool
    @Binding var filter: TaskFilter
    var onScanList: () -> Void
    var onCalendar: () -> Void
    var onShopping: () -> Void
    var onEditGroups: () -> Void

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { close() }

                sidebar
                    .frame(width: min(geo.size.width * 0.78, 320))
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .shadow(color: .black.opacity(0.3), radius: 18, x: 8, y: 0)
                    .transition(.move(edge: .leading))
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menu")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.systemGray5), in: Circle())
                    }
                    .accessibilityLabel("Close menu")
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

                sectionHeader("View")
                ForEach(TaskFilter.allCases, id: \.self) { option in
                    MenuRow(systemImage: option.systemImage,
                            title: option.rawValue,
                            subtitle: option.description,
                            isSelected: filter == option,
                            showsCheckmark: true) {
                        filter = option
                        close()
                    }
                }

                sectionHeader("Tools")
                    .padding(.top, 10)
                MenuRow(systemImage: "camera.viewfinder", title: "Add by camera",
                        subtitle: "Scan a written list and add each line as a task") {
                    onScanList()
                    close()
                }
                MenuRow(systemImage: "calendar", title: "Calendar view",
                        subtitle: "See what's due, laid out on a month grid") {
                    onCalendar()
                    close()
                }
                MenuRow(systemImage: "cart", title: "Shopping list",
                        subtitle: "A simple separate list for things to buy") {
                    onShopping()
                    close()
                }
                MenuRow(systemImage: "pencil", title: "Edit groups",
                        subtitle: "Rename or recolour your groups") {
                    onEditGroups()
                    close()
                }

                Spacer(minLength: 24)

                MonogramView()
                    .frame(width: 64, height: 64)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }
}

private struct MenuRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var isSelected: Bool = false
    var showsCheckmark: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17))
                    .frame(width: 22)
                    .foregroundStyle(showsCheckmark && isSelected ? Color.accentTasks : .secondary)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        if showsCheckmark && isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.accentTasks)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
