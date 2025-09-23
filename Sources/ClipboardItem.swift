import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// カテゴリのデータモデル
struct Category: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let color: String // カラーコード（例: "#FF0000"）
    let isDefault: Bool // デフォルトカテゴリかどうか
    
    init(name: String, color: String = "#007AFF", isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isDefault = isDefault
    }
    
    // デフォルトカテゴリ
    static let defaultCategory = Category(name: "一般", color: "#007AFF", isDefault: true)
    
    // プリセットカテゴリ
    static let presetCategories: [Category] = [
        Category(name: "一般", color: "#007AFF", isDefault: true),
        Category(name: "URL", color: "#34C759", isDefault: true),
        Category(name: "コード", color: "#FF9500", isDefault: true),
        Category(name: "パスワード", color: "#FF3B30", isDefault: true),
        Category(name: "メモ", color: "#FFCC00", isDefault: true)
    ]
}

/// お気に入りフォルダのデータモデル
struct FavoriteFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var color: String // カラーコード
    let isDefault: Bool // デフォルトフォルダかどうか
    let createdAt: Date
    
    init(name: String, color: String = "#FF6B6B", isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isDefault = isDefault
        self.createdAt = Date()
    }
    
    // デフォルトフォルダは削除（ユーザーが作成したフォルダのみ使用）
}

/// クリップボードアイテムのデータモデル
struct ClipboardItem: Codable, Identifiable, Equatable, Transferable {
    var id: UUID
    let content: String
    var timestamp: Date
    let isFavorite: Bool
    let categoryId: UUID // カテゴリのID
    var favoriteFolderId: UUID? // お気に入りフォルダのID（お気に入りの場合のみ）
    let description: String // 説明
    
    init(content: String, isFavorite: Bool = false, categoryId: UUID? = nil, favoriteFolderId: UUID? = nil, description: String = "") {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.categoryId = categoryId ?? Category.defaultCategory.id
        self.favoriteFolderId = favoriteFolderId
        self.description = description
    }
    
    // カスタムデコーダー（既存データとの互換性のため）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        
        // categoryIdが存在しない場合はデフォルトカテゴリを使用
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId) ?? Category.defaultCategory.id
        
        // favoriteFolderIdが存在しない場合はnilを使用
        favoriteFolderId = try container.decodeIfPresent(UUID.self, forKey: .favoriteFolderId)
        
        // descriptionが存在しない場合は空文字を使用
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
    
    // コーディングキー
    private enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isFavorite, categoryId, favoriteFolderId, description
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
    
    // MARK: - Transferable
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

/// クリップボードデータの管理クラス
class ClipboardDataManager: ObservableObject {
    @Published var historyItems: [ClipboardItem] = []
    @Published var favoriteItems: [ClipboardItem] = []
    @Published var categories: [Category] = []
    @Published var favoriteFolders: [FavoriteFolder] = []
    
    private let maxHistoryCount = 50
    private let historyKey = "ClipboardHistory"
    private let favoritesKey = "ClipboardFavorites"
    private let categoriesKey = "ClipboardCategories"
    private let favoriteFoldersKey = "FavoriteFolders"
    
    init() {
        loadData()
        initializeDefaultCategories()
        initializeDefaultFavoriteFolders()
        
        // 開発用フォルダとスニペットを初期化
        initializeDevelopmentSnippets()
    }
    
    /// デフォルトカテゴリを初期化
    private func initializeDefaultCategories() {
        if categories.isEmpty {
            categories = Category.presetCategories
            saveData()
        }
    }
    
    /// デフォルトお気に入りフォルダを初期化
    private func initializeDefaultFavoriteFolders() {
        // 既存のデフォルトフォルダを削除
        let defaultFolderIds = favoriteFolders.filter { $0.isDefault }.map { $0.id }
        favoriteFolders.removeAll { $0.isDefault }
        
        // デフォルトフォルダのアイテムも削除
        favoriteItems.removeAll { item in
            guard let folderId = item.favoriteFolderId else { return false }
            return defaultFolderIds.contains(folderId)
        }
        
        saveData()
    }
    
