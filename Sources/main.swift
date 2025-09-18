import Cocoa

// アプリケーションのエントリーポイント
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager: ClipboardManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // アプリケーションの設定
        setupApplication()
        
        // メインウィンドウを非表示にする（常駐アプリのため）
        NSApp.setActivationPolicy(.accessory)
        
        // アクセシビリティ権限の確認
        checkAccessibilityPermission()
        
        // クリップボードマネージャーを初期化
        clipboardManager = ClipboardManager()
    }
    
    /// アプリケーションの設定
    private func setupApplication() {
        // アプリケーションの情報を設定（読み取り専用のため、実際の設定は不要）
        // Bundle.main.infoDictionaryは読み取り専用
    }
    
    /// アクセシビリティ権限の確認
    private func checkAccessibilityPermission() {
        // アクセシビリティ権限をチェック（プロンプト表示なし）
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            print("アクセシビリティ権限が必要です。システム環境設定 > セキュリティとプライバシー > プライバシー > アクセシビリティで許可してください。")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // アプリケーション終了時の処理
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// アプリケーションを起動
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
