import SwiftUI
import UIKit

/// Tab identity in one place — views navigate with `.habits`, not a magic
/// number that silently breaks when tabs are added or reordered.
enum AppTab: Hashable {
    case dashboard, tasks, boxes, habits, settings
}

/// Shared tab selection, so the custom bar can live *inside* each tab's
/// NavigationStack (safe-area insets applied outside a stack never reach
/// its scroll views — content ends up unreachable behind the bar).
@Observable
final class TabRouter {
    var selection: AppTab = .dashboard
}

struct MainTabView: View {
    @State private var router = TabRouter()

    init() {
        // The system bar is replaced by CompartmentsTabBar (the standard
        // bar can't render one item larger than the others)
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            DashboardView(tabSelection: $router.selection)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.dashboard)
            TasksView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.tasks)
            TaskBoxesView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.boxes)
            HabitsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.habits)
            SettingsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.settings)
        }
        .environment(router)
    }
}

extension View {
    /// Attach to each tab's scrollable root, inside its NavigationStack —
    /// mounts the custom tab bar as a bottom safe-area inset the scroll
    /// view actually respects.
    func compartmentsTabBar() -> some View {
        modifier(CompartmentsTabBarModifier())
    }
}

private struct CompartmentsTabBarModifier: ViewModifier {
    @Environment(TabRouter.self) private var router

    func body(content: Content) -> some View {
        @Bindable var router = router
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CompartmentsTabBar(selection: $router.selection)
            }
    }
}

/// The custom tab bar: four system-style items around the app's monogram
/// tile, which sits ~35% larger and gently raised — the bar's feature
/// button and the brand's anchor.
private struct CompartmentsTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.dashboard, symbol: "sun.max", label: "Today")
            tabButton(.tasks, symbol: "checklist", label: "Tasks")
            monogramButton
            tabButton(.habits, symbol: "repeat", label: "Habits")
            tabButton(.settings, symbol: "gearshape", label: "Settings")
        }
        .padding(.horizontal, 6)
        .padding(.top, 7)
        .padding(.bottom, 2)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tabButton(_ tab: AppTab, symbol: String, label: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 21))
                    .symbolVariant(isSelected ? .fill : .none)
                    .frame(height: 26)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var monogramButton: some View {
        let isSelected = selection == .boxes
        return Button {
            selection = .boxes
        } label: {
            VStack(spacing: 3) {
                MonogramView()
                    .frame(width: 35, height: 35)
                    .overlay(
                        RoundedRectangle(cornerRadius: 35 * 27 / 120, style: .continuous)
                            .strokeBorder(Color.accentBoxes.opacity(isSelected ? 0.9 : 0),
                                          lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                Text("Compartments")
                    .font(.system(size: 10, weight: .medium))
            }
            // The gentle raise: the plate breaks the bar's top line
            .offset(y: -8)
            .foregroundStyle(isSelected ? Color.accentBoxes : Color.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Compartments")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
