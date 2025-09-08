import Cocoa

// アプリケーションのエントリーポイント
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager: ClipboardManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // メインウィンドウを非表示にする（常駐アプリのため）
        NSApp.setActivationPolicy(.accessory)
        
        // クリップボードマネージャーを初期化
        clipboardManager = ClipboardManager()
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
