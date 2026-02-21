import SwiftUI
import Supabase

struct RoomsView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var rooms: [SupabaseManager.Room] = []
    @State private var newRoomName = ""
    @State private var selectedRoom: SupabaseManager.Room?
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("Nueva sala") {
                    HStack {
                        TextField("Nombre de la sala", text: $newRoomName)
                        Button("Crear") {
                            Task {
                                try? await supabase.createRoom(name: newRoomName)
                                newRoomName = ""
                                await loadRooms()
                            }
                        }
                    }
                }

                Section("Salas") {
                    ForEach(rooms) { room in
                        NavigationLink(room.name, value: room)
                    }
                }
            }
            .navigationTitle("Salas")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Text("🎙️")
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .navigationDestination(for: SupabaseManager.Room.self) { room in
                WalkieTalkieView(room: room)
                    .environmentObject(supabase)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(supabase)
            }
            .task { await loadRooms() }
        }
    }

    func loadRooms() async {
        rooms = (try? await supabase.fetchRooms()) ?? []
    }
}
