import Foundation
import Supabase

class NetworkManager {
    
    static let shared = NetworkManager()
    
    // Configura tus credenciales reales aquí
    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tu-proyecto.supabase.co")!,
        supabaseKey: "tu-api-key-anon"
    )
    
    func sendAudioToFriend(data: Data, friendId: String) async {
        let fileName = "\(UUID().uuidString).m4a"
        
        do {
            let storageBucket = supabase.storage.from("audios")
            
            // 1. Subida del archivo
            try await storageBucket.upload(
                path: fileName,
                file: data,
                options: FileOptions(contentType: "audio/m4a")
            )

            // 2. CORRECCIÓN: Añadimos 'try' porque el método puede lanzar un error
            // Dependiendo de tu versión exacta de Supabase, usa getPublicURL o getPublicUrl
            let audioURL = try storageBucket.getPublicURL(path: fileName)
            
            // 3. Obtener el ID del usuario de forma asíncrona
            let session = try await supabase.auth.session
            let currentUserId = session.user.id.uuidString
            
            // 4. Insertar en la base de datos
            try await supabase.from("talks").insert([
                "sender_id": currentUserId,
                "receiver_id": friendId,
                "audio_url": audioURL.absoluteString
            ]).execute()
            
            print("Audio enviado con éxito")
            
        } catch {
            print("Error detallado en NetworkManager: \(error)")
        }
    }

    // Cambiamos el nombre para que coincida con MainTalkView (sin guion bajo)
    func subscribeToIncomingTalks() {
        let channel = supabase.channel("public:talks")
        
        channel.onPostgresChange(AnyAction.self, schema: "public", table: "talks") { action in
            switch action {
            case .insert(let action):
                if let audioUrlString = action.record["audio_url"] as? String,
                   let url = URL(string: audioUrlString) {
                    
                    Task {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            DispatchQueue.main.async {
                                TalkManager.shared.reportIncomingTalk(userName: "Amigo", audioData: data)
                            }
                        } catch {
                            print("Error al descargar audio: \(error)")
                        }
                    }
                }
            default:
                break
            }
        }
        
        Task {
            await channel.subscribe()
        }
    }
}
