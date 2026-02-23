import SwiftUI

@main
struct TenTenApp: App {
    @StateObject var supabase = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabase)
                .task { await supabase.loadExistingUser() }
        }
    }
}
