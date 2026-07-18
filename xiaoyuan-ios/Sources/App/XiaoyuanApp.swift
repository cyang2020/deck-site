import SwiftUI
import SwiftData

@main
struct XiaoyuanApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(AllModels.schema))
        } catch {
            fatalError("ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            GardenRootView()   // Features/Garden 提供
        }
        .modelContainer(container)
    }
}
