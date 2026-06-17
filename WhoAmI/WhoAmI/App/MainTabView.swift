import SwiftUI

/// The signed-in shell — a fully CUSTOM glass tab bar copied from the design
/// prototype. (Apple's `UITabBar` couldn't match it reliably: `.tabItem` images
/// don't react to selection, and `UITabBar.appearance()` set in `init()` often
/// no-ops.) This bar is plain SwiftUI, so it always reflects the design and
/// updates on tap.
///
/// Four tabs, each its own nav stack, kept alive once visited so tab state
/// persists. Selected tab = FILLED glyph in tangerine; others = OUTLINE glyph in
/// text-faint. Bold ~10.5pt labels; dark glass blur with a hairline top separator.
struct MainTabView: View {
    @AppStorage("gv.selectedTab") private var tab: AppTab = .today
    @State private var visited: Set<AppTab> = [.today]

    var body: some View {
        ZStack {
            pane(.today)    { TodayView() }
            pane(.people)   { ConnectionsView() }
            pane(.activity) { ActivityView() }
            pane(.you)      { NavigationStack { ProfileView() } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GrapevineTabBar(selection: $tab)
        }
        .onChange(of: tab) { _, newTab in visited.insert(newTab) }
        .onAppear { visited.insert(tab) }   // render the restored tab on launch
    }

    /// Render a tab only once visited (lazy first load), then keep it alive +
    /// hidden when another tab is active (so its nav/scroll state persists).
    @ViewBuilder
    private func pane<Content: View>(_ which: AppTab, @ViewBuilder _ content: () -> Content) -> some View {
        if visited.contains(which) {
            content()
                .opacity(tab == which ? 1 : 0)
                .allowsHitTesting(tab == which)
                .zIndex(tab == which ? 1 : 0)
        }
    }
}

/// The four root tabs, with their design glyphs (Phosphor → SF Symbol).
enum AppTab: Int, CaseIterable, Identifiable {
    case today, people, activity, you

    var id: Self { self }

    var label: String {
        switch self {
        case .today:    return "Today"
        case .people:   return "People"
        case .activity: return "Activity"
        case .you:      return "You"
        }
    }

    /// Outline glyph (inactive). ph-house · ph-users-three · ph-bell · ph-user.
    var icon: String {
        switch self {
        case .today:    return "house"
        case .people:   return "person.3"
        case .activity: return "bell"
        case .you:      return "person"
        }
    }

    /// Filled glyph (active).
    var filledIcon: String { icon + ".fill" }
}

/// The bar itself: justified row of four items over a dark glass blur, a 1px top
/// separator, and a glass fill that extends down into the home-indicator area.
private struct GrapevineTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = selection == tab
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: active ? tab.filledIcon : tab.icon)
                            .font(.system(size: 24, weight: active ? .semibold : .regular))
                            .frame(height: 26)
                        Text(tab.label)
                            .font(BrandFont.hanken(10.5, .bold))
                    }
                    .foregroundStyle(active ? Theme.primary : Theme.textFaint)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
