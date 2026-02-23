import Supabase
import Foundation
import Combine
import UIKit

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    @Published var currentUser: AppUser?

    struct AppUser: Codable, Identifiable {
        let id: String
        let username: String
        var avatarUrl: String?
        var isDnd: Bool?
        enum CodingKeys: String, CodingKey {
            case id, username
            case avatarUrl = "avatar_url"
            case isDnd = "is_dnd"
        }
    }

    struct Room: Codable, Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    struct Profile: Codable, Identifiable, Hashable {
        let id: String
        let username: String
        var avatarUrl: String?
        var isDnd: Bool?
        enum CodingKeys: String, CodingKey {
            case id, username
            case avatarUrl = "avatar_url"
            case isDnd = "is_dnd"
        }
    }

    func loadOrCreateUser(username: String) async throws {
        let key = "tenten_user_id"
        let userId: String
        if let saved = UserDefaults.standard.string(forKey: key) {
            userId = saved
        } else {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: key)
        }
        try await client.from("users")
            .upsert(["id": userId, "username": username])
            .execute()
        let users: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        currentUser = users.first
    }

    func loadExistingUser() async {
        guard let userId = UserDefaults.standard.string(forKey: "tenten_user_id") else { return }
        let users: [AppUser] = (try? await client.from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value) ?? []
        currentUser = users.first
    }

    func uploadAvatar(image: UIImage) async throws -> String {
        guard let userId = currentUser?.id,
              let data = image.jpegData(compressionQuality: 0.7) else { return "" }
        let path = "\(userId)/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path: path,
            file: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let url = try client.storage.from("avatars").getPublicURL(path: path)
        // Guardar en DB
        try await client.from("users")
            .update(["avatar_url": url.absoluteString])
            .eq("id", value: userId)
            .execute()
        // Refrescar usuario local
        var updated = currentUser
        updated?.avatarUrl = url.absoluteString
        currentUser = updated
        return url.absoluteString
    }

    func setDND(active: Bool) async throws {
        guard let userId = currentUser?.id else { return }
        try await client.from("users")
            .update(["is_dnd": active])
            .eq("id", value: userId)
            .execute()
        var updated = currentUser
        updated?.isDnd = active
        currentUser = updated
    }

    func fetchRooms() async throws -> [Room] {
        return try await client.from("rooms").select().execute().value
    }

    func createRoom(name: String) async throws {
        guard let uid = currentUser?.id else { return }
        try await client.from("rooms")
            .insert(["name": name, "created_by": uid])
            .execute()
    }

    func joinRoom(roomId: UUID) async throws {
        guard let uid = currentUser?.id else { return }
        try await client.from("room_members")
            .upsert(["room_id": roomId.uuidString, "user_id": uid])
            .execute()
    }

    func sendSignal(roomId: UUID, type: String, payload: String? = nil) async throws {
        guard let uid = currentUser?.id else { return }
        var body: [String: String] = [
            "room_id": roomId.uuidString,
            "sender_id": uid,
            "type": type
        ]
        if let payload { body["payload"] = payload }
        try await client.from("signals").insert(body).execute()
    }

    func sendDirectSignal(channelKey: String, type: String, payload: String? = nil) async throws {
        guard let uid = currentUser?.id else { return }
        var body: [String: String] = [
            "room_id": "00000000-0000-0000-0000-000000000000",
            "sender_id": uid,
            "type": type,
            "channel_key": channelKey
        ]
        if let payload { body["payload"] = payload }
        try await client.from("signals").insert(body).execute()
    }

    func findUser(byCode code: String) async throws -> Profile? {
        let users: [Profile] = try await client.from("users")
            .select()
            .or("id.eq.\(code),username.eq.\(code)")
            .execute()
            .value
        return users.first
    }

    func addFriend(friendId: String) async throws {
        guard let myId = currentUser?.id else { return }
        try await client.from("friends")
            .upsert([
                ["user_id": myId, "friend_id": friendId],
                ["user_id": friendId, "friend_id": myId]
            ])
            .execute()
    }

    func fetchFriends() async throws -> [Profile] {
        guard let myId = currentUser?.id else { return [] }
        struct FriendRow: Codable {
            let friendId: String
            enum CodingKeys: String, CodingKey { case friendId = "friend_id" }
        }
        let rows: [FriendRow] = try await client.from("friends")
            .select("friend_id")
            .eq("user_id", value: myId)
            .execute()
            .value
        var result: [Profile] = []
        for row in rows {
            let users: [Profile] = try await client.from("users")
                .select()
                .eq("id", value: row.friendId)
                .execute()
                .value
            result.append(contentsOf: users)
        }
        return result
    }
}
