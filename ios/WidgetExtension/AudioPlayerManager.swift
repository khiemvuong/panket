import Foundation
import AVFoundation

class AudioPlayerManager {
    static let shared = AudioPlayerManager()
    private var player: AVAudioPlayer?

    private init() {}

    func play(url: URL) throws {
        // Dừng âm thanh đang phát (nếu có)
        stop()

        // Cấu hình Audio Session để phát nhạc nền
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)

        // Khởi tạo và phát nhạc
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
    }

    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }
}
