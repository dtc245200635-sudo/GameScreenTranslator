import SwiftUI
import Vision
import CoreVideo
import CoreMedia
import AVFoundation

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
    
    // Ngôn ngữ dịch 2 chiều linh hoạt
    @State private var sourceLang: String = AppSettings.sourceLanguage
    @State private var targetLang: String = AppSettings.targetLanguage
    
    // Nhập để dịch ngay bên dưới
    @State private var quickInputText: String = ""
    @State private var quickResultText: String = ""
    @State private var isQuickTranslating: Bool = false
    
    let allLanguages: [(code: String, name: String)] = [
        ("auto", "🔍 Tự động phát hiện"),
        ("id-ID", "Tiếng Indonesia"),
        ("vi-VN", "Tiếng Việt"),
        ("en-US", "Tiếng Anh"),
        ("ja-JP", "Tiếng Nhật"),
        ("zh-Hans", "Tiếng Trung"),
        ("ko-KR", "Tiếng Hàn"),
        ("th-TH", "Tiếng Thái"),
        ("es-ES", "Tây Ban Nha"),
        ("ru-RU", "Tiếng Nga"),
        ("fr-FR", "Tiếng Pháp"),
        ("de-DE", "Tiếng Đức")
    ]
    
    private var sourceLangName: String {
        allLanguages.first(where: { $0.code == sourceLang })?.name ?? "Tiếng Indonesia"
    }
    
    private var targetLangName: String {
        allLanguages.first(where: { $0.code == targetLang })?.name ?? "Tiếng Việt"
    }
    
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
                    Color.black.opacity(0.4)
                    
                    // NẾU CHƯA KHOANH VÙNG: HIỂN THỊ CÁC Ô GỢI Ý CHẠM ĐỂ DỊCH (CHUẨN ẢNH NGƯỜI DÙNG GỬI)
                    if selectionRect.width <= 10 && translatedResultText.isEmpty {
                        VStack(spacing: 20) {
                            // Ô Quest Objective gợi ý
                            Button(action: {
                                let targetW = min(geo.size.width - 40, 340)
                                let targetH: CGFloat = 80
                                let rect = CGRect(x: (geo.size.width - targetW) / 2, y: geo.size.height * 0.28, width: targetW, height: targetH)
                                selectionRect = rect
                                processCropArea(rect: rect, containerSize: geo.size)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text("📜 Quest Objective:")
                                                .font(.caption.bold())
                                                .foregroundColor(.yellow)
                                            Spacer()
                                            Text("[Chạm để dịch]")
                                                .font(.caption2.bold())
                                                .foregroundColor(.blue)
                                        }
                                        Text("\"Kalahkan 5 monster bayangan di hutan berkabut...\"")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.75)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                            
                            // Ô Khung thoại NPC gợi ý
                            Button(action: {
                                let targetW = min(geo.size.width - 40, 340)
                                let targetH: CGFloat = 90
                                let rect = CGRect(x: (geo.size.width - targetW) / 2, y: geo.size.height * 0.50, width: targetW, height: targetH)
                                selectionRect = rect
                                processCropArea(rect: rect, containerSize: geo.size)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text("🇮🇩 \(sourceLangName) (Khung thoại NPC)")
                                                .font(.caption.bold())
                                                .foregroundColor(.cyan)
                                            Spacer()
                                            Text("[Chạm để dịch]")
                                                .font(.caption2.bold())
                                                .foregroundColor(.blue)
                                        }
                                        Text("\"Segel kuno di gunung berapi telah rusak. Kita harus bergegas trước khi quái thú trốn thoát!\"")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.75)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // 2. KHUNG NGẮM VIEWFINDER 4 GÓC BO TRÒN TRẮNG CHUẨN THEO ẢNH NGƯỜI DÙNG GỬI
                    if selectionRect.width > 10 && selectionRect.height > 10 {
                        ZStack {
                            // Nền mờ nhẹ bên trong vùng ngắm
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: selectionRect.width, height: selectionRect.height)
                                .position(x: selectionRect.midX, y: selectionRect.midY)
                            
                            // 4 góc bo tròn màu trắng
                            ViewfinderCorners(color: .white, lineWidth: 4, length: min(28, max(16, selectionRect.width / 4)), cornerRadius: 14)
                                .frame(width: selectionRect.width, height: selectionRect.height)
                                .position(x: selectionRect.midX, y: selectionRect.midY)
                                .shadow(color: .black.opacity(0.7), radius: 6)
                        }
                    }
                    
                    // 3. Khung popup hiển thị kết quả chuẩn Google Dịch
                    if !translatedResultText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("GOOGLE DỊCH (\(sourceLangName.uppercased()) ➔ \(targetLangName.uppercased())):")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))
                                Spacer()
                                
                                // Biểu tượng phát âm (chỉ icon, không chữ)
                                Button(action: {
                                    let utterance = AVSpeechUtterance(string: translatedResultText)
                                    utterance.voice = AVSpeechSynthesisVoice(language: targetLang)
                                    let synthesizer = AVSpeechSynthesizer()
                                    synthesizer.speak(utterance)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color(UIColor.systemGray5)))
                                }
                                
                                // Biểu tượng sao chép (chỉ icon 2 trang giấy chồng, không chữ)
                                Button(action: {
                                    UIPasteboard.general.string = translatedResultText
                                }) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color(UIColor.systemGray5)))
                                }
                                
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
            
            // 4. Menu nổi góc trên trái & Nút X đóng ở góc trên phải
            VStack {
                HStack(alignment: .center) {
                    // MENU NỔI GÓC TRÊN TRÁI (CHUẨN ẢNH 10: [ ☰ ID Indo ▼ ] và [ 文A Bấm Dịch ])
                    HStack(spacing: 6) {
                        Menu {
                            ForEach(allLanguages, id: \.code) { lang in
                                Button(lang.name) {
                                    sourceLang = lang.code
                                    AppSettings.sourceLanguage = lang.code
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 11, weight: .bold))
                                Text(sourceLang.starts(with: "id") ? "ID Indo" : (allLanguages.first(where: { $0.code == sourceLang })?.name ?? sourceLang))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray6)))
                        }
                        
                        // Nút 文A Bấm Dịch: Tự động chụp / quét câu thoại và dịch ngay; bấm lại để đóng
                        Button(action: {
                            if !translatedResultText.isEmpty {
                                translatedResultText = ""
                                selectionRect = .zero
                            } else {
                                triggerDefaultSnapTranslation(containerSize: UIScreen.main.bounds.size)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "character.book.closed.fill")
                                    .font(.system(size: 11))
                                Text(!translatedResultText.isEmpty ? "Ẩn Dịch" : "Bấm Dịch")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                        }
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.85)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.5), lineWidth: 1))
                    
                    Spacer()
                    
                    if isTranslating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Đang dịch...")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    
                    // Nút X tròn ở góc trên (chỉ để lại dấu X, không thêm chữ)
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Spacer()
                
                // MỤC MỚI: BẢNG DỊCH 2 CHIỀU & Ô NHẬP DỊCH NHANH Ở DƯỚI CÙNG
                VStack(spacing: 8) {
                    // HÀNG 1: [ Ngôn ngữ nguồn ▼ ] ⇄ [ Ngôn ngữ đích ▼ ]
                    HStack(spacing: 8) {
                        // Hộp bên trái: Chọn ngôn ngữ nguồn
                        Menu {
                            ForEach(allLanguages, id: \.code) { lang in
                                Button(lang.name) {
                                    sourceLang = lang.code
                                    AppSettings.sourceLanguage = lang.code
                                }
                            }
                        } label: {
                            HStack {
                                Text(sourceLangName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
                        }
                        
                        // Nút hoán đổi ⇄ ở giữa
                        Button(action: {
                            let temp = sourceLang
                            sourceLang = targetLang
                            targetLang = temp
                            AppSettings.sourceLanguage = sourceLang
                            AppSettings.targetLanguage = targetLang
                        }) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.slateDark))
                        }
                        
                        // Hộp bên phải: Chọn ngôn ngữ đích
                        Menu {
                            ForEach(allLanguages, id: \.code) { lang in
                                Button(lang.name) {
                                    targetLang = lang.code
                                    AppSettings.targetLanguage = lang.code
                                }
                            }
                        } label: {
                            HStack {
                                Text(targetLangName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(red: 0.1, green: 0.14, blue: 0.49))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35), lineWidth: 1))
                        }
                    }
                    
                    // HÀNG 2: MỤC ĐỂ CHỮ "NHẬP ĐỂ DỊCH"
                    HStack(spacing: 8) {
                        TextField("Nhập để dịch...", text: $quickInputText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                        
                        Button(action: executeQuickTranslate) {
                            HStack(spacing: 4) {
                                if isQuickTranslating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Dịch")
                                        .font(.system(size: 12, weight: .bold))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                        }
                    }
                    
                    // HÀNG 3: HIỂN THỊ KẾT QUẢ - CHUẨN GOOGLE DỊCH
                    if !quickResultText.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GOOGLE DỊCH (\(sourceLangName.uppercased()) ➔ \(targetLangName.uppercased())):")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))
                                Text(quickResultText)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            
                            // Chỉ có biểu tượng phát âm (🔊)
                            Button(action: speakQuickResult) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color(UIColor.systemGray5)))
                            }
                            
                            // Chỉ có biểu tượng sao chép (📋)
                            Button(action: {
                                UIPasteboard.general.string = quickResultText
                            }) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color(UIColor.systemGray5)))
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.slateDark))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.5), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .background(Color.black.opacity(0.75).edgesIgnoringSafeArea(.bottom))
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
    
    /// Kích hoạt chụp & dịch nhanh vùng thoại trung tâm khi bấm Menu nổi
    private func triggerDefaultSnapTranslation(containerSize: CGSize) {
        let targetW = min(containerSize.width - 40, 360)
        let targetH: CGFloat = 90
        let rect = CGRect(x: (containerSize.width - targetW) / 2, y: containerSize.height * 0.45, width: targetW, height: targetH)
        selectionRect = rect
        processCropArea(rect: rect, containerSize: containerSize)
    }

    /// Dịch nhanh câu người dùng nhập vào ô văn bản bên dưới
    private func executeQuickTranslate() {
        let trimmed = quickInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isQuickTranslating = true
        quickResultText = ""
        
        translationService.translate(text: trimmed, from: sourceLang, to: targetLang) { result in
            DispatchQueue.main.async {
                self.isQuickTranslating = false
                self.quickResultText = result ?? "Không thể dịch câu này."
            }
        }
    }
    
    /// Phát âm giọng đọc câu vừa dịch
    private func speakQuickResult() {
        guard !quickResultText.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: quickResultText)
        utterance.voice = AVSpeechSynthesisVoice(language: targetLang)
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
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

/// Khung ngắm Viewfinder với 4 góc bo tròn màu trắng chuẩn theo ảnh người dùng gửi
struct ViewfinderCorners: View {
    var color: Color = .white
    var lineWidth: CGFloat = 4
    var length: CGFloat = 26
    var cornerRadius: CGFloat = 14
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                // Góc trên - trái (Top-Left)
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                
                // Góc trên - phải (Top-Right)
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: cornerRadius), control: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))
                
                // Góc dưới - phải (Bottom-Right)
                path.move(to: CGPoint(x: w, y: h - length))
                path.addLine(to: CGPoint(x: w, y: h - cornerRadius))
                path.addQuadCurve(to: CGPoint(x: w - cornerRadius, y: h), control: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w - length, y: h))
                
                // Góc dưới - trái (Bottom-Left)
                path.move(to: CGPoint(x: length, y: h))
                path.addLine(to: CGPoint(x: cornerRadius, y: h))
                path.addQuadCurve(to: CGPoint(x: 0, y: h - cornerRadius), control: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h - length))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}
