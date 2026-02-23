import SwiftUI

struct RoomsView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var rooms: [SupabaseManager.Room] = []
    @State private var newRoomName = ""
    @State private var showProfile = false
    @State private var friends: [SupabaseManager.Profile] = []
    @State private var selectedFriend: SupabaseManager.Profile?

    var body: some View {
        NavigationStack {
            List {
                // Amigos (Direct talk)
                if !friends.isEmpty {
                    Section("Amigos") {
                        ForEach(friends) { friend in
                            Button {
                                selectedFriend = friend
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarCircle(url: friend.avatarUrl, name: friend.username, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(friend.username)").font(.body)
                                        if friend.isDnd == true {
                                            Text("🌙 No molestar").font(.caption).foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "mic.fill").foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }

                // Salas grupales
                Section("Salas") {
                    HStack {
                        TextField("Nueva sala...", text: $newRoomName)
                        Button("Crear") {
                            Task {
                                try? await supabase.createRoom(name: newRoomName)
                                newRoomName = ""
                                await loadRooms()
                            }
                        }
                        .disabled(newRoomName.isEmpty)
                    }
                    ForEach(rooms) { room in
                        NavigationLink(room.name, value: room)
                    }
                }
            }
            .navigationTitle("TenTen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showProfile = true } label: {
                        AvatarCircle(
                            url: supabase.currentUser?.avatarUrl,
                            name: supabase.currentUser?.username ?? "?",
                            size: 36
                        )
                    }
                }
            }
            .navigationDestination(for: SupabaseManager.Room.self) { room in
                WalkieTalkieView(room: room).environmentObject(supabase)
            }
            .navigationDestination(item: $selectedFriend) { friend in
                DirectCallView(friend: friend).environmentObject(supabase)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView().environmentObject(supabase)
            }
            .task {
                await loadRooms()
                await loadFriends()
            }
        }
    }

    func loadRooms() async {
        rooms = (try? await supabase.fetchRooms()) ?? []
    }

    func loadFriends() async {
        friends = (try? await supabase.fetchFriends()) ?? []
    }
}
