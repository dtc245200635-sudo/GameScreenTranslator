import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    @State private var sourceLang: String = AppSettings.sourceLanguage
    @State private var targetLang: String = AppSettings.targetLanguage
    @State private var scanInterval: Double = AppSettings.scanInterval
    @State private var isServiceEnabled: Bool = AppSettings.isServiceEnabled
    
    @State private var showingTestNotificationAlert = false
    @State private var testNotificationMessage = ""
    
    let supportedLanguages: [(code: String, name: String, flag: String)] = [
        ("en-US", "Tiếng Anh (English)", "🇺🇸"),
        ("ja-JP", "Tiếng Nhật (日本語)", "🇯🇵"),
        ("zh-Hans", "Tiếng Trung (简体中文)", "🇨🇳"),
        ("ko-KR", "Tiếng Hàn (한국어)", "🇰🇷"),
        ("fr-FR", "Tiếng Pháp (Français)", "🇫🇷"),
        ("de-DE", "Tiếng Đức (Deutsch)", "🇩🇪")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Mục 1: Trạng thái quyền
                Section(header: Label("Quyền hệ thống", systemImage: "bell.badge")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thông báo biểu ngữ (Banner)")
                                .font(.body.weight(.medium))
                            Text(permissionManager.isNotificationAuthorized ? "Đã cho phép nhận bản dịch" : "Chưa cấp quyền thông báo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if permissionManager.isNotificationAuthorized {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else {
                            Button("Cấp quyền") {
                                if permissionManager.authorizationStatus == .denied {
                                    permissionManager.openSettings()
                                } else {
                                    permissionManager.requestNotificationPermission()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    }
                    
                    if permissionManager.isNotificationAuthorized {
                        Button(action: sendTestNotification) {
                            Label("Thử bắn thông báo mẫu", systemImage: "paperplane")
                                .font(.subheadline)
                        }
                    }
                }
                
                // MARK: - Mục 2: Bật tắt dịch vụ & Kích hoạt Broadcast
                Section(header: Label("Kích hoạt Quay màn hình", systemImage: "record.circle")) {
                    Toggle("Cho phép Extension dịch ngầm", isOn: $isServiceEnabled)
                        .onChange(of: isServiceEnabled) { value in
                            AppSettings.isServiceEnabled = value
                        }
                    
                    VStack(alignment: .center, spacing: 14) {
                        Text("Bấm vào biểu tượng quay màn hình bên dưới, chọn **GameTranslator** và bấm **Bắt đầu truyền phát**:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 90)
                            
                            VStack(spacing: 6) {
                                BroadcastPickerView(tintColor: .systemBlue)
                                    .frame(width: 50, height: 50)
                                Text("Chạm để bật ReplayKit")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Mục 3: Cấu hình ngôn ngữ & Tần suất
                Section(header: Label("Cấu hình Dịch thuật", systemImage: "character.book.closed")) {
                    Picker("Ngôn ngữ game", selection: $sourceLang) {
                        ForEach(supportedLanguages, id: \.code) { item in
                            Text("\(item.flag) \(item.name)").tag(item.code)
                        }
                    }
                    .onChange(of: sourceLang) { newValue in
                        AppSettings.sourceLanguage = newValue
                    }
                    
                    HStack {
                        Text("Dịch sang")
                        Spacer()
                        Text("🇻🇳 Tiếng Việt")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tần suất quét màn hình:")
                            Spacer()
                            Text("\(String(format: "%.1f", scanInterval)) giây / lần")
                                .foregroundColor(.blue)
                                .bold()
                        }
                        
                        Slider(value: $scanInterval, in: 1.0...4.0, step: 0.5)
                            .onChange(of: scanInterval) { newValue in
                                AppSettings.scanInterval = newValue
                            }
                        
                        Text("💡 Mẹo: 2.0s là mức tối ưu nhất giúp điện thoại không bị nóng và không tốn pin khi chơi game.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Mục 4: Hướng dẫn chi tiết
                Section(header: Label("Cách sử dụng khi chơi game", systemImage: "gamecontroller")) {
                    VStack(alignment: .leading, spacing: 10) {
                        StepRow(step: "1", title: "Cấp quyền thông báo", desc: "Đảm bảo mục Quyền hệ thống hiện dấu tích xanh.")
                        StepRow(step: "2", title: "Bật quay màn hình", desc: "Chạm vào ô ReplayKit ở trên, chọn GameTranslator và bấm Bắt đầu.")
                        StepRow(step: "3", title: "Mở game và trải nghiệm", desc: "Chuyển sang tựa game yêu thích. Khi màn hình xuất hiện phụ đề hoặc nhiệm vụ tiếng nước ngoài, bản dịch tiếng Việt sẽ rơi xuống từ mép trên màn hình.")
                        StepRow(step: "4", title: "Dừng dịch", desc: "Bấm vào thanh trạng thái màu đỏ trên cùng của iPhone hoặc vào lại app để tắt truyền phát.")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Dịch Màn Hình Game")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingTestNotificationAlert) {
                Alert(title: Text("Thông báo"), message: Text(testNotificationMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🌐 Dịch Game (Thử nghiệm)"
        content.subtitle = "Quest: Defeat the Fire Dragon in 3 minutes"
        content.body = "Nhiệm vụ: Đánh bại Rồng Lửa trong vòng 3 phút!"
        content.sound = nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: AppGroupConstants.notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.testNotificationMessage = "Lỗi gửi: \(error.localizedDescription)"
                } else {
                    self.testNotificationMessage = "Đã gửi! Vui lòng vuốt về Home hoặc khóa màn hình trong 1 giây để xem Banner thông báo."
                }
                self.showingTestNotificationAlert = true
            }
        }
    }
}

struct StepRow: View {
    let step: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                Text(step)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
