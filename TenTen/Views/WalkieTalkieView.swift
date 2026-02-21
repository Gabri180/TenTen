import SwiftUI
import Supabase

struct WalkieTalkieView: View {
    let room: SupabaseManager.Room
    @EnvironmentObject var supabase: SupabaseManager
    @StateObject private var audio = AudioManager()
    @State private var whoIsTalking: String? = nil
    @State private var pokeMessage: String? = nil
    @State private var channel: RealtimeChannelV2?

    var body: some View {
        VStack(spacing: 40) {
            Text(room.name)
                .font(.title.bold())

            if let who = whoIsTalking {
                Text("🎙️ \(who) está hablando...")
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }

            if let poke = pokeMessage {
                Text(poke)
                    .foregroundColor(.blue)
                    .transition(.opacity)
            }

            Circle()
                .fill(audio.isTalking ? Color.red : Color.green)
                .frame(width: 140, height: 140)
                .overlay(
                    Text(audio.isTalking ? "🔴 Suelta" : "🎙️ Pulsa")
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !audio.isTalking { startTalking() } }
                        .onEnded { _ in stopTalking() }
                )

            Button("👋 Poke a la sala") {
                Task {
                    try? await supabase.sendSignal(
                        roomId: room.id,
                        type: "poke",
                        payload: supabase.currentUser?.username ?? "Alguien"
                    )
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle(room.name)
        .task { await subscribeToRoom() }
        .onDisappear { Task { await channel?.unsubscribe() } }
    }

    func startTalking() {
        print("🟢 startTalking llamado")
        audio.onAudioChunk = { data in
            let base64 = data.base64EncodedString()
            print("📤 Enviando chunk a Supabase: \(data.count) bytes")
            Task { try? await supabase.sendSignal(roomId: room.id, type: "audio_chunk", payload: base64) }
        }
        audio.startRecording()
        Task {
            try? await supabase.sendSignal(
                roomId: room.id,
                type: "start_talking",
                payload: supabase.currentUser?.username
            )
        }
    }

    func stopTalking() {
        audio.stopRecording()
        Task { try? await supabase.sendSignal(roomId: room.id, type: "stop_talking") }
    }

    func subscribeToRoom() async {
        let ch = await supabase.client.realtimeV2.channel("room:\(room.id.uuidString)")

        let _ = await ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "signals",
            filter: "room_id=eq.\(room.id.uuidString)"
        ) { change in
            Task { @MainActor in handleSignal(record: change.record) }
        }

        await ch.subscribe()
        channel = ch
    }

    @MainActor
    func handleSignal(record: [String: AnyJSON]) {
        print("📥 Signal recibida: \(record["type"] ?? "nil")")
        guard let typeVal = record["type"], case .string(let type) = typeVal else { return }
        let myId = supabase.currentUser?.id
        var senderId: String? = nil
        if let s = record["sender_id"], case .string(let sid) = s { senderId = sid }
        if type == "audio_chunk" && senderId == myId { return }
        var payload: String? = nil
        if let p = record["payload"], case .string(let pv) = p { payload = pv }

        switch type {
        case "audio_chunk":
            if let p = payload { audio.playAudio(base64: p) }
        case "start_talking":
            withAnimation { whoIsTalking = payload }
        case "stop_talking":
            withAnimation { whoIsTalking = nil }
        case "poke":
            withAnimation { pokeMessage = "👋 \(payload ?? "Alguien") te ha pokeado" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { pokeMessage = nil }
            }
        default: break
        }
    }
}
