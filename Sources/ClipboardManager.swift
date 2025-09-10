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
        
        // 履歴セクション（カテゴリ別表示）
        let groupedItems = dataManager.getItemsByCategory()
        if !groupedItems.isEmpty {
            let historyTitle = NSMenuItem(title: "直近のコピー履歴", action: nil, keyEquivalent: "")
            historyTitle.isEnabled = false
            menu.addItem(historyTitle)
            
            // カテゴリ別に表示
            for category in dataManager.categories {
                if let items = groupedItems[category.id], !items.isEmpty {
                    // カテゴリ名を追加
                    let categoryItem = NSMenuItem(title: "  📁 \(category.name)", action: nil, keyEquivalent: "")
                    categoryItem.isEnabled = false
                    menu.addItem(categoryItem)
                    
                    // そのカテゴリのアイテムを追加（最大5件）
                    let displayCount = min(items.count, 5)
                    for i in 0..<displayCount {
                        let item = items[i]
                        let menuItem = NSMenuItem(title: "    \(item.displayText)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                        menuItem.target = self
                        menuItem.representedObject = item.content
                        menu.addItem(menuItem)
                    }
                }
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // お気に入りセクション（フォルダ別表示）
        let groupedFavorites = dataManager.getFavoritesByFolder()
        if !groupedFavorites.isEmpty {
            let favoritesTitle = NSMenuItem(title: "⭐ お気に入り", action: nil, keyEquivalent: "")
            favoritesTitle.isEnabled = false
            menu.addItem(favoritesTitle)
            
            // フォルダ別に表示
            for folder in dataManager.favoriteFolders {
                if let items = groupedFavorites[folder.id], !items.isEmpty {
                    // フォルダ名を追加（より見やすいアイコン）
                    let folderItem = NSMenuItem(title: "  📂 \(folder.name)", action: nil, keyEquivalent: "")
                    folderItem.isEnabled = false
                    menu.addItem(folderItem)
                    
                    // そのフォルダのアイテムを追加（最大5件）
                    let displayCount = min(items.count, 5)
                    for i in 0..<displayCount {
                        let item = items[i]
                        let menuItem = NSMenuItem(title: "    • \(item.displayText)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                        menuItem.target = self
                        menuItem.representedObject = item.content
                        menu.addItem(menuItem)
                    }
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

