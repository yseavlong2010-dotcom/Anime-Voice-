AnimeVoice Pro v2.0 🎙️✨
🌟 Tính năng nổi bật
1. Kiến trúc Stateful DSP: Sử dụng cấu trúc ⁠AnimeVoiceState⁠ giúp luồng âm thanh xử lý liên tục, mượt mà, không bị lạo xạo (click/pop) giữa các khung hình (frames).
2. Reverb (Độ vang không gian): Tích hợp Comb-filter Reverb giúp giọng hát/nói có chiều sâu, nghe nịnh tai và chuyên nghiệp hơn.
3. Soft Clipping (Chống rè): Tích hợp thuật toán bảo vệ Tanh-approximation giúp âm thanh không bị vỡ (distortion) khi đầu vào có cường độ quá lớn.
4. Volume Boost & Brightness EQ: Hỗ trợ tăng âm lượng đầu ra và tự động làm trong trẻo giọng nói (High-pass filter cơ bản).
5. Cấu hình Struct API linh hoạt: Dễ dàng tuỳ chỉnh thông số qua struct ⁠AnimeVoiceParams⁠.
🛠 Hướng dẫn biên dịch (Build)
Dự án có sẵn ⁠Makefile⁠ hỗ trợ biên dịch thành thư viện động (⁠.dylib⁠).
Dành cho macOS (Local Testing)
Mở terminal tại thư mục dự án và chạy:
Dành cho iOS
Hệ thống tự động sử dụng SDK của ⁠iphoneos⁠ nếu được chạy thông qua GitHub Actions, xuất ra file ⁠AnimeVoice_Pro.dylib⁠ chuẩn kiến trúc ⁠arm64⁠.
🎛 Thông số khuyên dùng (Preset: Anime Girl)
￼ ⁠pitch_shift⁠: 1.20 (Nâng tone)
￼ ⁠brightness⁠: 0.35 (Làm trong giọng)
￼ ⁠reverb_level⁠: 0.15 (Tạo độ vang nhẹ)
￼ ⁠volume_boost⁠: 1.20 (Bù đắp âm lượng)
￼ ⁠enable_soft_clip⁠: true (Luôn bật)