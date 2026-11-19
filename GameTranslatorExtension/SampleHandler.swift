import ReplayKit
import UserNotifications

/// Lớp chính nhận các luồng khung hình từ hệ điều hành iOS khi người dùng đang chơi game
class SampleHandler: RPBroadcastSampleHandler {
    private let throttler = FrameThrottler()
    private let ocrService = OCRService()
    private let translationService = TranslationService()
    
    // Khóa tránh chạy đồng thời 2 lần OCR gây quá tải và tràn RAM
    private var isProcessing = false
    private let processingQueue = DispatchQueue(label: "com.gametranslator.extension.queue", qos: .userInitiated)

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        throttler.reset()
        print("[SampleHandler] Đã bắt đầu truyền phát màn hình game.")
    }

    override func broadcastPaused() {
        print("[SampleHandler] Đã tạm dừng truyền phát.")
    }

    override func broadcastResumed() {
        print("[SampleHandler] Tiếp tục truyền phát.")
    }

    override func broadcastFinished() {
        throttler.reset()
        print("[SampleHandler] Kết thúc truyền phát.")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            handleVideoBuffer(sampleBuffer)
        case .audioApp, .audioMic:
            // Bỏ qua luồng âm thanh để giải phóng CPU và tránh tiêu hao năng lượng
            break
        @unknown default:
            break
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Kiểm tra xem người dùng có đang bật dịch trong cài đặt không
        guard AppSettings.isServiceEnabled else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()
        let interval = AppSettings.scanInterval

        // Bước 1: Throttling thời gian (chỉ xử lý sau mỗi N giây, mặc định 2.0s)
        guard throttler.shouldProcess(currentTime: currentTime, interval: interval) else {
            return
        }

        // Bước 2: Kiểm tra cờ xử lý - Nếu tác vụ trước chưa xong thì bỏ qua frame này ngay
        guard !isProcessing else { return }
        isProcessing = true

        // Bước 3: Đưa vào queue riêng và bọc toàn bộ bằng autoreleasepool để giải phóng RAM ngay lập tức
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                defer {
                    self.isProcessing = false
                }

                // Trích xuất CVPixelBuffer từ CMSampleBuffer
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }

                // Bước 4: Kiểm tra nhanh biến động màn hình (nếu ảnh tĩnh không đổi thì bỏ qua)
                guard self.throttler.hasMeaningfulChange(pixelBuffer: pixelBuffer) else {
                    return
                }

                // Bước 5: Downscale ảnh về 720p để cứu bộ nhớ khỏi mức trần 50MB của Extension
                guard let resizedBuffer = ImageProcessor.resize(pixelBuffer: pixelBuffer, targetWidth: 720) else {
                    return
                }

                let sourceLanguage = AppSettings.sourceLanguage
                let targetLanguage = AppSettings.targetLanguage
                let minLength = AppSettings.minimumTextLength

                // Bước 6: Nhận diện chữ bằng Vision Framework (.fast mode)
                self.ocrService.recognizeText(from: resizedBuffer, language: sourceLanguage) { [weak self] recognizedText in
                    guard let self = self,
                          let text = recognizedText,
                          text.count >= minLength else {
                        return
                    }

                    // Bước 7: Dịch nội dung sang tiếng Việt (có in-memory cache)
                    self.translationService.translate(text: text, from: sourceLanguage, to: targetLanguage) { translatedText in
                        guard let translated = translatedText else { return }

                        // Bước 8: Bắn biểu ngữ Notification lên cạnh trên màn hình game
                        NotificationService.shared.showTranslationBanner(original: text, translated: translated)
                    }
                }
            }
        }
    }
}
