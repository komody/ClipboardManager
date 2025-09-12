import SwiftUI

// MARK: - プロフェッショナル・ブルーテーマ
struct ProfessionalBlueTheme {
    
    // MARK: - カラーパレット
    struct Colors {
        // メインカラー
        static let primary = Color(hex: "1976D2")      // プロフェッショナルブルー
        static let primaryDark = Color(hex: "0D47A1")  // ダークブルー
        static let primaryLight = Color(hex: "BBDEFB") // ライトブルー
        
        // 背景カラー
        static let background = Color(hex: "E3F2FD")   // ベース背景
        static let backgroundLight = Color(hex: "F8FBFF") // ライト背景
        static let card = Color(hex: "F2F8FF")         // カード背景
        
        // テキストカラー
        static let text = Color(hex: "0D47A1")         // メインテキスト
        static let textSecondary = Color(hex: "1565C0") // セカンダリテキスト
        static let textMuted = Color(hex: "6C757D")     // ミュートテキスト
        
        // アクセントカラー
        static let success = Color(hex: "28A745")       // 成功
        static let warning = Color(hex: "FFC107")       // 警告
        static let danger = Color(hex: "DC3545")        // 危険
        static let info = Color(hex: "17A2B8")          // 情報
        
        // ボーダー・シャドウ
        static let border = Color(hex: "BBDEFB")        // ボーダー
        static let shadow = Color(hex: "1976D2")        // シャドウ
    }
    
    // MARK: - スペーシング
    struct Spacing {
        static let xs: CGFloat = 4      // 極小
        static let sm: CGFloat = 8      // 小
        static let md: CGFloat = 12     // 中
        static let lg: CGFloat = 16     // 大
        static let xl: CGFloat = 20     // 特大
        static let xxl: CGFloat = 24    // 極大
    }
    
    // MARK: - コーナーラディウス
    struct CornerRadius {
        static let sm: CGFloat = 6      // 小
        static let md: CGFloat = 8      // 中
        static let lg: CGFloat = 12     // 大
        static let xl: CGFloat = 16     // 特大
    }
    
    // MARK: - フォントサイズ
    struct FontSize {
        static let xs: CGFloat = 12     // 極小
        static let sm: CGFloat = 14     // 小
        static let md: CGFloat = 16     // 中
        static let lg: CGFloat = 18     // 大
        static let xl: CGFloat = 20     // 特大
        static let xxl: CGFloat = 24    // 極大
    }
    
    // MARK: - アニメーション
    struct Animation {
        static let fast: Double = 0.2   // 高速
        static let normal: Double = 0.3 // 通常
        static let slow: Double = 0.4   // 低速
    }
}

// MARK: - Color拡張（ヘックスカラー対応）
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
}
