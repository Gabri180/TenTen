import SwiftUI
import CoreImage.CIFilterBuiltins
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @State private var friendUsername = ""
    @State private var friends: [SupabaseManager.Profile] = []
    @State private var message = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isDND: Bool = false

    var userId: String { supabase.currentUser?.id ?? "..." }
    var username: String { supabase.currentUser?.username ?? "..." }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Avatar + foto
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            AvatarCircle(
                                url: supabase.currentUser?.avatarUrl,
                                name: username,
                                size: 90
                            )
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .foregroundColor(.white),
                                alignment: .bottomTrailing
                            )
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task { await uploadPhoto(item: item) }
                        }

                        Text("@\(username)").font(.title2.bold())

                        Text(userId)
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: 260)

                        Button {
                            UIPasteboard.general.string = userId
                            message = "ID copiado ✅"
                        } label: {
                            Label("Copiar ID", systemImage: "doc.on.doc").font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top)

                    Divider()

                    // Toggle No Molestar
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $isDND) {
                            Label("No molestar 🌙", systemImage: "moon.fill")
                        }
                        .onChange(of: isDND) { _, val in
                            Task { try? await supabase.setDND(active: val) }
                        }
                        Text("Tus amigos verán que estás en modo no molestar")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Divider()

                    // QR
                    VStack(spacing: 8) {
                        Image(uiImage: generateQR(from: userId))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 4)
                        Text("Muestra este QR para que te añadan")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Divider()

                    // Añadir amigo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Añadir amigo").font(.headline)
                        HStack {
                            TextField("Usuario o ID", text: $friendUsername)
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

                    // Lista amigos
                    VStack(alignment: .leading) {
                        Text("Amigos (\(friends.count))").font(.headline).padding(.horizontal)
                        ForEach(friends) { friend in
                            HStack(spacing: 12) {
                                AvatarCircle(url: friend.avatarUrl, name: friend.username, size: 36)
                                VStack(alignment: .leading) {
                                    Text("@\(friend.username)")
                                    if friend.isDnd == true {
                                        Text("🌙 No molestar").font(.caption).foregroundColor(.orange)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Mi perfil")
            .task {
                await loadFriends()
                isDND = supabase.currentUser?.isDnd ?? false
            }
        }
    }

    func uploadPhoto(item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        _ = try? await supabase.uploadAvatar(image: image)
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
            message = "Usuario no encontrado ❌"; return
        }
        guard found.id != supabase.currentUser?.id else {
            message = "No puedes añadirte a ti mismo 😅"; return
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
