import SwiftUI
import Supabase

struct DirectCallView: View {
    let friend: SupabaseManager.Profile
    @EnvironmentObject var supabase: SupabaseManager
    @StateObject private var audio = AudioManager()
    @State private var whoIsTalking: String? = nil
    @State private var pokeMessage: String? = nil
    @State private var channel: RealtimeChannelV2?

    var channelId: String {
        let ids = [supabase.currentUser?.id ?? "", friend.id].sorted()
        return "direct:\(ids[0]):\(ids[1])"
    }

    var body: some View {
        VStack(spacing: 40) {
            VStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(Text("🎙️").font(.largeTitle))
                Text("@\(friend.username)")
                    .font(.title2.bold())
            }

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

            Button("👋 Poke") {
                Task {
                    try? await supabase.sendDirectSignal(
                        channelKey: channelId,
                        type: "poke",
                        payload: supabase.currentUser?.username ?? "Alguien"
                    )
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("@\(friend.username)")
        .task { await subscribeToChannel() }
        .onDisappear { Task { await channel?.unsubscribe() } }
    }

    func startTalking() {
        audio.onAudioChunk = { data in
            let base64 = data.base64EncodedString()
            Task {
                try? await supabase.sendDirectSignal(channelKey: channelId, type: "audio_chunk", payload: base64)
            }
        }
        audio.startRecording()
        Task {
            try? await supabase.sendDirectSignal(
                channelKey: channelId,
                type: "start_talking",
                payload: supabase.currentUser?.username
            )
        }
    }

    func stopTalking() {
        audio.stopRecording()
        Task { try? await supabase.sendDirectSignal(channelKey: channelId, type: "stop_talking") }
    }

    func subscribeToChannel() async {
        let ch = await supabase.client.realtimeV2.channel(channelId)

        let _ = await ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "signals",
            filter: "channel_key=eq.\(channelId)"
        ) { change in
            Task { @MainActor in handleSignal(record: change.record) }
        }

        await ch.subscribe()
        channel = ch
    }

    @MainActor
    func handleSignal(record: [String: AnyJSON]) {
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
