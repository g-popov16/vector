import SwiftUI

@main
struct VectorApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).preferredColorScheme(.dark)
                .task { await store.refreshIfConnected() }
        }
    }
}
