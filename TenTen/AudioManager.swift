import SwiftUI
import AVFoundation
import Combine

class AudioManager: ObservableObject {
    @Published var isTalking = false
    static let shared = AudioManager()
    var onAudioChunk: ((Data) -> Void)?
    
    private var audioEngine: AVAudioEngine?
    private var recordingTap: AVAudioNodeTapBlock?
    private var audioPlayer: AVAudioPlayer?

    func startRecording() {
        print("🎤 Iniciando grabación")
        isTalking = true
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        recordingTap = { [weak self] (buffer: AVAudioPCMBuffer, time) in
            guard let self = self,
                  let onAudioChunk = self.onAudioChunk,
                  let channelData = buffer.floatChannelData else { return }
            
            let frameLength = Int(buffer.frameLength)
            let bytesPerSample = 4
            let totalBytes = frameLength * bytesPerSample
            
            let dataPointer = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: 4)
            defer { dataPointer.deallocate() }
            
            memcpy(dataPointer, channelData[0], totalBytes)
            
            let chunkData = Data(bytesNoCopy: dataPointer, count: totalBytes, deallocator: .none)
            onAudioChunk(chunkData)
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: recordingTap!)
        
        do {
            try audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("❌ Error iniciando audio engine: \(error)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        print("⏹️ Parando grabación")
        isTalking = false
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recordingTap = nil
    }
    
    /// Reproduce un chunk de audio recibido como Data (PCM Float32)
    func playAudioChunk(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("❌ Error reproduciendo audio chunk: \(error)")
        }
    }
    
    func playAudio(base64: String) {
        guard let data = Data(base64Encoded: base64) else {
            print("❌ Error decodificando base64 audio")
            return
        }
        playAudioChunk(data: data)
    }
}
