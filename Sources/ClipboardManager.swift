import Cocoa
import Combine

/// クリップボード監視とメニューバー管理を行うクラス
@MainActor
class ClipboardManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    private var historyWindowController: HistoryWindowController?
    
    let dataManager = ClipboardDataManager()
    
    init() {
        setupStatusBar()
        startClipboardMonitoring()
    }
    
    deinit {
        // Timerは自動的に無効化される
    }
    
    /// ステータスバーの設定
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // システムのクリップボードアイコンを使用
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "クリップボードマネージャー")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }
    
    /// ステータスバーボタンがクリックされた時の処理
    @objc private func statusBarButtonClicked() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        // 履歴セクション
        if !dataManager.historyItems.isEmpty {
            let historyTitle = NSMenuItem(title: "直近のコピー履歴", action: nil, keyEquivalent: "")
            historyTitle.isEnabled = false
            menu.addItem(historyTitle)
            
            // 履歴アイテムを追加（最大10件表示）
            let displayCount = min(dataManager.historyItems.count, 10)
            for i in 0..<displayCount {
                let item = dataManager.historyItems[i]
                let menuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item.content
                menu.addItem(menuItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // お気に入りセクション
        if !dataManager.favoriteItems.isEmpty {
            let favoritesTitle = NSMenuItem(title: "お気に入り", action: nil, keyEquivalent: "")
            favoritesTitle.isEnabled = false
            menu.addItem(favoritesTitle)
            
            for item in dataManager.favoriteItems {
                let menuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item.content
                menu.addItem(menuItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 管理メニュー
        let manageMenuItem = NSMenuItem(title: "履歴を管理...", action: #selector(openHistoryWindow), keyEquivalent: "")
        manageMenuItem.target = self
        menu.addItem(manageMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 終了メニュー
        let quitMenuItem = NSMenuItem(title: "終了", action: #selector(quitApplication), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem.menu = menu
    }
    
    /// クリップボードにテキストをコピー
    @objc private func copyToClipboard(_ sender: NSMenuItem) {
        guard let content = sender.representedObject as? String else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
    
    /// 履歴管理ウィンドウを開く
    @objc private func openHistoryWindow() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController(dataManager: dataManager)
        }
        
        historyWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// アプリケーションを終了
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
    
    /// クリップボード監視を開始
    private func startClipboardMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboardChanges()
            }
        }
    }
    
    /// クリップボードの変更をチェック
    private func checkClipboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // クリップボードの内容を取得
            if let content = NSPasteboard.general.string(forType: .string) {
                DispatchQueue.main.async { [weak self] in
                    self?.dataManager.addToHistory(content)
                }
            }
        }
    }
}

