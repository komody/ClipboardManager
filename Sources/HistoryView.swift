import SwiftUI
import AppKit
import Foundation

// MARK: - フォルダ色パレット
struct FolderColorPalette {
    static let colors: [(name: String, hex: String)] = [
        ("青", "3B82F6"),      // ブルー
        ("赤", "EF4444"),      // レッド
        ("緑", "10B981"),      // グリーン
        ("紫", "8B5CF6"),      // パープル
        ("オレンジ", "F97316"), // オレンジ
        ("ピンク", "EC4899"),   // ピンク
        ("シアン", "06B6D4"),   // シアン
        ("イエロー", "EAB308"), // イエロー
        ("グレー", "6B7280"),   // グレー
        ("インディゴ", "6366F1"), // インディゴ
        ("エメラルド", "059669"), // エメラルド
        ("ローズ", "F43F5E")    // ローズ
    ]
}

// MARK: - ログ機能
@MainActor
class Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    private init() {
        // プロジェクト内のlogsディレクトリにログファイルを保存
        let projectPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let logsDirectory = projectPath.appendingPathComponent("logs")
        
        // logsディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: logsDirectory.path) {
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
        
        logFileURL = logsDirectory.appendingPathComponent("clipboard_log.txt")
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
        
        // コンソールにも出力
        print(logMessage.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// 履歴管理画面のSwiftUIビュー
struct HistoryView: View {
    @ObservedObject var dataManager: ClipboardDataManager
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingClearAlert = false
    @State private var selectedFavoriteFolder: UUID? = nil
    @State private var showingFavoriteFolderManager = false
    @State private var showingSnippetRegistration = false
    @State private var isReorderMode = false
    @State private var hasBeenReordered = false
    @State private var reorderModeItems: [ClipboardItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // アニメーション付きタブビュー
            Picker("表示モード", selection: $selectedTab) {
                Text("履歴").tag(0)
                Text("スニペット").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
            
            // 共通検索バー
            HStack {
                SearchBar(text: $searchText, placeholder: "検索...")
                Spacer()
            }
            .padding(.horizontal, ProfessionalBlueTheme.Spacing.xl)
            
            // シンプルなコンテンツエリア
            Group {
                if selectedTab == 0 {
                    historyListView
                        .transition(.opacity)
                } else {
                    favoritesListView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(ProfessionalBlueTheme.Colors.background)
    }
    
    // MARK: - 履歴リストビュー
    private var historyListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HistoryHeaderView(
                title: "コピー履歴 (\(filteredHistoryItems.count)件)",
                onClearHistory: { showingClearAlert = true }
            )
            
            Divider()
            
            HistoryListView(
                items: filteredHistoryItems,
                dataManager: dataManager
            )
        }
        .alert("履歴をクリア", isPresented: $showingClearAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("クリア", role: .destructive) {
                dataManager.clearHistory()
            }
        } message: {
            Text("すべての履歴を削除しますか？この操作は元に戻せません。")
        }
    }
    
    // MARK: - お気に入りリストビュー
    private var favoritesListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            FavoritesHeaderView(
                title: "スニペット (\(filteredFavoriteItems.count)件)",
                selectedFolder: $selectedFavoriteFolder,
                folders: dataManager.favoriteFolders,
                onFolderManager: { showingFavoriteFolderManager = true },
                onAddSnippet: { showingSnippetRegistration = true },
                isReorderMode: $isReorderMode
            )
            
            Divider()
            
            FavoritesListView(
                items: filteredFavoriteItems,
                dataManager: dataManager,
                isReorderMode: $isReorderMode,
                hasBeenReordered: $hasBeenReordered,
                reorderModeItems: $reorderModeItems
            )
            .onChange(of: isReorderMode) { newValue in
                if !newValue {
                    Logger.shared.log("並び替えモード終了: 変更を反映中...")
                    Logger.shared.log("reorderModeItems count: \(reorderModeItems.count)")
                    Logger.shared.log("dataManager.favoriteItems count: \(dataManager.favoriteItems.count)")
                    
                    // 並び替えモード終了時に変更を反映
                    dataManager.favoriteItems = reorderModeItems
                    dataManager.saveData()
                    
                    // 並び替えが行われたことを記録
                    hasBeenReordered = true
                    Logger.shared.log("hasBeenReordered = true に設定")
                    Logger.shared.log("並び替えモード終了: 反映完了")
                }
            }
        }
        .sheet(isPresented: $showingFavoriteFolderManager) {
            FavoriteFolderManagerView(dataManager: dataManager)
        }
        .sheet(isPresented: $showingSnippetRegistration) {
            SnippetRegistrationView(
                dataManager: dataManager,
                onDismiss: { showingSnippetRegistration = false }
            )
        }
    }
    
    // MARK: - 空の状態ビュー
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == 0 ? "doc.on.clipboard" : "heart")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title2)
                .foregroundColor(.secondary)
            
            if selectedTab == 0 {
                Text("テキストをコピーすると、ここに履歴が表示されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("履歴からスニペットに追加できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - フィルタリング
    private var filteredHistoryItems: [ClipboardItem] {
        var items = dataManager.historyItems
        
        // 検索フィルター
        if !searchText.isEmpty {
            items = items.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    private var filteredFavoriteItems: [ClipboardItem] {
        var items = dataManager.favoriteItems
        
        // お気に入りフォルダフィルター
        if let selectedFavoriteFolder = selectedFavoriteFolder {
            items = items.filter { $0.favoriteFolderId == selectedFavoriteFolder }
        }
        
        // 検索フィルター
        if !searchText.isEmpty {
            items = items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 並び替えが行われた場合は、timestampでのソートを無効にする
        if hasBeenReordered {
            return items
        } else {
            return items.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    // MARK: - アクション
    private func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}

// MARK: - 履歴アイテム行
struct HistoryItemRow: View {
    let item: ClipboardItem
    let category: Category
    let onCopy: () -> Void
    let onAddToFavorites: () -> Void
    let onDelete: () -> Void
    let onChangeCategory: (UUID) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // カテゴリバッジ
                    Text(category.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: category.color).opacity(0.2))
                        .foregroundColor(Color(hex: category.color))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(item.content)
                    .font(.body)
                    .lineLimit(3)
                
                Text(item.displayTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(PlainButtonStyle())
                .help("クリップボードにコピー")
                
                Button(action: onAddToFavorites) {
                    Image(systemName: "heart")
                }
                .buttonStyle(PlainButtonStyle())
                .help("スニペットに追加")
                
                Menu {
                    Text("カテゴリを変更")
                    ForEach([Category.defaultCategory] + Category.presetCategories.filter { $0.id != category.id }) { cat in
                        Button(cat.name) {
                            onChangeCategory(cat.id)
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(PlainButtonStyle())
                .help("カテゴリを変更")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
                .help("削除")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - お気に入りアイテム行
struct FavoriteItemRow: View {
    let item: ClipboardItem
    let folder: FavoriteFolder?
    let folders: [FavoriteFolder]
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onChangeFolder: (UUID) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.content)
                        .font(.body)
                        .lineLimit(3)
                    
                    Spacer()
                    
                    // フォルダバッジ（フォルダが存在する場合のみ表示）
                    if let folder = folder {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: folder.color))
                                .frame(width: 8, height: 8)
                            Text(folder.name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                // フォルダ変更メニュー
                Menu {
                    ForEach(folders) { folder in
                        Button(folder.name) {
                            onChangeFolder(folder.id)
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("フォルダを変更")
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(PlainButtonStyle())
                .help("クリップボードにコピー")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
                .help("削除")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - カテゴリ管理画面
struct CategoryManagerView: View {
    @ObservedObject var dataManager: ClipboardDataManager
    @State private var newCategoryName = ""
    @State private var newCategoryColor = "#007AFF"
    @Environment(\.dismiss) private var dismiss
    
    let presetColors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#FFCC00", "#5AC8FA", "#FF2D92"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("カテゴリ管理")
                .font(.title2)
                .fontWeight(.bold)
            
            // 新しいカテゴリ追加
            VStack(alignment: .leading, spacing: 10) {
                Text("新しいカテゴリを追加")
                    .font(.headline)
                
                HStack {
                    TextField("カテゴリ名", text: $newCategoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    ColorPicker("色", selection: Binding(
                        get: { Color(hex: newCategoryColor) },
                        set: { newCategoryColor = $0.toHex() }
                    ))
                    .frame(width: 50)
                    
                    Button("追加") {
                        if !newCategoryName.isEmpty {
                            dataManager.addCategory(name: newCategoryName, color: newCategoryColor)
                            newCategoryName = ""
                            newCategoryColor = "#007AFF"
                        }
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // カテゴリ一覧
            List {
                ForEach(dataManager.categories) { category in
                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 20, height: 20)
                        
                        Text(category.name)
                        
                        Spacer()
                        
                        if !category.isDefault {
                            Button("削除") {
                                dataManager.deleteCategory(category)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            HStack {
                Spacer()
                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// MARK: - お気に入りフォルダ管理画面
struct FavoriteFolderManagerView: View {
    @ObservedObject var dataManager: ClipboardDataManager
    @State private var newFolderName = ""
    @State private var newFolderColor = "#FF6B6B"
    @Environment(\.dismiss) private var dismiss
    
    // フォルダ編集用の状態
    @State private var editingFolder: FavoriteFolder? = nil
    @State private var editedFolderName: String = ""
    @State private var editedFolderColor: String = ""
    
    // ドロップ処理
    private func handleDrop(providers: [NSItemProvider], targetFolder: FavoriteFolder) -> Bool {
        for provider in providers {
            provider.loadTransferable(type: ClipboardItem.self) { result in
                switch result {
                case .success(let clipboardItem):
                    DispatchQueue.main.async {
                        // スニペットを指定されたフォルダに移動
                        dataManager.moveSnippetsToFolder([clipboardItem.id], to: targetFolder.id)
                    }
                case .failure(_):
                    break
                }
            }
        }
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("スニペットフォルダ管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("完了") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // コンテンツ
            VStack(spacing: 20) {
                // 新しいフォルダ追加
                VStack(alignment: .leading, spacing: 12) {
                    Text("新しいフォルダを追加")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        TextField("フォルダ名を入力", text: $newFolderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("色:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                                ForEach(FolderColorPalette.colors, id: \.hex) { colorInfo in
                                    Button(action: {
                                        newFolderColor = colorInfo.hex
                                    }) {
                                        Circle()
                                            .fill(Color(hex: colorInfo.hex))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(newFolderColor == colorInfo.hex ? Color.primary : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .frame(maxWidth: 200)
                        }
                        
                        Button("追加") {
                            if !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                dataManager.addFavoriteFolder(name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines), color: newFolderColor)
                                newFolderName = ""
                                newFolderColor = "#FF6B6B"
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                // フォルダ一覧
                VStack(alignment: .leading, spacing: 12) {
                    Text("フォルダ一覧")
                        .font(.headline)
                    
                    if dataManager.favoriteFolders.isEmpty {
                        Text("フォルダがありません")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(dataManager.favoriteFolders) { folder in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: folder.color))
                                        .frame(width: 20, height: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name)
                                            .font(.body)
                                        
                                        if folder.isDefault {
                                            Text("デフォルトフォルダ")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !folder.isDefault {
                                        HStack(spacing: 8) {
                                            Button("編集") {
                                                editingFolder = folder
                                                editedFolderName = folder.name
                                                editedFolderColor = folder.color
                                            }
                                            .foregroundColor(.blue)
                                            .buttonStyle(.plain)
                                            
                                            Button("削除") {
                                                dataManager.deleteFavoriteFolder(folder)
                                            }
                                            .foregroundColor(.red)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .onDrop(of: [.data], isTargeted: nil) { providers in
                                    handleDrop(providers: providers, targetFolder: folder)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $editingFolder) { folder in
            FolderEditView(
                folder: folder,
                editedName: $editedFolderName,
                editedColor: $editedFolderColor,
                onSave: { newName, newColor in
                    dataManager.updateFavoriteFolder(folder.id, name: newName, color: newColor)
                    editingFolder = nil
                },
                onCancel: {
                    editingFolder = nil
                },
                dataManager: dataManager
            )
        }
    }
}

// MARK: - フォルダ編集ビュー
struct FolderEditView: View {
    let folder: FavoriteFolder
    @Binding var editedName: String
    @Binding var editedColor: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    let dataManager: ClipboardDataManager
    
    @Environment(\.dismiss) private var dismiss
    
    // スニペット移動用の状態
    @State private var selectedSnippets: Set<UUID> = []
    @State private var showingMoveDialog = false
    
    // フォルダなしのスニペットを取得
    private var unassignedSnippets: [ClipboardItem] {
        dataManager.favoriteItems.filter { $0.favoriteFolderId == nil }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            nameInputView
            colorSelectionView
            
            // フォルダなしのスニペット表示
            if !unassignedSnippets.isEmpty {
                unassignedSnippetsView
            }
            
            buttonView
        }
        .padding(24)
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("スニペットを移動", isPresented: $showingMoveDialog) {
            Button("このフォルダに移動") {
                moveSelectedSnippetsToCurrentFolder()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("選択したスニペットを「\(folder.name)」フォルダに移動しますか？")
        }
    }
    
    private var headerView: some View {
        Text("フォルダを編集")
            .font(.title2)
            .fontWeight(.bold)
    }
    
    private var nameInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("フォルダ名")
                .font(.headline)
            
            TextField("フォルダ名を入力", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var colorSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("フォルダの色")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(FolderColorPalette.colors, id: \.hex) { colorInfo in
                    colorButton(for: colorInfo)
                }
            }
        }
    }
    
    private func colorButton(for colorInfo: (name: String, hex: String)) -> some View {
        Button(action: {
            editedColor = colorInfo.hex
        }) {
            Circle()
                .fill(Color(hex: colorInfo.hex))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(editedColor == colorInfo.hex ? Color.blue : Color.clear, lineWidth: 3)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var unassignedSnippetsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("フォルダなしのスニペット")
                    .font(.headline)
                
                Spacer()
                
                if !selectedSnippets.isEmpty {
                    Button("このフォルダに移動") {
                        showingMoveDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSnippets.isEmpty)
                }
            }
            
            List {
                ForEach(unassignedSnippets) { snippet in
                    HStack(spacing: 12) {
                        Checkbox(isChecked: selectedSnippets.contains(snippet.id)) {
                            if selectedSnippets.contains(snippet.id) {
                                selectedSnippets.remove(snippet.id)
                            } else {
                                selectedSnippets.insert(snippet.id)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.content)
                                .font(.body)
                                .lineLimit(2)
                            
                            if !snippet.description.isEmpty {
                                Text(snippet.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 150)
        }
    }
    
    private var buttonView: some View {
        HStack(spacing: 12) {
            Button("キャンセル") {
                onCancel()
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("保存") {
                onSave(editedName, editedColor)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private func moveSelectedSnippetsToCurrentFolder() {
        let snippetIds = Array(selectedSnippets)
        dataManager.moveSnippetsToFolder(snippetIds, to: folder.id)
        selectedSnippets.removeAll()
    }
}


// MARK: - チェックボックスコンポーネント
struct Checkbox: View {
    let isChecked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundColor(isChecked ? .blue : .gray)
                .font(.system(size: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ヘッダービューコンポーネント
struct HistoryHeaderView: View {
    let title: String
    let onClearHistory: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(ProfessionalBlueTheme.Colors.text)
            
            Spacer()
            
            Button("履歴をクリア") {
                onClearHistory()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(6)
            .font(.system(size: 13))
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
}

// MARK: - シンプル履歴アイテム行コンポーネント
struct SimpleHistoryItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onAddToFavorites: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content)
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(ProfessionalBlueTheme.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("コピー")
                
                Button(action: onAddToFavorites) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(item.isFavorite ? .yellow : ProfessionalBlueTheme.Colors.textMuted)
                }
                .buttonStyle(PlainButtonStyle())
                .help(item.isFavorite ? "スニペットから削除" : "スニペットに追加")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("削除")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ProfessionalBlueTheme.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: ProfessionalBlueTheme.Colors.shadow.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 履歴リストビューコンポーネント
struct HistoryListView: View {
    let items: [ClipboardItem]
    let dataManager: ClipboardDataManager
    
    var body: some View {
        if items.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                
                Text("履歴がありません")
                    .font(.system(size: 16))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        SimpleHistoryItemRow(
                            item: item,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.content, forType: .string)
                            },
                            onAddToFavorites: {
                                dataManager.addToFavorites(item)
                            },
                            onDelete: {
                                dataManager.removeFromHistory(item)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: items.count)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - お気に入りヘッダービューコンポーネント
struct FavoritesHeaderView: View {
    let title: String
    @Binding var selectedFolder: UUID?
    let folders: [FavoriteFolder]
    let onFolderManager: () -> Void
    let onAddSnippet: () -> Void
    @Binding var isReorderMode: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(ProfessionalBlueTheme.Colors.text)
            
            Spacer()
            
            HStack(spacing: 12) {
                // 並び替えモード切り替えボタン
                Button(action: {
                    isReorderMode.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                            .font(.system(size: 12))
                        Text(isReorderMode ? "完了" : "並び替え")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isReorderMode ? ProfessionalBlueTheme.Colors.success : ProfessionalBlueTheme.Colors.warning)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // スニペット追加ボタン（並び替えモード時は非表示）
                if !isReorderMode {
                    Button(action: onAddSnippet) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("スニペット追加")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ProfessionalBlueTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // フォルダフィルター
                Menu {
                    Button("すべてのフォルダ") {
                        selectedFolder = nil
                    }
                    
                    ForEach(folders) { folder in
                        Button(folder.name) {
                            selectedFolder = folder.id
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                        Text(selectedFolder == nil ? "すべて" : folders.first(where: { $0.id == selectedFolder })?.name ?? "すべて")
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // フォルダ管理ボタン（並び替えモード時は非表示）
                if !isReorderMode {
                    Button("フォルダ管理") {
                        onFolderManager()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ProfessionalBlueTheme.Colors.primaryLight)
                    .foregroundColor(ProfessionalBlueTheme.Colors.primaryDark)
                    .cornerRadius(6)
                    .font(.system(size: 13))
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
    }
}

// MARK: - お気に入りリストビューコンポーネント（アコーディオン形式）
struct FavoritesListView: View {
    let items: [ClipboardItem]
    let dataManager: ClipboardDataManager
    @Binding var isReorderMode: Bool
    @Binding var hasBeenReordered: Bool
    @Binding var reorderModeItems: [ClipboardItem]
    @State private var refreshID = UUID()
    
    // フォルダなしエリアへのドロップ処理
    private func handleDropToUnassigned(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadTransferable(type: ClipboardItem.self) { result in
                switch result {
                case .success(let clipboardItem):
                    DispatchQueue.main.async {
                        // スニペットをフォルダなしに移動
                        dataManager.moveSnippetsToFolder([clipboardItem.id], to: nil)
                    }
                case .failure(_):
                    break
                }
            }
        }
        return true
    }
    @State private var expandedFolders: Set<UUID> = []
    
    var body: some View {
        if items.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "star")
                    .font(.system(size: 48))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                
                Text("スニペットがありません")
                    .font(.system(size: 16))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if isReorderMode {
            // 並び替えモード専用UI
            reorderModeView
                .id(refreshID)
                .onAppear {
                    // 並び替えモード開始時に専用の状態を初期化
                    // 現在表示されている順序（filteredFavoriteItems）を使用
                    reorderModeItems = items
                }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // フォルダ別のスニペットを表示（空のフォルダも含む）
                    ForEach(dataManager.favoriteFolders) { folder in
                        let folderItems = items.filter { $0.favoriteFolderId == folder.id }
                        let _ = Logger.shared.log("フォルダ '\(folder.name)' (ID: \(folder.id.uuidString)) のアイテム数: \(folderItems.count)")
                        
                        FolderAccordionView(
                            folder: folder,
                            items: folderItems,
                            isExpanded: expandedFolders.contains(folder.id),
                            onToggle: {
                                if expandedFolders.contains(folder.id) {
                                    expandedFolders.remove(folder.id)
                                } else {
                                    expandedFolders.insert(folder.id)
                                }
                            },
                            dataManager: dataManager
                        )
                    }
                    
                    // フォルダなしのスニペットを直接表示
                    let unassignedItems = items.filter { $0.favoriteFolderId == nil }
                    let _ = Logger.shared.log("フォルダなしアイテム数: \(unassignedItems.count)")
                    if !unassignedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // ヘッダー
                            HStack {
                                Image(systemName: "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(ProfessionalBlueTheme.Colors.warning)
                                
                                Text("フォルダなし")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ProfessionalBlueTheme.Colors.text)
                                
                                Spacer()
                                
                                Text("\(unassignedItems.count)件")
                                    .font(.system(size: 12))
                                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(ProfessionalBlueTheme.Colors.backgroundLight)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(ProfessionalBlueTheme.Colors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .onDrop(of: [.data], isTargeted: nil) { providers in
                                handleDropToUnassigned(providers: providers)
                            }
                            
                            // スニペット一覧（直接表示）
                            VStack(spacing: 4) {
                                ForEach(unassignedItems) { item in
                                    SnippetItemRow(
                                        item: item,
                                        dataManager: dataManager,
                                        onCopy: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(item.content, forType: .string)
                                        },
                                        onDelete: {
                                            dataManager.removeFromFavorites(item)
                                        },
                                        onEdit: { item in
                                            dataManager.updateFavoriteItem(item)
                                        }
                                    )
                                    .padding(.leading, 20)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .id(refreshID)
        }
    }
    
    // MARK: - 並び替えモード専用UI
    private var reorderModeView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 並び替えモードの説明
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(ProfessionalBlueTheme.Colors.warning)
                    Text("並び替えモード: 上下矢印ボタンでスニペットの順序を変更できます")
                        .font(.system(size: 14))
                        .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ProfessionalBlueTheme.Colors.warning.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                
                    // フォルダ別のスニペットを表示
                    ForEach(dataManager.favoriteFolders) { folder in
                        let folderItems = reorderModeItems.filter { $0.favoriteFolderId == folder.id }
                    
                    if !folderItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // フォルダヘッダー
                            HStack {
                                Circle()
                                    .fill(Color(hex: folder.color))
                                    .frame(width: 12, height: 12)
                                
                                Text(folder.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ProfessionalBlueTheme.Colors.text)
                                
                                Spacer()
                                
                                Text("\(folderItems.count)件")
                                    .font(.system(size: 12))
                                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(ProfessionalBlueTheme.Colors.backgroundLight)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(ProfessionalBlueTheme.Colors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                            )
                            .cornerRadius(8)
                            
                            // スニペット一覧（並び替え可能）
                            VStack(spacing: 4) {
                                ForEach(Array(folderItems.enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 8) {
                                        // 並び替えボタン
                                        VStack(spacing: 2) {
                                            Button(action: {
                                                moveSnippetUp(item: item, in: folderItems, folderId: folder.id)
                                            }) {
                                                Image(systemName: "chevron.up")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(index > 0 ? .blue : .gray)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .disabled(index == 0)
                                            
                                            Button(action: {
                                                moveSnippetDown(item: item, in: folderItems, folderId: folder.id)
                                            }) {
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(index < folderItems.count - 1 ? .blue : .gray)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .disabled(index == folderItems.count - 1)
                                        }
                                        .frame(width: 20)
                                        
                                        SnippetItemRow(
                                            item: item,
                                            dataManager: dataManager,
                                            onCopy: {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(item.content, forType: .string)
                                            },
                                            onDelete: {
                                                dataManager.removeFromFavorites(item)
                                            },
                                            onEdit: { item in
                                                dataManager.updateFavoriteItem(item)
                                            }
                                        )
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                // フォルダなしのスニペット
                let unassignedItems = reorderModeItems.filter { $0.favoriteFolderId == nil }
                if !unassignedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // ヘッダー
                        HStack {
                            Image(systemName: "star")
                                .font(.system(size: 12))
                                .foregroundColor(ProfessionalBlueTheme.Colors.warning)
                            
                            Text("フォルダなし")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ProfessionalBlueTheme.Colors.text)
                            
                            Spacer()
                            
                            Text("\(unassignedItems.count)件")
                                .font(.system(size: 12))
                                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(ProfessionalBlueTheme.Colors.backgroundLight)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ProfessionalBlueTheme.Colors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                        )
                        .cornerRadius(8)
                        
                        // スニペット一覧（並び替え可能）
                        VStack(spacing: 4) {
                            ForEach(Array(unassignedItems.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 8) {
                                    // 並び替えボタン
                                    VStack(spacing: 2) {
                                        Button(action: {
                                            moveSnippetUp(item: item, in: unassignedItems, folderId: nil)
                                        }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 12))
                                                .foregroundColor(index > 0 ? .blue : .gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(index == 0)
                                        
                                        Button(action: {
                                            moveSnippetDown(item: item, in: unassignedItems, folderId: nil)
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(index < unassignedItems.count - 1 ? .blue : .gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(index == unassignedItems.count - 1)
                                    }
                                    .frame(width: 20)
                                    
                                    SnippetItemRow(
                                        item: item,
                                        dataManager: dataManager,
                                        onCopy: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(item.content, forType: .string)
                                        },
                                        onDelete: {
                                            dataManager.removeFromFavorites(item)
                                        },
                                        onEdit: { item in
                                            dataManager.updateFavoriteItem(item)
                                        }
                                    )
                                }
                                .padding(.leading, 20)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    /// スニペットを上に移動
    private func moveSnippetUp(item: ClipboardItem, in items: [ClipboardItem], folderId: UUID?) {
        Logger.shared.log("moveSnippetUp called for item: \(item.content)")
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }),
              currentIndex > 0 else { 
            Logger.shared.log("moveSnippetUp: cannot move up - currentIndex: \(items.firstIndex(where: { $0.id == item.id }) ?? -1)")
            return 
        }
        
        Logger.shared.log("moveSnippetUp: moving from index \(currentIndex) to \(currentIndex - 1)")
        
        // reorderModeItemsから該当フォルダのスニペットを取得
        let targetFolderSnippets = reorderModeItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId == nil
            } else {
                return item.favoriteFolderId == folderId
            }
        }
        
        var reorderedItems = targetFolderSnippets
        reorderedItems.swapAt(currentIndex, currentIndex - 1)
        
        // reorderModeItemsを直接更新
        let otherSnippets = reorderModeItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId != nil
            } else {
                return item.favoriteFolderId != folderId
            }
        }
        
        reorderModeItems = reorderedItems + otherSnippets
        Logger.shared.log("moveSnippetUp: reorderModeItems updated, count: \(reorderModeItems.count)")
        
        // UI更新を確実にする
        DispatchQueue.main.async {
            self.refreshID = UUID()
        }
        Logger.shared.log("moveSnippetUp: reorder completed")
    }
    
    /// スニペットを下に移動
    private func moveSnippetDown(item: ClipboardItem, in items: [ClipboardItem], folderId: UUID?) {
        Logger.shared.log("moveSnippetDown called for item: \(item.content)")
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }),
              currentIndex < items.count - 1 else { 
            Logger.shared.log("moveSnippetDown: cannot move down - currentIndex: \(items.firstIndex(where: { $0.id == item.id }) ?? -1), count: \(items.count)")
            return 
        }
        
        Logger.shared.log("moveSnippetDown: moving from index \(currentIndex) to \(currentIndex + 1)")
        
        // reorderModeItemsから該当フォルダのスニペットを取得
        let targetFolderSnippets = reorderModeItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId == nil
            } else {
                return item.favoriteFolderId == folderId
            }
        }
        
        var reorderedItems = targetFolderSnippets
        reorderedItems.swapAt(currentIndex, currentIndex + 1)
        
        // reorderModeItemsを直接更新
        let otherSnippets = reorderModeItems.filter { item in
            if folderId == nil {
                return item.favoriteFolderId != nil
            } else {
                return item.favoriteFolderId != folderId
            }
        }
        
        reorderModeItems = reorderedItems + otherSnippets
        Logger.shared.log("moveSnippetDown: reorderModeItems updated, count: \(reorderModeItems.count)")
        
        // UI更新を確実にする
        DispatchQueue.main.async {
            self.refreshID = UUID()
        }
        Logger.shared.log("moveSnippetDown: reorder completed")
    }
    
}

// MARK: - フォルダアコーディオンビュー
struct FolderAccordionView: View {
    let folder: FavoriteFolder
    let items: [ClipboardItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    let dataManager: ClipboardDataManager
    
    // ドロップ処理
    private func handleDrop(providers: [NSItemProvider], targetFolder: FavoriteFolder) -> Bool {
        for provider in providers {
            provider.loadTransferable(type: ClipboardItem.self) { result in
                switch result {
                case .success(let clipboardItem):
                    DispatchQueue.main.async {
                        // スニペットを指定されたフォルダに移動
                        dataManager.moveSnippetsToFolder([clipboardItem.id], to: targetFolder.id)
                    }
                case .failure(_):
                    break
                }
            }
        }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // フォルダヘッダー
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ProfessionalBlueTheme.Colors.text)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    Circle()
                        .fill(Color(hex: folder.color))
                        .frame(width: 12, height: 12)
                    
                    Text(folder.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ProfessionalBlueTheme.Colors.text)
                    
                    Spacer()
                    
                    Text("\(items.count)件")
                        .font(.system(size: 12))
                        .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ProfessionalBlueTheme.Colors.backgroundLight)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ProfessionalBlueTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .onDrop(of: [.data], isTargeted: nil) { providers in
                handleDrop(providers: providers, targetFolder: folder)
            }
            
            // フォルダ内容（アコーディオン）
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        SnippetItemRow(
                            item: item,
                            dataManager: dataManager,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.content, forType: .string)
                            },
                            onDelete: {
                                dataManager.removeFromFavorites(item)
                            },
                            onEdit: { item in
                                dataManager.updateFavoriteItem(item)
                            }
                        )
                        .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
    }
    
}

// MARK: - スニペット登録ビュー
struct SnippetRegistrationView: View {
    @State private var content: String = ""
    @State private var description: String = ""
    @State private var selectedFolderId: UUID? = nil
    @State private var showingFolderManager = false
    
    let dataManager: ClipboardDataManager
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            let _ = Logger.shared.log("スニペット登録ビュー表示 - 利用可能なフォルダ数: \(dataManager.favoriteFolders.count)")
            // ヘッダー
            HStack {
                Text("新しいスニペットを登録")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ProfessionalBlueTheme.Colors.text)
                
                Spacer()
                
                Button("キャンセル") {
                    onDismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
            }
            
            // 入力フォーム
            VStack(spacing: 12) {
                // 内容フィールド（メイン）
                VStack(alignment: .leading, spacing: 4) {
                    Text("内容 *")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ProfessionalBlueTheme.Colors.text)
                    
                    TextEditor(text: $content)
                        .font(.system(size: 14))
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                        )
                        .cornerRadius(6)
                }
                
                // 説明フィールド
                VStack(alignment: .leading, spacing: 4) {
                    Text("説明（任意）")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ProfessionalBlueTheme.Colors.text)
                    
                    TextField("スニペットの説明を入力", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 14))
                }
                
                // フォルダ選択
                VStack(alignment: .leading, spacing: 4) {
                    Text("フォルダ")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ProfessionalBlueTheme.Colors.text)
                    
                    VStack(spacing: 8) {
                        Picker("フォルダ選択", selection: $selectedFolderId) {
                            Text("フォルダなし").tag(nil as UUID?)
                            ForEach(dataManager.favoriteFolders) { folder in
                                Text(folder.name).tag(folder.id as UUID?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedFolderId) { newValue in
                            Logger.shared.log("フォルダ選択変更: \(newValue?.uuidString ?? "nil")")
                        }
                        
                        Button("フォルダ管理") {
                            showingFolderManager = true
                        }
                        .font(.system(size: 12))
                        .foregroundColor(ProfessionalBlueTheme.Colors.primary)
                    }
                }
            }
            
            // ボタン
            HStack(spacing: 12) {
                Button("キャンセル") {
                    onDismiss()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                
                Spacer()
                
                Button("登録") {
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Logger.shared.log("登録時のselectedFolderId: \(selectedFolderId?.uuidString ?? "nil")")
                        let newItem = ClipboardItem(
                            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                            favoriteFolderId: selectedFolderId,
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        Logger.shared.log("作成されたアイテムのfavoriteFolderId: \(newItem.favoriteFolderId?.uuidString ?? "nil")")
                        Logger.shared.log("作成されたアイテムのdescription: '\(newItem.description)'")
                        dataManager.addToFavorites(newItem, to: selectedFolderId)
                        onDismiss()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                           ProfessionalBlueTheme.Colors.textMuted : ProfessionalBlueTheme.Colors.primary)
                .cornerRadius(6)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .background(ProfessionalBlueTheme.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
        )
        .cornerRadius(12)
        .sheet(isPresented: $showingFolderManager) {
            FavoriteFolderManagerView(dataManager: dataManager)
        }
    }
}

// MARK: - スニペットアイテム行
struct SnippetItemRow: View {
    let item: ClipboardItem
    let dataManager: ClipboardDataManager
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onEdit: (ClipboardItem) -> Void
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var editedDescription = ""
    @State private var editedFolderId: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                // 編集モード
                VStack(alignment: .leading, spacing: 8) {
                    // コンテンツ編集（メイン）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("内容")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ProfessionalBlueTheme.Colors.text)
                        
                        TextField("内容を入力", text: $editedContent, axis: .vertical)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ProfessionalBlueTheme.Colors.backgroundLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                            )
                            .cornerRadius(4)
                            .lineLimit(3...6)
                    }
                    
                    // 説明編集
                    VStack(alignment: .leading, spacing: 4) {
                        Text("説明")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ProfessionalBlueTheme.Colors.text)
                        
                        TextField("説明を入力", text: $editedDescription)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ProfessionalBlueTheme.Colors.backgroundLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                            )
                            .cornerRadius(4)
                    }
                    
                    // フォルダ選択
                    VStack(alignment: .leading, spacing: 4) {
                        Text("フォルダ")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ProfessionalBlueTheme.Colors.text)
                        
                        Picker("フォルダを選択", selection: $editedFolderId) {
                            Text("フォルダなし").tag(nil as UUID?)
                            ForEach(dataManager.favoriteFolders) { folder in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: folder.color))
                                        .frame(width: 12, height: 12)
                                    Text(folder.name)
                                }
                                .tag(folder.id as UUID?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ProfessionalBlueTheme.Colors.backgroundLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
                        )
                        .cornerRadius(4)
                    }
                    
                    // 編集ボタン
                    HStack(spacing: 8) {
                        Button("保存") {
                            // 編集内容を保存
                            Logger.shared.log("編集保存開始 - 元の説明: '\(item.description)', 新しい説明: '\(editedDescription)'")
                            var updatedItem = ClipboardItem(
                                content: editedContent.trimmingCharacters(in: .whitespacesAndNewlines),
                                isFavorite: item.isFavorite,
                                categoryId: item.categoryId,
                                favoriteFolderId: editedFolderId,
                                description: editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            // 既存のIDを保持
                            updatedItem.id = item.id
                            updatedItem.timestamp = item.timestamp
                            Logger.shared.log("更新されたアイテムの説明: '\(updatedItem.description)'")
                            onEdit(updatedItem)
                            isEditing = false
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ProfessionalBlueTheme.Colors.primary)
                        .cornerRadius(4)
                        
                        Button("キャンセル") {
                            isEditing = false
                            editedContent = item.content
                            editedDescription = item.description
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 12))
                        .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ProfessionalBlueTheme.Colors.backgroundLight)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ProfessionalBlueTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ProfessionalBlueTheme.Colors.primary, lineWidth: 1)
                )
                .cornerRadius(6)
            } else {
                // 表示モード
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        // コンテンツ（メイン）
                        Text(item.content)
                            .font(.system(size: 14))
                            .lineLimit(2)
                        
                        // 説明（あれば表示）
                        if !item.description.isEmpty {
                            let _ = Logger.shared.log("説明を表示: '\(item.description)'")
                            Text(item.description)
                                .font(.system(size: 12))
                                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                                .lineLimit(2)
                        } else {
                            let _ = Logger.shared.log("説明が空のため表示しない")
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(ProfessionalBlueTheme.Colors.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("コピー")
                        
                        Button(action: {
                            editedContent = item.content
                            editedDescription = item.description
                            editedFolderId = item.favoriteFolderId
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("編集")
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("削除")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ProfessionalBlueTheme.Colors.backgroundLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 0.5)
                )
                .cornerRadius(6)
                .draggable(item) {
                    // ドラッグ時のプレビュー
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text(item.content)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
            }
        }
        .onAppear {
            editedContent = item.content
            editedDescription = item.description
        }
    }
}


// MARK: - プレビュー
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let dataManager = ClipboardDataManager()
        
        // サンプルデータを追加
        dataManager.addToHistory("サンプルテキスト1")
        dataManager.addToHistory("サンプルテキスト2")
        dataManager.addToHistory("サンプルテキスト3")
        
        return HistoryView(dataManager: dataManager)
    }
}
