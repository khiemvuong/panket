import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), imagePath: nil, audioPath: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = readSharedData(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readSharedData(date: Date())
        // Kế hoạch cập nhật lại timeline
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func readSharedData(date: Date) -> SimpleEntry {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.panket.app") else {
            return SimpleEntry(date: date, imagePath: nil, audioPath: nil)
        }
        let imagePath = sharedDefaults.string(forKey: "imagePath")
        let audioPath = sharedDefaults.string(forKey: "audioPath")
        return SimpleEntry(date: date, imagePath: imagePath, audioPath: audioPath)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
    let audioPath: String?
}

struct WidgetExtensionEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // Hiển thị ảnh nền
            if let imagePath = entry.imagePath,
               let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }

            VStack {
                Spacer()
                // Nút phát nhạc tương tác (iOS 17+)
                if entry.audioPath != nil {
                    Button(intent: PlayAudioIntent()) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                } else {
                    Text("No Audio")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct WidgetExtension: Widget {
    let kind: String = "WidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Panket Locket Widget")
        .description("Widget hiển thị ảnh nhóm và phát âm thanh tương tác.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
