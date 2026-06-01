# Kiến trúc Hệ thống & Workflow Lập trình Ứng dụng Widget Đa phương tiện (iOS First)

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)
- **Mục tiêu:** Xây dựng ứng dụng mạng xã hội thu nhỏ (giống Locket) cho nhóm 10 người. Người dùng chia sẻ ảnh tĩnh kèm âm thanh/giọng nói AI. Ảnh sẽ xuất hiện trên Home Screen Widget của bạn bè [6]. Khi bấm vào widget, âm thanh sẽ phát trực tiếp [5].
- **Nền tảng ưu tiên:** iOS 17.0+ (Sử dụng WidgetKit & AppIntents) [5].
- **Framework chính:** Flutter (UI & Logic) + Swift (Native iOS Widget) [7].
- **Chi phí (Cost):** $0 (Tận dụng Client-side processing và Serverless Free Tier) [2, 4].

## 2. KIẾN TRÚC HỆ THỐNG & TECH STACK ($0 COST STRATEGY)
- **Backend/BaaS:** Firebase (Spark Plan). 
  - *Firestore:* Lưu trữ thông tin metadata (URL ảnh, URL nhạc).
  - *Firebase Storage:* Lưu trữ tệp tin `.jpg`, `.mp3`.
  - *FCM (Firebase Cloud Messaging):* Gửi Silent Push Notification để kích hoạt widget cập nhật ngầm [1].
- **Client-side Processing:** `ffmpeg_kit_flutter_new` (Thực thi lệnh FFmpeg ngay trên thiết bị người dùng để không tốn tiền thuê server xử lý video/âm thanh) [2, 8].
- **AI Voice:** API ElevenLabs (Free Tier). Giọng Adam (ID: `OFHP1Qg30FPoNfkUFFlA`) [3].
- **Cầu nối dữ liệu (Bridge):** `home_widget` package + iOS App Group (Shared `UserDefaults`) [9].

## 3. WORKFLOW CẤU HÌNH & LẬP TRÌNH TỪNG BƯỚC (CHO AI AGENT)

### Bước 1: Khởi tạo dự án & Cấu hình iOS App Group
1. Tạo dự án Flutter mới. Cài đặt các thư viện: `home_widget`, `firebase_core`, `firebase_messaging`, `ffmpeg_kit_flutter_new`, `path_provider`, `device_preview` [2, 10].
2. Mở Xcode, thêm **Widget Extension** (đặt tên là `WidgetExtension`) [11]. Bỏ chọn "Include Live Activity" [11].
3. Trong Xcode, cấp quyền **App Groups** cho cả Target chính (Runner) và `WidgetExtension` (VD: `group.com.yourcompany.appname`) [12-14].
4. Cấu hình `home_widget` trong Flutter để nhận diện App Group ID này nhằm đồng bộ dữ liệu `UserDefaults` giữa Dart và Swift [9].

### Bước 2: Tích hợp AI Voice (ElevenLabs API)
Viết một service trong Flutter gọi API Text-to-Speech của ElevenLabs.
- **Quy tắc Agent cần tuân thủ:**
  - Endpoint: `https://api.elevenlabs.io/v1/text-to-speech/OFHP1Qg30FPoNfkUFFlA` [15].
  - Model: Bắt đầu test bằng `eleven_flash_v2_5` (để tối ưu độ trễ và chi phí), sau đó nâng lên `eleven_v3` để có độ biểu cảm cao nhất [4].
  - Payload bắt buộc cấu hình: 
    - `stability`: `0.40` (40%) [16].
    - `similarity_boost`: `0.75` (75%) [16].
    - `style`: `0.50` (50%) [16].
  - Chunking: Nếu văn bản > 500 ký tự, phải tách nhỏ mảng array để gọi API nhiều lần rồi nối lại, tránh trôi lệch cao độ [17].
  - Inline Tags: Nhúng thẻ (ví dụ: `[laughs]`, `[sigh]`) vào chuỗi string trước khi gửi [18].

### Bước 3: Client-side Media Processing (FFmpeg)
Sau khi có tệp hình ảnh (từ Camera/Gallery) và tệp âm thanh (từ ElevenLabs hoặc ghi âm), viết hàm hợp nhất (Muxing) trực tiếp trên thiết bị bằng `ffmpeg_kit_flutter_new` [2].
- **Lệnh Agent cần sử dụng để ghép (không mã hóa lại hình ảnh):**
  `ffmpeg -i input_video.mp4 -i background_audio.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest output.mp4` [8].
  *(Lưu ý: Nếu đầu vào là ảnh tĩnh, hãy lưu trữ kèm âm thanh thành 2 tệp riêng biệt để widget iOS dễ dàng xử lý phát nhạc độc lập).*

### Bước 4: Kiến trúc Giao tiếp Widget ngầm (Headless & Silent Push)
Để có trải nghiệm realtime giống Locket mà không tốn pin:
1. **Gửi Push:** Khi User A chia sẻ dữ liệu, Firebase Function hoặc App bắn một FCM *Silent Payload* (không có trường `notification`, chỉ có `data`) tới thiết bị của User B [1].
2. **Headless Isolate:** Cài đặt hàm `@pragma('vm:entry-point')` trong `main.dart` để lắng nghe FCM khi app bị đóng (Dead-App State) [19].
3. **Xử lý ngầm:** Hàm này sẽ âm thầm tải ảnh & mp3 từ Firebase Storage lưu vào Local Storage, ghi đường dẫn vào `UserDefaults` bằng lệnh `HomeWidget.saveWidgetData()` [9].
4. **Kích hoạt làm mới:** Gọi lệnh `WidgetCenter.shared.reloadAllTimelines()` (thông qua hàm update của `home_widget`) để báo iOS vẽ lại widget [1].

### Bước 5: Lập trình Native iOS Widget (Phát âm thanh từ Home Screen)
Không dùng Flutter để vẽ Widget, yêu cầu Agent viết mã Swift (SwiftUI) cho `WidgetExtension`.
1. **Giao diện:** Đọc đường dẫn ảnh từ `UserDefaults` (sử dụng chung App Group ID) và hiển thị bằng thẻ `Image()` trong SwiftUI [20].
2. **Phát nhạc (iOS 17+ AppIntents):** 
   - Không được dùng hàm phát nhạc tự động (Apple cấm). Phải tạo một nút (Button) tương tác trên Widget [5].
   - Triển khai `AppIntent` (iOS 17 Interactive Widgets). Khi người dùng nhấn nút, AppIntent chạy dưới nền, truy xuất tệp `.mp3` từ bộ nhớ dùng chung và gọi `AVAudioPlayer` gốc của hệ thống để phát nhạc [5]. Nhạc phát ngay trên Home Screen mà không mở ứng dụng [5].

## 4. QUY TẮC KIỂM THỬ (TESTING & DEBUGGING)
- **UI Testing:** Dùng package `device_preview` gói quanh `MaterialApp` để giả lập các màn hình kích thước khác nhau trực tiếp trên máy Mac [10].
- **Widget/Native Testing:** Bắt buộc chạy trên **iOS Simulator (ARM64 Native)** của Xcode trên máy Mac Apple Silicon (M1/M2/M3). Không dùng Rosetta 2 để đảm bảo FFmpeg và bộ đệm âm thanh chạy không có độ trễ [21].

*— Hết chỉ dẫn cho Agent —*
