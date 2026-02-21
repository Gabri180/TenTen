import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var friendUsername = ""
    @State private var friends: [SupabaseManager.Profile] = []
    @State private var message = ""
    @State private var selectedFriend: SupabaseManager.Profile?

    var userId: String { supabase.currentUser?.id ?? "..." }
    var username: String { supabase.currentUser?.username ?? "..." }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(uiImage: generateQR(from: userId))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(radius: 4)

                    Text("@\(username)")
                        .font(.headline)

                    Text(userId)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 260)

                    Button {
                        UIPasteboard.general.string = userId
                        message = "ID copiado ✅"
                    } label: {
                        Label("Copiar ID", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Añadir amigo").font(.headline)
                    HStack {
                        TextField("Nombre de usuario o ID", text: $friendUsername)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                        Button("Añadir") {
                            Task { await addFriend() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(friendUsername.isEmpty)
                    }
                    if !message.isEmpty {
                        Text(message).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                Divider()

                VStack(alignment: .leading) {
                    Text("Amigos (\(friends.count))").font(.headline).padding(.horizontal)
                    if friends.isEmpty {
                        Text("Aún no tienes amigos añadidos")
                            .foregroundColor(.secondary).font(.caption).padding(.horizontal)
                    } else {
                        List(friends) { friend in
                            Button {
                                selectedFriend = friend
                            } label: {
                                HStack {
                                    Circle().fill(Color.green).frame(width: 10, height: 10)
                                    Text("@\(friend.username)")
                                    Spacer()
                                    Image(systemName: "mic.fill").foregroundColor(.orange)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Mi perfil")
            .task { await loadFriends() }
            .navigationDestination(item: $selectedFriend) { friend in
                DirectCallView(friend: friend)
            }
        }
    }

    func generateQR(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        if let output = filter.outputImage,
           let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage()
    }

    func addFriend() async {
        message = ""
        guard let found = try? await supabase.findUser(byCode: friendUsername) else {
            message = "Usuario no encontrado ❌"
            return
        }
        guard found.id != supabase.currentUser?.id else {
            message = "No puedes añadirte a ti mismo 😅"
            return
        }
        do {
            try await supabase.addFriend(friendId: found.id)
            message = "@\(found.username) añadido ✅"
            friendUsername = ""
            await loadFriends()
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
    }

    func loadFriends() async {
        friends = (try? await supabase.fetchFriends()) ?? []
    }
}
