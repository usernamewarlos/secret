import SwiftUI

/// The signed-in shell: the daily prompt, your crowd-authored profile, and your people.
struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sparkles") }
            ProfileView()
                .tabItem { Label("You", systemImage: "person.crop.circle") }
            ConnectionsView()
                .tabItem { Label("People", systemImage: "person.2") }
        }
    }
}