    /// 開発用フォルダとスニペットを初期化
    func initializeDevelopmentSnippets() {
        // 既存の開発用フォルダがあるかチェック
        let existingFolders = ["Git", "React", "Laravel"]
        let hasExistingFolders = favoriteFolders.contains { existingFolders.contains($0.name) }
        
        print("DEBUG: 開発用スニペット初期化 - 既存フォルダ: \(hasExistingFolders)")
        print("DEBUG: 現在のフォルダ数: \(favoriteFolders.count)")
        for folder in favoriteFolders {
            print("DEBUG: フォルダ: \(folder.name)")
        }
        
        if !hasExistingFolders {
            // Git フォルダとスニペット
            let gitSnippets = [
                ("git init", "新しいGitリポジトリを初期化"),
                ("git clone <url>", "リモートリポジトリをクローン"),
                ("git add .", "すべての変更をステージング"),
                ("git commit -m \"<message>\"", "変更をコミット"),
                ("git push origin main", "メインブランチにプッシュ"),
                ("git pull origin main", "リモートから最新を取得"),
                ("git branch <branch-name>", "新しいブランチを作成"),
                ("git checkout <branch-name>", "ブランチを切り替え"),
                ("git merge <branch-name>", "ブランチをマージ"),
                ("git status", "リポジトリの状態を確認")
            ]
            createFolderWithSnippets(folderName: "Git", folderColor: "F97316", snippets: gitSnippets)
            
            // React フォルダとスニペット
            let reactSnippets = [
                ("npx create-react-app <app-name>", "新しいReactアプリを作成"),
                ("npm start", "開発サーバーを起動"),
                ("npm run build", "プロダクションビルド"),
                ("npm test", "テストを実行"),
                ("import React from 'react'", "Reactをインポート"),
                ("const [state, setState] = useState(initial)", "useStateフック"),
                ("useEffect(() => {}, [])", "useEffectフック"),
                ("<div className=\"container\">", "JSX要素"),
                ("export default Component", "コンポーネントをエクスポート"),
                ("props.children", "子要素にアクセス")
            ]
            createFolderWithSnippets(folderName: "React", folderColor: "3B82F6", snippets: reactSnippets)
            
            // Laravel フォルダとスニペット
            let laravelSnippets = [
                ("composer create-project laravel/laravel <project-name>", "新しいLaravelプロジェクトを作成"),
                ("php artisan serve", "開発サーバーを起動"),
                ("php artisan make:controller <ControllerName>", "コントローラーを作成"),
                ("php artisan make:model <ModelName>", "モデルを作成"),
                ("php artisan make:migration <migration_name>", "マイグレーションを作成"),
                ("php artisan migrate", "マイグレーションを実行"),
                ("php artisan route:list", "ルート一覧を表示"),
                ("php artisan tinker", "Tinkerを起動"),
                ("php artisan cache:clear", "キャッシュをクリア"),
                ("php artisan config:cache", "設定をキャッシュ")
            ]
            createFolderWithSnippets(folderName: "Laravel", folderColor: "EF4444", snippets: laravelSnippets)
        }
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
    func addToFavorites(_ item: ClipboardItem, to folderId: UUID? = nil) {
        // 既にお気に入りに存在するかチェック
        if !favoriteItems.contains(where: { $0.content == item.content }) {
            let favoriteItem = ClipboardItem(
                content: item.content, 
                isFavorite: true, 
                categoryId: item.categoryId,
                favoriteFolderId: folderId,
                description: item.description
            )
            favoriteItems.append(favoriteItem)
            saveData()
        }
    }
    
    /// お気に入りからアイテムを削除
    func removeFromFavorites(_ item: ClipboardItem) {
        favoriteItems.removeAll { $0.id == item.id }
        saveData()
    }
    
    /// お気に入りアイテムのフォルダを変更
    func changeFavoriteFolder(_ item: ClipboardItem, to folderId: UUID) {
        guard let index = favoriteItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        let updatedItem = ClipboardItem(
            content: item.content,
            isFavorite: item.isFavorite,
            categoryId: item.categoryId,
            favoriteFolderId: folderId,
            description: item.description
        )
        favoriteItems[index] = updatedItem
        saveData()
    }
    
    /// お気に入りアイテムを編集
    func updateFavoriteItem(_ item: ClipboardItem) {
        guard let index = favoriteItems.firstIndex(where: { $0.id == item.id }) else { 
            print("編集エラー: アイテムが見つかりません (ID: \(item.id))")
            return 
        }
        print("編集前の説明: '\(favoriteItems[index].description)'")
        favoriteItems[index] = item
        print("編集後の説明: '\(favoriteItems[index].description)'")
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
    
    // MARK: - カテゴリ管理
    
    /// カスタムカテゴリを追加
    func addCategory(name: String, color: String = "#007AFF") {
        let newCategory = Category(name: name, color: color, isDefault: false)
        categories.append(newCategory)
        saveData()
    }
    
    /// カテゴリを削除
    func deleteCategory(_ category: Category) {
        // デフォルトカテゴリは削除できない
        guard !category.isDefault else { return }
        
        // 削除するカテゴリのアイテムをデフォルトカテゴリに移動
        let defaultCategoryId = Category.defaultCategory.id
        for i in 0..<historyItems.count {
            if historyItems[i].categoryId == category.id {
                let updatedItem = ClipboardItem(
                    content: historyItems[i].content,
                    isFavorite: historyItems[i].isFavorite,
                    categoryId: defaultCategoryId
                )
                historyItems[i] = updatedItem
            }
        }
        
        for i in 0..<favoriteItems.count {
            if favoriteItems[i].categoryId == category.id {
                let updatedItem = ClipboardItem(
                    content: favoriteItems[i].content,
                    isFavorite: favoriteItems[i].isFavorite,
                    categoryId: defaultCategoryId
                )
                favoriteItems[i] = updatedItem
            }
        }
        
        categories.removeAll { $0.id == category.id }
        saveData()
    }
    
    /// カテゴリを更新
    func updateCategory(_ category: Category, name: String, color: String) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let updatedCategory = Category(name: name, color: color, isDefault: category.isDefault)
        categories[index] = updatedCategory
        saveData()
    }
    
    /// アイテムのカテゴリを変更
    func changeItemCategory(_ item: ClipboardItem, to categoryId: UUID) {
        let updatedItem = ClipboardItem(
            content: item.content,
            isFavorite: item.isFavorite,
            categoryId: categoryId
        )
        
        // 履歴から更新
        if let index = historyItems.firstIndex(where: { $0.id == item.id }) {
            historyItems[index] = updatedItem
        }
        
        // お気に入りから更新
        if let index = favoriteItems.firstIndex(where: { $0.id == item.id }) {
            favoriteItems[index] = updatedItem
        }
        
        saveData()
    }
    
    /// カテゴリIDからカテゴリを取得
    func getCategory(by id: UUID) -> Category {
        return categories.first { $0.id == id } ?? Category.defaultCategory
    }
    
    /// カテゴリ別にアイテムをグループ化
    func getItemsByCategory() -> [UUID: [ClipboardItem]] {
        var grouped: [UUID: [ClipboardItem]] = [:]
        
        for item in historyItems {
            if grouped[item.categoryId] == nil {
                grouped[item.categoryId] = []
            }
            grouped[item.categoryId]?.append(item)
        }
        
        return grouped
    }
    
    // MARK: - お気に入りフォルダ管理
    
    /// カスタムお気に入りフォルダを追加
    func addFavoriteFolder(name: String, color: String = "#FF6B6B") {
        let newFolder = FavoriteFolder(name: name, color: color, isDefault: false)
        favoriteFolders.append(newFolder)
        saveData()
    }
    
    /// お気に入りフォルダの色を更新
    func updateFavoriteFolderColor(_ folder: FavoriteFolder, to color: String) {
        guard let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        var updatedFolder = favoriteFolders[index]
        updatedFolder.color = color
        favoriteFolders[index] = updatedFolder
        saveData()
    }
    
    /// 孤立したスニペットをフォルダなしに移動
    func fixOrphanedSnippets() {
        let validFolderIds = Set(favoriteFolders.map { $0.id })
        var hasChanges = false
        
        for i in 0..<favoriteItems.count {
            if let folderId = favoriteItems[i].favoriteFolderId,
               !validFolderIds.contains(folderId) {
                print("[] 孤立したスニペットを修正: '\(favoriteItems[i].content)' (フォルダID: \(folderId))")
                favoriteItems[i].favoriteFolderId = nil
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveData()
            print("[] 孤立したスニペットの修正完了")
        }
    }
    
    /// お気に入りフォルダを削除
    func deleteFavoriteFolder(_ folder: FavoriteFolder) {
        // デフォルトフォルダは削除できない
        guard !folder.isDefault else { return }
        
        // 削除するフォルダのアイテムをデフォルトフォルダに移動
        // デフォルトフォルダは使用しない
        for i in 0..<favoriteItems.count {
            if favoriteItems[i].favoriteFolderId == folder.id {
                let updatedItem = ClipboardItem(
                    content: favoriteItems[i].content,
                    isFavorite: favoriteItems[i].isFavorite,
                    categoryId: favoriteItems[i].categoryId,
                    favoriteFolderId: nil
                )
                favoriteItems[i] = updatedItem
            }
        }
        
        favoriteFolders.removeAll { $0.id == folder.id }
        saveData()
    }
    
    /// お気に入りフォルダを更新
    func updateFavoriteFolder(_ folder: FavoriteFolder, name: String, color: String) {
        guard let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        let updatedFolder = FavoriteFolder(name: name, color: color, isDefault: folder.isDefault)
        favoriteFolders[index] = updatedFolder
        saveData()
    }
    
    /// お気に入りフォルダIDからフォルダを取得
    func getFavoriteFolder(by id: UUID) -> FavoriteFolder? {
        return favoriteFolders.first { $0.id == id }
    }
    
    /// お気に入りフォルダ別にアイテムをグループ化
    func getFavoritesByFolder() -> [UUID: [ClipboardItem]] {
        var grouped: [UUID: [ClipboardItem]] = [:]
        
        for item in favoriteItems {
            guard let folderId = item.favoriteFolderId else { continue }
            if grouped[folderId] == nil {
                grouped[folderId] = []
            }
            grouped[folderId]?.append(item)
        }
        
        return grouped
    }
    
    /// お気に入りフォルダを更新
    func updateFavoriteFolder(_ folderId: UUID, name: String, color: String) {
        if let index = favoriteFolders.firstIndex(where: { $0.id == folderId }) {
            favoriteFolders[index].name = name
            favoriteFolders[index].color = color
            saveData()
        }
    }
    
    /// スニペットをフォルダに移動
    func moveSnippetsToFolder(_ snippetIds: [UUID], to folderId: UUID?) {
        for snippetId in snippetIds {
            if let index = favoriteItems.firstIndex(where: { $0.id == snippetId }) {
                favoriteItems[index].favoriteFolderId = folderId
            }
        }
        saveData()
    }
    
    /// フォルダとスニペットを一括作成するヘルパー関数
    func createFolderWithSnippets(folderName: String, folderColor: String, snippets: [(content: String, description: String)]) {
        // フォルダを作成
        let newFolder = FavoriteFolder(name: folderName, color: folderColor, isDefault: false)
        favoriteFolders.append(newFolder)
        
        // スニペットを追加
        for snippet in snippets {
            let newItem = ClipboardItem(
                content: snippet.content,
                isFavorite: true,
                categoryId: nil,
                favoriteFolderId: newFolder.id,
                description: snippet.description
            )
            favoriteItems.append(newItem)
        }
        
        print("DEBUG: フォルダ '\(folderName)' 作成完了 - スニペット数: \(snippets.count)")
        print("DEBUG: 総スニペット数: \(favoriteItems.count)")
        
        // 作成されたスニペットの詳細をログ出力
        let folderSnippets = favoriteItems.filter { $0.favoriteFolderId == newFolder.id }
        print("DEBUG: フォルダ '\(folderName)' のスニペット詳細:")
        for (index, snippet) in folderSnippets.enumerated() {
            print("DEBUG:  スニペット \(index + 1): '\(snippet.content.prefix(20))...' - フォルダID: \(snippet.favoriteFolderId?.uuidString ?? "nil")")
        }
        
        saveData()
        
        // メニューバーの更新を通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("UpdateMenuBar"), object: nil)
        }
    }
    
    /// スニペットの並び替え
    func reorderSnippets(from source: IndexSet, to destination: Int, in folderId: UUID?) {
        // 指定されたフォルダのスニペットのみを取得
        let targetFolderSnippets = favoriteItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId == nil
            } else {
                return item.favoriteFolderId == folderId
            }
        }
        let otherSnippets = favoriteItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId != nil
            } else {
                return item.favoriteFolderId != folderId
            }
        }
        
        // 対象フォルダ内のスニペットを並び替え
        var reorderedSnippets = targetFolderSnippets
        reorderedSnippets.move(fromOffsets: source, toOffset: destination)
        
        // 全体のリストを再構築
        var newFavoriteItems: [ClipboardItem] = []
        
        // 対象フォルダのスニペットを新しい順序で追加
        newFavoriteItems.append(contentsOf: reorderedSnippets)
        
        // 他のフォルダのスニペットを追加
        newFavoriteItems.append(contentsOf: otherSnippets)
        
        // リストを更新
        favoriteItems = newFavoriteItems
        
        saveData()
    }
    
    /// フォルダ内のスニペットを指定された順序で並び替え
    @MainActor
    func reorderSnippetsInFolder(_ reorderedSnippets: [ClipboardItem], folderId: UUID?) {
        Logger.shared.log("reorderSnippetsInFolder called with \(reorderedSnippets.count) snippets, folderId: \(folderId?.uuidString ?? "nil")")
        
        // 指定されたフォルダ以外のスニペットを取得
        let otherSnippets = favoriteItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId != nil
            } else {
                return item.favoriteFolderId != folderId
            }
        }
        
        Logger.shared.log("Found \(otherSnippets.count) other snippets")
        
        // 全体のリストを再構築
        var newFavoriteItems: [ClipboardItem] = []
        
        // 並び替えられたスニペットを追加
        newFavoriteItems.append(contentsOf: reorderedSnippets)
        
        // 他のフォルダのスニペットを追加
        newFavoriteItems.append(contentsOf: otherSnippets)
        
        Logger.shared.log("New favoriteItems count: \(newFavoriteItems.count)")
        
        // リストを更新
        favoriteItems = newFavoriteItems
        
        // UI更新を通知
        objectWillChange.send()
        
        saveData()
        Logger.shared.log("reorderSnippetsInFolder completed")
    }

    /// データをUserDefaultsに保存
    func saveData() {
        do {
            let historyData = try JSONEncoder().encode(historyItems)
            let favoritesData = try JSONEncoder().encode(favoriteItems)
            let categoriesData = try JSONEncoder().encode(categories)
            let favoriteFoldersData = try JSONEncoder().encode(favoriteFolders)
            
            UserDefaults.standard.set(historyData, forKey: historyKey)
            UserDefaults.standard.set(favoritesData, forKey: favoritesKey)
            UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
            UserDefaults.standard.set(favoriteFoldersData, forKey: favoriteFoldersKey)
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
            
            if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey) {
                categories = try JSONDecoder().decode([Category].self, from: categoriesData)
            }
            
            if let favoriteFoldersData = UserDefaults.standard.data(forKey: favoriteFoldersKey) {
                favoriteFolders = try JSONDecoder().decode([FavoriteFolder].self, from: favoriteFoldersData)
            }
        } catch {
            print("データの読み込みに失敗しました: \(error)")
            // エラーが発生した場合は既存データをクリアして新しく開始
            historyItems = []
            favoriteItems = []
            categories = []
            favoriteFolders = []
        }
    }
}

