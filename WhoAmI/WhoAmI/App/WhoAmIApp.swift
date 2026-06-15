import SwiftUI

@main
struct WhoAmIApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(container.session)
                .task {
                    container.session.start()
                    await container.notifications.requestAuthorization()
                }
        }
    }
}
