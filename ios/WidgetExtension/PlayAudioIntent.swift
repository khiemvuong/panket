import AppIntents
import Foundation

struct PlayAudioIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play Panket Audio"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        // Lấy thông tin âm thanh từ shared UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.panket.app"),
           let audioPath = sharedDefaults.string(forKey: "audioPath") {
            let audioUrl = URL(fileURLWithPath: audioPath)
            
            // Thực hiện phát âm thanh thông qua AudioPlayerManager
            try AudioPlayerManager.shared.play(url: audioUrl)
        }
        return .result()
    }
}
