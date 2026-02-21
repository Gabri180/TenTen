import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabase: SupabaseManager

    var body: some View {
        if supabase.currentUser != nil {
            RoomsView()
        } else {
            LoginView()
        }
    }
}
