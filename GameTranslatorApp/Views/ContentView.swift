import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    @State private var sourceLang: String = AppSettings.sourceLanguage
    @State private var targetLang: String = AppSettings.targetLanguage
    @State private var scanRegion: String = AppSettings.scanRegion
    @State private var scanInterval: Double = AppSettings.scanInterval
    @State private var isServiceEnabled: Bool = AppSettings.isServiceEnabled
    
    @State private var showingTestNotificationAlert = false
    @State private var testNotificationMessage = ""
    
    let supportedLanguages: [(code: String, name: String, flag: String)] = [
        ("id-ID", "Tiếng Indonesia (Bahasa Indonesia)", "🇮🇩"),
        ("en-US", "Tiếng Anh (English)", "🇺🇸"),
        ("ja-JP", "Tiếng Nhật (日本語)", "🇯🇵"),
        ("zh-Hans", "Tiếng Trung Giản thể (简体中文)", "🇨🇳"),
        ("zh-Hant", "Tiếng Trung Phồn thể (繁體中文)", "🇭🇰"),
        ("ko-KR", "Tiếng Hàn (한국어)", "🇰🇷"),
        ("th-TH", "Tiếng Thái (ไทย)", "🇹🇭"),
        ("ru-RU", "Tiếng Nga (Русский)", "🇷🇺"),
        ("es-ES", "Tiếng Tây Ban Nha (Español)", "🇪🇸"),
        ("pt-BR", "Tiếng Bồ Đào Nha (Português)", "🇧🇷"),
        ("fr-FR", "Tiếng Pháp (Français)", "🇫🇷"),
        ("de-DE", "Tiếng Đức (Deutsch)", "🇩🇪"),
        ("it-IT", "Tiếng Ý (Italiano)", "🇮🇹")
    ]
    
    let regionOptions: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("bottom", "Phụ đề hội thoại (Nửa dưới)", "Chỉ quét khung thoại NPC, bỏ qua nút bấm & thanh máu", "captions.bubble"),
        ("top", "Bảng nhiệm vụ (Nửa trên)", "Chỉ quét mục tiêu & quest log ở góc trên màn hình", "list.bullet.rectangle"),
        ("all", "Toàn màn hình", "Quét toàn bộ mọi chữ xuất hiện trên màn hình", "viewfinder")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Mục Nổi Bật: Chế độ Menu Nổi Góc Trái (Chạy ẩn khi chơi game)
                Section(header: Label("Menu Nổi Dịch Game (Chạy Ẩn)", systemImage: "sparkles")) {
                    NavigationLink(destination: ScreenCropTranslateView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 42, height: 42)
                                Image(systemName: "character.book.closed.fill")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bật Menu Nổi Chơi Game")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Hiện menu nổi góc trên trái: Bấm để chụp & dịch tức thì, bấm lại để ẩn")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Mục 1: Chọn Ngôn Ngữ Game Cần Dịch (Đưa lên đầu để dễ thấy nhất)
                Section(header: Label("Chọn Ngôn Ngữ Game Cần Dịch", systemImage: "globe")) {
                    Picker("Ngôn ngữ gốc", selection: $sourceLang) {
                        ForEach(supportedLanguages, id: \.code) { item in
                            Text("\(item.flag) \(item.name)").tag(item.code)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: sourceLang) { newValue in
                        AppSettings.sourceLanguage = newValue
                    }
                    
                    HStack {
                        Text("Dịch sang")
                        Spacer()
                        Text("🇻🇳 Tiếng Việt")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }
                
                // MARK: - Mục 2: Chọn Vùng Để Dịch Câu Thoại (ROI)
                Section(header: Label("Chọn Vùng Dịch Câu Thoại", systemImage: "crop")) {
                    NavigationLink(destination: ScreenCropTranslateView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.draw.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chế độ: Dừng màn hình & Khoanh vùng")
                                    .font(.subheadline.bold())
                                Text("Chạm/kéo ngón tay để khoanh chính xác câu thoại cần dịch")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ForEach(regionOptions, id: \.id) { opt in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: opt.icon)
                                .font(.title3)
                                .foregroundColor(scanRegion == opt.id ? .blue : .secondary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(opt.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if scanRegion == opt.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body.bold())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            scanRegion = opt.id
                            AppSettings.scanRegion = opt.id
                        }
                    }
                }
                
                // MARK: - Mục 3: Kích hoạt Quay Màn Hình (ReplayKit)
                Section(header: Label("Kích hoạt Quay màn hình", systemImage: "record.circle")) {
                    Toggle("Cho phép Extension dịch ngầm", isOn: $isServiceEnabled)
                        .onChange(of: isServiceEnabled) { value in
                            AppSettings.isServiceEnabled = value
                        }
                    
                    VStack(alignment: .center, spacing: 14) {
                        Text("Bấm vào biểu tượng bên dưới, chọn **GameTranslator** và bấm **Bắt đầu truyền phát**:")
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
                
                // MARK: - Mục 4: Tần Suất Quét Màn Hình
                Section(header: Label("Tần Suất Quét", systemImage: "timer")) {
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
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Mục 5: Quyền Hệ Thống
                Section(header: Label("Quyền Thông Báo (Banner)", systemImage: "bell.badge")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thông báo biểu ngữ (Banner)")
                                .font(.body.weight(.medium))
                            Text(permissionManager.isNotificationAuthorized ? "Đã cấp quyền hiển thị bản dịch" : "Chưa cấp quyền thông báo")
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
                
                // MARK: - Mục 6: Nút Ảo (Assistive Touch / Gõ Mặt Lưng)
                Section(header: Label("Mẹo: Dùng Nút Home Ảo Khi Chơi Game", systemImage: "hand.tap")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cách gán nút ảo kích hoạt:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                        Text("Vào **Cài đặt iPhone** -> **Trợ năng (Accessibility)** -> **Cảm ứng (Touch)** -> Kéo xuống dưới chọn **Chạm vào mặt lưng (Back Tap)** -> Chọn **Chạm hai lần** để gán mở nhanh bản dịch.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        content.subtitle = "Misi: Kalahkan 5 monster bayangan di hutan berkabut"
        content.body = "Nhiệm vụ: Đánh bại 5 quái vật bóng đêm trong khu rừng sương mù!"
        content.sound = nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: AppGroupConstants.notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.testNotificationMessage = "Lỗi gửi: \(error.localizedDescription)"
                } else {
                    self.testNotificationMessage = "Đã gửi! Vui lòng vuốt về Home trong 1 giây để xem Banner thông báo."
                }
                self.showingTestNotificationAlert = true
            }
        }
    }
}
