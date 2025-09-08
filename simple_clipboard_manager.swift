#!/usr/bin/env swift

import Cocoa
import Foundation

// 簡易版クリップボードマネージャー
class SimpleClipboardManager {
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var history: [String] = []
    private let maxHistory = 10
    
    init() {
        setupStatusBar()
        startMonitoring()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "クリップボード")
            button.action = #selector(showMenu)
            button.target = self
        }
    }
    
    @objc private func showMenu() {
        let menu = NSMenu()
        
        if history.isEmpty {
            let item = NSMenuItem(title: "履歴がありません", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for (index, text) in history.enumerated() {
                let displayText = text.count > 30 ? String(text.prefix(27)) + "..." : text
                let menuItem = NSMenuItem(title: displayText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
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
    }
    
    @objc private func copyToClipboard(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            
            if let text = NSPasteboard.general.string(forType: .string),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                // 重複チェック
                if history.first != text {
                    history.insert(text, at: 0)
                    
                    // 最大件数制限
                    if history.count > maxHistory {
                        history = Array(history.prefix(maxHistory))
                    }
                }
            }
        }
    }
}

// アプリケーションのエントリーポイント
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager: SimpleClipboardManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        clipboardManager = SimpleClipboardManager()
    }
}

// アプリケーションを起動
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

