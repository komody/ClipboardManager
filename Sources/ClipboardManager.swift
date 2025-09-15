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
        // 孤立したスニペットを修正
        dataManager.fixOrphanedSnippets()
        
        // データ変更の監視を開始
        setupDataObserver()
    }
    
    /// データ変更の監視を設定
    private func setupDataObserver() {
        // お気に入りアイテムの変更を監視
        dataManager.$favoriteItems
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateMenuBar()
                }
            }
            .store(in: &cancellables)
        
        // お気に入りフォルダの変更を監視
        dataManager.$favoriteFolders
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateMenuBar()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        // Timerは自動的に無効化される
    }
    
    /// ステータスバーの設定
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "クリップボード履歴")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }
    
    /// メニューバーを更新
    private func updateMenuBar() {
        guard let statusItem = statusItem else { return }
        statusItem.menu = nil // 既存のメニューをクリア
        statusBarButtonClicked() // メニューを再構築
    }
    
    /// ステータスバーボタンがクリックされた時の処理
    @objc private func statusBarButtonClicked() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        // 履歴セクション（履歴 + スニペット）
        let recentItems = dataManager.historyItems.prefix(5)
        let snippetItems = dataManager.favoriteItems.prefix(10)
        
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
            
            // スニペットをフォルダ別に表示
            if !snippetItems.isEmpty {
                menu.addItem(NSMenuItem.separator())
                let snippetTitle = NSMenuItem(title: "  ⭐ スニペット", action: nil, keyEquivalent: "")
                snippetTitle.isEnabled = false
                menu.addItem(snippetTitle)
                
                // フォルダ別にスニペットをグループ化
                let snippetsByFolder = Dictionary(grouping: snippetItems) { item in
                    item.favoriteFolderId
                }
                
                // フォルダなしのスニペット（サブメニュー）
                if let unassignedSnippets = snippetsByFolder[nil], !unassignedSnippets.isEmpty {
                    let unassignedMenuItem = NSMenuItem(title: "    📁 フォルダなし", action: nil, keyEquivalent: "")
                    unassignedMenuItem.isEnabled = true
                    
                    // サブメニューを作成
                    let submenu = NSMenu()
                    for item in unassignedSnippets.prefix(5) {
                        let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                        submenuItem.target = self
                        submenuItem.representedObject = item.content
                        submenu.addItem(submenuItem)
                    }
                    
                    unassignedMenuItem.submenu = submenu
                    menu.addItem(unassignedMenuItem)
                }
                
                // フォルダ別のスニペット（サブメニュー）
                for folder in dataManager.favoriteFolders {
                    if let folderSnippets = snippetsByFolder[folder.id], !folderSnippets.isEmpty {
                        let folderMenuItem = NSMenuItem(title: "    📁 \(folder.name)", action: nil, keyEquivalent: "")
                        folderMenuItem.isEnabled = true
                        
                        // サブメニューを作成
                        let submenu = NSMenu()
                        for item in folderSnippets.prefix(5) {
                            let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                            submenuItem.target = self
                            submenuItem.representedObject = item.content
                            submenu.addItem(submenuItem)
                        }
                        
                        folderMenuItem.submenu = submenu
                        menu.addItem(folderMenuItem)
                    }
                }
                
                // 孤立したスニペット（不明なフォルダ）
                let orphanedSnippets = snippetItems.filter { item in
                    guard let folderId = item.favoriteFolderId else { return false }
                    return !dataManager.favoriteFolders.contains { $0.id == folderId }
                }
                
                if !orphanedSnippets.isEmpty {
                    let orphanedMenuItem = NSMenuItem(title: "    📁 不明なフォルダ", action: nil, keyEquivalent: "")
                    orphanedMenuItem.isEnabled = true
                    
                    // サブメニューを作成
                    let submenu = NSMenu()
                    for item in orphanedSnippets.prefix(5) {
                        let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                        submenuItem.target = self
                        submenuItem.representedObject = item.content
                        submenu.addItem(submenuItem)
                    }
                    
                    orphanedMenuItem.submenu = submenu
                    menu.addItem(orphanedMenuItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 管理メニュー
        let manageMenuItem = NSMenuItem(title: "⚙️ 履歴を管理...", action: #selector(openHistoryWindow), keyEquivalent: "")
        manageMenuItem.target = self
        menu.addItem(manageMenuItem)
        
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