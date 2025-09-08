import Foundation

/// クリップボードアイテムのデータモデル
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFavorite: Bool
    
    init(content: String, isFavorite: Bool = false) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
    }
    
    /// 表示用の短縮テキスト（長すぎる場合は省略）
    var displayText: String {
        if content.count > 50 {
            return String(content.prefix(47)) + "..."
        }
        return content
    }
    
    /// 表示用のタイムスタンプ
    var displayTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

/// クリップボードデータの管理クラス
class ClipboardDataManager: ObservableObject {
    @Published var historyItems: [ClipboardItem] = []
    @Published var favoriteItems: [ClipboardItem] = []
    
    private let maxHistoryCount = 50
    private let historyKey = "ClipboardHistory"
    private let favoritesKey = "ClipboardFavorites"
    
    init() {
        loadData()
    }
    
    /// 新しいクリップボードアイテムを履歴に追加
    func addToHistory(_ content: String) {
        // 空の文字列や重複をチェック
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 重複チェック（直近のアイテムと同じ内容の場合は追加しない）
        if let lastItem = historyItems.first, lastItem.content == content {
            return
        }
        
        let newItem = ClipboardItem(content: content)
        historyItems.insert(newItem, at: 0)
        
        // 最大件数を超えた場合は古いアイテムを削除
        if historyItems.count > maxHistoryCount {
            historyItems = Array(historyItems.prefix(maxHistoryCount))
        }
        
        saveData()
    }
    
    /// アイテムをお気に入りに追加
    func addToFavorites(_ item: ClipboardItem) {
        // 既にお気に入りに存在するかチェック
        if !favoriteItems.contains(where: { $0.content == item.content }) {
            let favoriteItem = ClipboardItem(content: item.content, isFavorite: true)
            favoriteItems.append(favoriteItem)
            saveData()
        }
    }
    
    /// お気に入りからアイテムを削除
    func removeFromFavorites(_ item: ClipboardItem) {
        favoriteItems.removeAll { $0.id == item.id }
        saveData()
    }
    
    /// 履歴からアイテムを削除
    func removeFromHistory(_ item: ClipboardItem) {
        historyItems.removeAll { $0.id == item.id }
        saveData()
    }
    
    /// すべての履歴をクリア
    func clearHistory() {
        historyItems.removeAll()
        saveData()
    }
    
    /// すべてのお気に入りをクリア
    func clearFavorites() {
        favoriteItems.removeAll()
        saveData()
    }
    
    /// データをUserDefaultsに保存
    private func saveData() {
        do {
            let historyData = try JSONEncoder().encode(historyItems)
            let favoritesData = try JSONEncoder().encode(favoriteItems)
            
            UserDefaults.standard.set(historyData, forKey: historyKey)
            UserDefaults.standard.set(favoritesData, forKey: favoritesKey)
        } catch {
            print("データの保存に失敗しました: \(error)")
        }
    }
    
    /// UserDefaultsからデータを読み込み
    private func loadData() {
        do {
            if let historyData = UserDefaults.standard.data(forKey: historyKey) {
                historyItems = try JSONDecoder().decode([ClipboardItem].self, from: historyData)
            }
            
            if let favoritesData = UserDefaults.standard.data(forKey: favoritesKey) {
                favoriteItems = try JSONDecoder().decode([ClipboardItem].self, from: favoritesData)
            }
        } catch {
            print("データの読み込みに失敗しました: \(error)")
        }
    }
}

