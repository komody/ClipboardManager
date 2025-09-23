import Cocoa
import SwiftUI

/// 履歴管理ウィンドウのコントローラー
class HistoryWindowController: NSWindowController {
    private let dataManager: ClipboardDataManager
    private var localKeyMonitor: Any?
    
    init(dataManager: ClipboardDataManager) {
        self.dataManager = dataManager
        
        // ウィンドウを作成
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "クリップボード履歴管理"
        window.center()
        window.setFrameAutosaveName("HistoryWindow")
        
        // SwiftUIビューを設定
        let contentView = HistoryView(dataManager: dataManager)
        let hostingController = NSHostingController(rootView: contentView)
        
        window.contentViewController = hostingController
        
        // ウィンドウの最小サイズを設定
        window.minSize = NSSize(width: 600, height: 400)
        
        // キーボードショートカットとメニューを有効化
        window.acceptsMouseMovedEvents = true
        window.makeKeyAndOrderFront(nil)
        
        // ウィンドウが閉じられた時の処理
        window.delegate = self

        // Cmd+V を標準ペーストにフォワード（ローカルモニター）
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isCommand = event.modifierFlags.contains(.command)
            let key = event.charactersIgnoringModifiers?.lowercased()
            if isCommand && key == "v" {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                return nil // ここでイベントを消費
            }
            return event
        }
    }
}

// MARK: - NSWindowDelegate
extension HistoryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // ウィンドウが閉じられた時にコントローラーを解放
        // これにより、次回開く時に新しいインスタンスが作成される
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}

