import Foundation
import CallKit
import AVFoundation

class TalkManager: NSObject, CXProviderDelegate {
    
    static let shared = TalkManager()
    let provider: CXProvider
    
    override init() {
        let configuration = CXProviderConfiguration(localizedName: "TenTen")
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    func reportIncomingTalk(userName: String, audioData: Data) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: userName)
        update.hasVideo = false
        
        let uuid = UUID()
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("❌ Error en CallKit: \(error.localizedDescription)")
            } else {
                print("✅ CallKit activado para \(userName). Reproduciendo...")
                AudioManager.shared.playAudioChunk(data: audioData)
            }
        }
    }
    
    func providerDidReset(_ provider: CXProvider) {}
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✅ Sesión de audio de CallKit activada.")
        } catch {
            print("❌ Error al configurar audioSession: \(error)")
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        print("📵 Comunicación finalizada.")
    }
}
