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
            // よりモダンなアイコンに変更
            button.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "クリップボードマネージャー")
            button.image?.size = NSSize(width: 18, height: 18)
            button.imagePosition = .imageOnly
            
            // ホバー効果の追加
            button.appearsDisabled = false
            button.isBordered = false
            
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }
    
    /// ステータスバーボタンがクリックされた時の処理
    @objc private func statusBarButtonClicked() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        // 履歴セクション（履歴 + スニペット）
        let recentItems = dataManager.historyItems.prefix(5)
        let snippetItems = dataManager.favoriteItems.prefix(5)
        
        if !recentItems.isEmpty || !snippetItems.isEmpty {
            let historyTitle = NSMenuItem(title: "直近のコピー履歴", action: nil, keyEquivalent: "")
            historyTitle.isEnabled = false
            menu.addItem(historyTitle)
            
            // 最近の履歴アイテムを表示（最大5件）
            for item in recentItems {
                let menuItem = NSMenuItem(title: "  \(item.displayText)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item.content
                menu.addItem(menuItem)
            }
            
            // スニペットを表示（最大5件）
            if !snippetItems.isEmpty {
                menu.addItem(NSMenuItem.separator())
                let snippetTitle = NSMenuItem(title: "  ⭐ スニペット", action: nil, keyEquivalent: "")
                snippetTitle.isEnabled = false
                menu.addItem(snippetTitle)
                
                for item in snippetItems {
                    let menuItem = NSMenuItem(title: "    \(item.displayText)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.representedObject = item.content
                    menu.addItem(menuItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        
        // 管理メニュー
        let manageMenuItem = NSMenuItem(title: "⚙️ 履歴を管理...", action: #selector(openHistoryWindow), keyEquivalent: "")
        manageMenuItem.target = self
        menu.addItem(manageMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 終了メニュー
        let quitMenuItem = NSMenuItem(title: "🚪 終了", action: #selector(quitApplication), keyEquivalent: "q")
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

