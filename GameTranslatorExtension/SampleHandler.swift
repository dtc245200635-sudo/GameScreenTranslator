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
            break
        @unknown default:
            break
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard AppSettings.isServiceEnabled else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()
        let interval = AppSettings.scanInterval

        // Bước 1: Throttling thời gian
        guard throttler.shouldProcess(currentTime: currentTime, interval: interval) else {
            return
        }

        // Bước 2: Kiểm tra cờ xử lý
        guard !isProcessing else { return }
        isProcessing = true

        // Bước 3: Đưa vào queue riêng và bọc toàn bộ bằng autoreleasepool
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                defer {
                    self.isProcessing = false
                }

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }

                // Bước 4: Kiểm tra nhanh biến động màn hình
                guard self.throttler.hasMeaningfulChange(pixelBuffer: pixelBuffer) else {
                    return
                }

                // Bước 5: Downscale ảnh về 720p để bảo vệ mức trần 50MB RAM
                guard let resizedBuffer = ImageProcessor.resize(pixelBuffer: pixelBuffer, targetWidth: 720) else {
                    return
                }

                let sourceLanguage = AppSettings.sourceLanguage
                let targetLanguage = AppSettings.targetLanguage
                let scanRegion = AppSettings.scanRegion
                let minLength = AppSettings.minimumTextLength

                // Bước 6: Nhận diện chữ bằng Vision Framework theo vùng chọn (ROI)
                self.ocrService.recognizeText(from: resizedBuffer, language: sourceLanguage, region: scanRegion) { [weak self] recognizedText in
                    guard let self = self,
                          let text = recognizedText,
                          text.count >= minLength else {
                        return
                    }

                    // Bước 7: Dịch nội dung sang tiếng Việt
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
