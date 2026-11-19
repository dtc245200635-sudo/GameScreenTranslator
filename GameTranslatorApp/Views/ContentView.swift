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
        ("id-ID", "Tiếng Indonesia (Bahasa)", "🇮🇩"),
        ("en-US", "Tiếng Anh (English)", "🇺🇸"),
        ("ja-JP", "Tiếng Nhật (日本語)", "🇯🇵"),
        ("zh-Hans", "Tiếng Trung Giản thể (简体)", "🇨🇳"),
        ("zh-Hant", "Tiếng Trung Phồn thể (繁體)", "🇭🇰"),
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
                
                // MARK: - Mục 2: Nút kích hoạt Broadcast ReplayKit
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
                
                // MARK: - Mục 3: CHỌN ĐỂ DỊCH CÂU THOẠI (Region of Interest)
                Section(header: Label("Chọn vùng để dịch câu thoại", systemImage: "crop")) {
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
                
                // MARK: - Mục 4: Cấu hình ngôn ngữ & Tần suất quét
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
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Mục 5: TÍNH NĂNG NÚT ẢO KÍCH HOẠT (Assistive Touch / Gõ mặt lưng)
                Section(header: Label("Bật nút ảo để dịch tức thì", systemImage: "hand.tap")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Mẹo dùng như Nút Home ảo (AssistiveTouch):")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                        
                        Text("Trên iOS, bạn có thể biến cử chỉ **Gõ 2 lần mặt lưng (Back Tap)** hoặc **Chạm nút AssistiveTouch** thành nút kích hoạt dịch cực kỳ tiện lợi:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Vào **Cài đặt iPhone** -> **Trợ năng (Accessibility)**.")
                            Text("2. Chọn **Cảm ứng (Touch)** -> Kéo xuống dưới chọn **Chạm vào mặt lưng (Back Tap)**.")
                            Text("3. Chọn **Chạm hai lần** -> Gán hành động hoặc phím tắt mở GameTranslator.")
                        }
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
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
