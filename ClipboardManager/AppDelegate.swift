import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager: ClipboardManager?
    private var window: NSWindow?

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
    
    // アプリケーションがアクティブになった時の処理
    func applicationDidBecomeActive(_ notification: Notification) {
        // 必要に応じて処理を追加
    }
    
    // アプリケーションが非アクティブになった時の処理
    func applicationDidResignActive(_ notification: Notification) {
        // 必要に応じて処理を追加
    }
}

