import SwiftUI
import ReplayKit

/// Bọc UIKit RPSystemBroadcastPickerView để hiển thị nút bắt đầu truyền phát màn hình ReplayKit trong SwiftUI
struct BroadcastPickerView: UIViewRepresentable {
    var extensionBundleId: String = AppGroupConstants.extensionBundleId
    var tintColor: UIColor = .systemBlue
    
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        picker.preferredExtension = extensionBundleId
        picker.showsMicrophoneButton = false
        
        // Căn chỉnh giao diện nút ReplayKit bên trong picker
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.tintColor = tintColor
                button.imageView?.contentMode = .scaleAspectFit
            }
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.preferredExtension = extensionBundleId
        for subview in uiView.subviews {
            if let button = subview as? UIButton {
                button.tintColor = tintColor
            }
        }
    }
}
