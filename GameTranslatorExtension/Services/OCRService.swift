import Foundation
import Vision
import CoreVideo

/// Dịch vụ nhận diện văn bản OCR sử dụng Apple Vision Framework
public final class OCRService {
    public init() {}
    
    /// Trích xuất text từ CVPixelBuffer đã được downscale
    public func recognizeText(
        from pixelBuffer: CVPixelBuffer,
        language: String,
        completion: @escaping (String?) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }

            // Sắp xếp các đoạn text theo thứ tự từ trên xuống dưới theo trục Y màn hình
            // BoundingBox trong Vision có gốc (0,0) ở góc dưới bên trái, y tăng dần lên trên
            let sortedObservations = observations.sorted { obs1, obs2 in
                return obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
            }

            // Lấy các ứng viên có độ tin cậy chấp nhận được (> 0.4)
            var recognizedLines: [String] = []
            for obs in sortedObservations {
                if let candidate = obs.topCandidates(1).first, candidate.confidence > 0.4 {
                    let cleaned = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        recognizedLines.append(cleaned)
                    }
                }
            }

            let fullText = recognizedLines.joined(separator: " ")
            completion(fullText.isEmpty ? nil : fullText)
        }

        // Tối ưu hóa cực hạn cho Extension:
        // .fast: Tốn ~10MB RAM (thay vì .accurate tốn ~35MB RAM dễ gây crash văng Extension)
        request.recognitionLevel = .fast
        request.recognitionLanguages = language == "en-US" ? ["en-US"] : [language, "en-US"]
        request.usesLanguageCorrection = false // Tắt để không tải từ điển nặng vào RAM

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
}
