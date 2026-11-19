import SwiftUI
import Vision

/// Màn hình Đóng băng & Cho phép người dùng chạm/kéo khoanh vùng câu thoại cần dịch
struct ScreenCropTranslateView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Ảnh chụp màn hình game đang đóng băng
    var frozenImage: UIImage?
    
    // Tọa độ vùng người dùng kéo chọn
    @State private var startPoint: CGPoint = .zero
    @State private var currentPoint: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var selectionRect: CGRect = .zero
    
    // Kết quả nhận diện & dịch
    @State private var recognizedOriginalText: String = ""
    @State private var translatedResultText: String = ""
    @State private var isTranslating: Bool = false
    
    private let ocrService = OCRService()
    private let translationService = TranslationService()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 1. Ảnh màn hình game đang đóng băng
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    if let img = frozenImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        // Ảnh mẫu mô phỏng nếu chưa có frame chụp
                        Color.slateDark
                            .overlay(
                                Text("Chạm hoặc kéo ngón tay để khoanh vùng câu thoại cần dịch")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding()
                            )
                    }
                    
                    // Lớp tối phủ mờ xung quanh khi đang khoanh vùng
                    Color.black.opacity(0.35)
                    
                    // 2. Khung chữ nhật khoanh vùng khi người dùng kéo tay
                    if selectionRect.width > 10 && selectionRect.height > 10 {
                        Rectangle()
                            .path(in: selectionRect)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, dash: [6, 3]))
                            .background(Rectangle().path(in: selectionRect).fill(Color.green.opacity(0.2)))
                    }
                    
                    // 3. Khung popup hiển thị kết quả dịch đè lên câu thoại
                    if !translatedResultText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("🇻🇳 Bản dịch tiếng Việt")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                Spacer()
                                Button(action: {
                                    translatedResultText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(translatedResultText)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            if !recognizedOriginalText.isEmpty {
                                Text(recognizedOriginalText)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.systemGray6).opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.5), lineWidth: 1))
                        .shadow(radius: 12)
                        .padding(.horizontal, 20)
                        .position(x: geo.size.width / 2, y: max(selectionRect.minY - 50, 100))
                    }
                }
                .contentShape(Rectangle())
                // Bắt cử chỉ chạm hoặc kéo ngón tay trên màn hình game
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                startPoint = value.startLocation
                                translatedResultText = ""
                            }
                            currentPoint = value.location
                            
                            let x = min(startPoint.x, currentPoint.x)
                            let y = min(startPoint.y, currentPoint.y)
                            let w = abs(currentPoint.x - startPoint.x)
                            let h = abs(currentPoint.y - startPoint.y)
                            selectionRect = CGRect(x: x, y: y, width: w, height: h)
                        }
                        .onEnded { _ in
                            isDragging = false
                            // Khi người dùng thả tay ra -> Thực hiện cắt ảnh và OCR đúng vùng vừa khoanh
                            processCropArea(rect: selectionRect, containerSize: geo.size)
                        }
                )
            }
            
            // 4. Thanh điều hướng trên cùng & Thanh chọn ngôn ngữ dưới cùng
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Quay lại Game")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue))
                    }
                    
                    Spacer()
                    
                    if isTranslating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Đang dịch...")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                }
                .padding()
                
                Spacer()
                
                // MỤC MỚI: Thanh chọn ngôn ngữ ở dưới cùng màn hình (Y hệt ảnh người dùng gửi)
                HStack(spacing: 8) {
                    // Hộp bên trái: Ngôn ngữ nguồn (Tiếng Indonesia ▼)
                    HStack {
                        Text("Tiếng Indonesia")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                        Spacer()
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
                    
                    // Nút hoán đổi ⇄ ở giữa
                    Button(action: {}) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                    }
                    
                    // Hộp bên phải: Ngôn ngữ đích (Tiếng Việt ▼)
                    HStack {
                        Text("Tiếng Việt")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                        Spacer()
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
    }
    
    /// Cắt ảnh theo vùng khoanh và chạy OCR + Dịch
    private func processCropArea(rect: CGRect, containerSize: CGSize) {
        guard rect.width > 20 && rect.height > 15 else { return }
        guard let sourceImage = frozenImage ?? UIImage(named: "SampleGameScreen") else { return }
        
        isTranslating = true
        
        // Chuyển đổi tọa độ view sang tọa độ ảnh gốc
        let scaleX = sourceImage.size.width / containerSize.width
        let scaleY = sourceImage.size.height / containerSize.height
        
        let cropZone = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        )
        
        guard let cgImage = sourceImage.cgImage?.cropping(to: cropZone) else {
            isTranslating = false
            return
        }
        
        let croppedImage = UIImage(cgImage: cgImage)
        
        // OCR vùng vừa cắt bằng Vision
        guard let pixelBuffer = croppedImage.toPixelBuffer() else {
            isTranslating = false
            return
        }
        
        let lang = AppSettings.sourceLanguage
        ocrService.recognizeText(from: pixelBuffer, language: lang, region: "all") { text in
            guard let text = text, !text.isEmpty else {
                DispatchQueue.main.async {
                    self.isTranslating = false
                    self.translatedResultText = "Không nhận diện được chữ trong vùng này. Vui lòng khoanh lại!"
                }
                return
            }
            
            self.recognizedOriginalText = text
            self.translationService.translate(text: text, from: lang, to: AppSettings.targetLanguage) { result in
                DispatchQueue.main.async {
                    self.isTranslating = false
                    self.translatedResultText = result ?? "Lỗi dịch thuật."
                }
            }
        }
    }
}

// Extension hỗ trợ convert UIImage sang CVPixelBuffer nhanh chóng
extension UIImage {
    func toPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        if let cgImg = self.cgImage {
            context.draw(cgImg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        return buffer
    }
}

extension Color {
    static let slateDark = Color(red: 0.08, green: 0.11, blue: 0.16)
}
