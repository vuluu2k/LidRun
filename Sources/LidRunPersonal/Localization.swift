import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"

    var id: String { rawValue }
    var title: String { self == .english ? "English" : "Tiếng Việt" }
}

enum L10n {
    private static let values: [String: [AppLanguage: String]] = [
        "ready": [.english: "Ready", .vietnamese: "Sẵn sàng"],
        "charging": [.english: "Charging", .vietnamese: "Đang sạc"],
        "battery": [.english: "Battery", .vietnamese: "Pin"],
        "open": [.english: "Open", .vietnamese: "Đang mở"],
        "armed": [.english: "Armed", .vietnamese: "Đã bật"],
        "autoMode": [.english: "Auto Mode", .vietnamese: "Chế độ tự động"],
        "keepAwake": [.english: "Keep Awake", .vietnamese: "Giữ máy thức"],
        "chargingOnly": [.english: "Only When Charging", .vietnamese: "Chỉ khi đang sạc"],
        "timer": [.english: "Timer", .vietnamese: "Hẹn giờ"],
        "closedLid": [.english: "Closed-Lid Mode", .vietnamese: "Chế độ đóng nắp"],
        "cooling": [.english: "Cooling", .vietnamese: "Bảo vệ nhiệt"],
        "stop": [.english: "Stop", .vietnamese: "Dừng"],
        "blockedByGuardrail": [.english: "Not started — safety guardrail", .vietnamese: "Chưa bật — bị chặn bởi giới hạn an toàn"],
        "closedLidNeedsCharger": [.english: "Closed-Lid Mode needs the charger connected: macOS ignores it on battery and the Mac would sleep when the lid closes.", .vietnamese: "Chế độ đóng nắp cần cắm sạc: khi chạy pin macOS bỏ qua chế độ này và máy vẫn sleep khi gập nắp."],
        "update": [.english: "Update to", .vietnamese: "Cập nhật"],
        "updating": [.english: "Updating…", .vietnamese: "Đang cập nhật…"],
        "status": [.english: "Status", .vietnamese: "Trạng thái"],
        "protected": [.english: "Protected", .vietnamese: "Đang bảo vệ"],
        "idle": [.english: "Idle", .vietnamese: "Đang nghỉ"],
        "tasksReports": [.english: "Tasks & Reports", .vietnamese: "Tác vụ & Báo cáo"],
        "notifications": [.english: "Notifications & Webhooks", .vietnamese: "Thông báo & Webhook"],
        "settings": [.english: "Settings", .vietnamese: "Cài đặt"],
        "quit": [.english: "Quit LidRun", .vietnamese: "Thoát LidRun"],
        "sessions": [.english: "Sessions", .vietnamese: "Phiên chạy"],
        "safetyStops": [.english: "Safety stops", .vietnamese: "Dừng an toàn"],
        "protectedTime": [.english: "Protected", .vietnamese: "Đã bảo vệ"],
        "copyReport": [.english: "Copy weekly report", .vietnamese: "Sao chép báo cáo tuần"],
        "macAlerts": [.english: "macOS Alerts", .vietnamese: "Thông báo macOS"],
        "webhook": [.english: "Webhook URL", .vietnamese: "URL Webhook"],
        "save": [.english: "Save", .vietnamese: "Lưu"],
        "done": [.english: "Done", .vietnamese: "Xong"],
        "lowBattery": [.english: "Low battery stop", .vietnamese: "Dừng khi pin yếu"],
        "watchdog": [.english: "Watchdog limit", .vietnamese: "Giới hạn Watchdog"],
        "language": [.english: "Language", .vietnamese: "Ngôn ngữ"],
        "launchAtLogin": [.english: "Launch at login", .vietnamese: "Mở khi đăng nhập"],
        "webhookToken": [.english: "Webhook token", .vietnamese: "Token Webhook"],
        "notificationHelp": [.english: "Enable alerts to request macOS notification permission.", .vietnamese: "Bật thông báo để macOS yêu cầu quyền Notifications."],
        "testNotification": [.english: "Send test notification", .vietnamese: "Gửi thông báo thử"],
        "openSystemSettings": [.english: "Open System Settings", .vietnamese: "Mở Cài đặt hệ thống"],
        "testWebhook": [.english: "Save & test webhook", .vietnamese: "Lưu & thử webhook"],
        "detectedPlatform": [.english: "Detected platform", .vietnamese: "Nền tảng nhận diện"],
        "hotkeys": [.english: "Global hotkeys", .vietnamese: "Phím tắt toàn hệ thống"],
        "hotkeysHelp": [.english: "Control+Option+A/S/L/X. No Accessibility permission required.", .vietnamese: "Control+Option+A/S/L/X. Không cần quyền Accessibility."],
        "smartRules": [.english: "Extra process rules", .vietnamese: "Process theo dõi thêm"],
        "allUnlocked": [.english: "Personal · All features unlocked", .vietnamese: "Cá nhân · Đã mở mọi tính năng"],
        "upToDate": [.english: "Local build · Up to date", .vietnamese: "Bản local · Đã cập nhật"],
        "noTasks": [.english: "No watched tasks", .vietnamese: "Không có tác vụ theo dõi"],
        "thermalOK": [.english: "OK", .vietnamese: "Tốt"],
        "thermalWarm": [.english: "Warm", .vietnamese: "Ấm"],
        "thermalHot": [.english: "Hot", .vietnamese: "Nóng"],
        "thermalCritical": [.english: "Critical", .vietnamese: "Nguy"],
        "jobs": [.english: "jobs", .vietnamese: "job"],
        "notRunning": [.english: "Idle", .vietnamese: "Nghỉ"],
        "safetyNote": [.english: "Public macOS power APIs cannot override every hardware sleep decision. Keep vents clear.", .vietnamese: "API nguồn công khai của macOS không thể ghi đè mọi quyết định sleep của phần cứng. Luôn giữ khe tản nhiệt thông thoáng."],
    ]

    static func text(_ key: String, _ language: AppLanguage) -> String {
        values[key]?[language] ?? key
    }
}
