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
        
        // グローバルキーボードイベントの監視を開始
        setupGlobalKeyboardMonitoring()
        
        // メニューバー更新通知の監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarUpdateNotification),
            name: NSNotification.Name("UpdateMenuBar"),
            object: nil
        )
        
        // 初期メニューバー更新（少し遅延させてデータが完全に読み込まれてから実行）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMenuBar()
        }
    }
    
    /// データ変更の監視を設定
    private func setupDataObserver() {
        // 履歴アイテムの変更を監視
        dataManager.$historyItems
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateMenuBar()
                }
            }
            .store(in: &cancellables)
        
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
    private nonisolated(unsafe) var globalKeyboardMonitor: Any?
    
    @objc private func handleMenuBarUpdateNotification() {
        updateMenuBar()
    }
    
    deinit {
        // Timerは自動的に無効化される
        // グローバルキーボード監視のクリーンアップ
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // 通知の監視を停止
        NotificationCenter.default.removeObserver(self)
    }
    
    /// グローバルキーボードイベントの監視を設定
    private func setupGlobalKeyboardMonitoring() {
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Option+Cでマウス位置にメニューを表示
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.option) && 
               event.keyCode == 8 { // C key
                Task { @MainActor in
                    self?.showMenuAtMousePosition()
                }
            }
        }
    }
    
    /// マウス位置にメニューを表示
    private func showMenuAtMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let menu = createClipboardMenu()
        
        // メニューをマウス位置に表示
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }
    
    /// クリップボードメニューを作成
    private func createClipboardMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 履歴セクション（履歴 + スニペット）
        let recentItems = dataManager.historyItems.prefix(10)
        let snippetItems = dataManager.favoriteItems
        
        if !recentItems.isEmpty || !snippetItems.isEmpty {
            // 履歴をサブメニューで表示
            if !recentItems.isEmpty {
                let historyMenuItem = NSMenuItem(title: "📋 履歴", action: nil, keyEquivalent: "")
                historyMenuItem.isEnabled = true
                
                // 履歴のサブメニューを作成
                let historySubmenu = NSMenu()
                for item in recentItems {
                    let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                    submenuItem.target = self
                    submenuItem.representedObject = item.content
                    historySubmenu.addItem(submenuItem)
                }
                
                historyMenuItem.submenu = historySubmenu
                menu.addItem(historyMenuItem)
                
                // 履歴とスニペットの間に区切り線を追加
                menu.addItem(NSMenuItem.separator())
            }
            
            // スニペットをフォルダ別に表示（サブメニュー構造）
            if !snippetItems.isEmpty {
                // スニペット見出しを追加
                let snippetTitle = NSMenuItem(title: "スニペット", action: #selector(doNothing), keyEquivalent: "")
                snippetTitle.target = self
                snippetTitle.isEnabled = true
                menu.addItem(snippetTitle)
                
                // 直接フィルタリングを使用するため、グループ化は不要
                
                
                // フォルダ別のスニペット（サブメニュー）
                for folder in dataManager.favoriteFolders {
                    // 直接フィルタリングを使用（snippetsByFolderの問題を回避）
                    let folderSnippets = snippetItems.filter { $0.favoriteFolderId == folder.id }
                    if !folderSnippets.isEmpty {
                        let folderMenuItem = NSMenuItem(title: "📁 \(folder.name)", action: nil, keyEquivalent: "")
                        folderMenuItem.isEnabled = true
                        
                        // サブメニューを作成（スクロール可能）
                        let submenu = NSMenu()
                        
                        // すべてのスニペットを表示（NSMenuの自動スクロール機能を使用）
                        for item in folderSnippets {
                            let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                            submenuItem.target = self
                            submenuItem.representedObject = item.content
                            submenu.addItem(submenuItem)
                        }
                        
                        // メニューの幅を設定（スクロール表示を改善）
                        submenu.minimumWidth = 200
                        
                        folderMenuItem.submenu = submenu
                        menu.addItem(folderMenuItem)
                    }
                }
                
                // フォルダなしのスニペット（サブメニュー）
                let unassignedSnippets = snippetItems.filter { $0.favoriteFolderId == nil }
                if !unassignedSnippets.isEmpty {
                    let unassignedMenuItem = NSMenuItem(title: "📁 フォルダなし", action: nil, keyEquivalent: "")
                    unassignedMenuItem.isEnabled = true
                    
                    // サブメニューを作成（スクロール可能）
                    let submenu = NSMenu()
                    
                    // すべてのスニペットを表示（NSMenuの自動スクロール機能を使用）
                    for item in unassignedSnippets {
                        let submenuItem = NSMenuItem(title: item.displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                        submenuItem.target = self
                        submenuItem.representedObject = item.content
                        submenu.addItem(submenuItem)
                    }
                    
                    // メニューの幅を設定（スクロール表示を改善）
                    submenu.minimumWidth = 200
                    
                    unassignedMenuItem.submenu = submenu
                    menu.addItem(unassignedMenuItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 管理メニュー
        let manageMenuItem = NSMenuItem(title: "⚙️ 履歴を管理...", action: #selector(openHistoryWindow), keyEquivalent: "")
        manageMenuItem.target = self
        menu.addItem(manageMenuItem)
        
        // 履歴を管理と終了の間に区切り線を追加
        menu.addItem(NSMenuItem.separator())
        
        // 終了メニュー
        let quitMenuItem = NSMenuItem(title: "🚪 終了", action: #selector(quitApplication), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        return menu
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
        
        let menu = createClipboardMenu()
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
    
    /// 何もしないアクション（スニペット見出し用）
    @objc private func doNothing() {
        // 何もしない
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