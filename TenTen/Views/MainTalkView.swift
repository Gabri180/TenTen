import SwiftUI

struct MainTalkView: View {
    @State private var isRecording = false
    let friendId = "ID_DE_TU_AMIGO_AQUÍ"

    var body: some View {
        VStack(spacing: 50) {
            Text(isRecording ? "¡Te están escuchando!" : "Mantén para hablar")
                .font(.headline)
                .foregroundColor(isRecording ? .red : .primary)

            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)

                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                        .padding(40)
                        .background(isRecording ? Color.red : Color.blue)
                        .clipShape(Circle())
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isRecording { startTalking() }
                        }
                        .onEnded { _ in
                            stopTalking()
                        }
                )
            }
        }
        .onAppear {
            // Configuramos el callback para enviar cada chunk de audio al amigo
            AudioManager.shared.onAudioChunk = { audioData in
                Task {
                    await NetworkManager.shared.sendAudioToFriend(data: audioData, friendId: friendId)
                }
            }
            NetworkManager.shared.subscribeToIncomingTalks()
        }
    }

    func startTalking() {
        isRecording = true
        AudioManager.shared.startRecording()
    }

    func stopTalking() {
        isRecording = false
        AudioManager.shared.stopRecording()
    }
}
