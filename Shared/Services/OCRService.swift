import Foundation
import Vision
import CoreVideo

/// Dịch vụ nhận diện văn bản OCR sử dụng Apple Vision Framework với tính năng chọn vùng quét (Region of Interest)
public final class OCRService {
    public init() {}
    
    /// Trích xuất text từ CVPixelBuffer theo vùng người dùng đã chọn
    public func recognizeText(
        from pixelBuffer: CVPixelBuffer,
        language: String,
        region: String = AppSettings.scanRegion,
        completion: @escaping (String?) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }

            // Sắp xếp các đoạn text theo thứ tự từ trên xuống dưới
            let sortedObservations = observations.sorted { obs1, obs2 in
                return obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
            }

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

        // Cấu hình vùng chọn để dịch câu thoại (Region of Interest - ROI)
        // Hệ tọa độ Vision: gốc (0,0) nằm ở GÓC DƯỚI BÊN TRÁI của màn hình
        switch region {
        case "bottom":
            // Chỉ tập trung vào 45% phía dưới màn hình (nơi chứa phụ đề hội thoại của NPC)
            request.regionOfInterest = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.45)
        case "top":
            // Chỉ tập trung vào 40% phía trên màn hình (nơi hiển thị bảng nhiệm vụ Quest log)
            request.regionOfInterest = CGRect(x: 0.0, y: 0.60, width: 1.0, height: 0.40)
        default:
            // Quét toàn bộ màn hình
            request.regionOfInterest = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        }

        // Tối ưu hóa bộ nhớ
        request.recognitionLevel = .fast
        request.recognitionLanguages = language == "en-US" ? ["en-US"] : [language, "en-US"]
        request.usesLanguageCorrection = false

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
