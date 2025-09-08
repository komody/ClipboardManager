#!/usr/bin/env swift

import Cocoa
import Foundation

// 修正版簡易クリップボードマネージャー
class SimpleClipboardManagerV2 {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var history: [String] = []
    private let maxHistory = 10
    
    init() {
        setupStatusBar()
        startMonitoring()
        print("クリップボードマネージャーが起動しました")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "クリップボード")
            button.action = #selector(showMenu)
            button.target = self
        }
        print("ステータスバーアイコンを設定しました")
    }
    
    @objc private func showMenu() {
        let menu = NSMenu()
        
        // デバッグ情報を追加
        let debugItem = NSMenuItem(title: "履歴数: \(history.count)", action: nil, keyEquivalent: "")
        debugItem.isEnabled = false
        menu.addItem(debugItem)
        
        if history.isEmpty {
            let item = NSMenuItem(title: "履歴がありません", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for (index, text) in history.enumerated() {
                let displayText = text.count > 30 ? String(text.prefix(27)) + "..." : text
                let menuItem = NSMenuItem(title: "\(index + 1). \(displayText)", action: #selector(copyToClipboard(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = text
                menu.addItem(menuItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        print("メニューを表示しました。履歴数: \(history.count)")
    }
    
    @objc private func copyToClipboard(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("クリップボードにコピーしました: \(text.prefix(20))...")
    }
    
    @objc private func quit() {
        print("アプリケーションを終了します")
        NSApp.terminate(nil)
    }
    
    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        print("クリップボード監視を開始しました。初期changeCount: \(lastChangeCount)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        
        if currentCount != lastChangeCount {
            print("クリップボードが変更されました: \(lastChangeCount) -> \(currentCount)")
            lastChangeCount = currentCount
            
            if let text = NSPasteboard.general.string(forType: .string),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                print("新しいテキストを検出: \(text.prefix(30))...")
                
                // 重複チェック
                if history.first != text {
                    history.insert(text, at: 0)
                    print("履歴に追加しました。現在の履歴数: \(history.count)")
                    
                    // 最大件数制限
                    if history.count > maxHistory {
                        history = Array(history.prefix(maxHistory))
                        print("履歴を\(maxHistory)件に制限しました")
                    }
                } else {
                    print("重複するテキストのため追加しませんでした")
                }
            } else {
                print("空のテキストまたはテキスト以外のデータです")
            }
        }
    }
}

// アプリケーションのエントリーポイント
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager: SimpleClipboardManagerV2?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("アプリケーションが起動しました")
        NSApp.setActivationPolicy(.accessory)
        clipboardManager = SimpleClipboardManagerV2()
    }
}

// アプリケーションを起動
print("クリップボードマネージャーを起動中...")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
