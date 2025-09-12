import SwiftUI
import AppKit

// MARK: - プロフェッショナル・ブルーテーマ
extension Color {
    // プロフェッショナル・ブルーテーマのカラーパレット
    static let professionalBlue = Color(hex: "1976D2")      // メインアクセント
    static let professionalBlueDark = Color(hex: "0D47A1")  // ダークアクセント
    static let professionalBlueLight = Color(hex: "BBDEFB") // ライトアクセント
    static let professionalBackground = Color(hex: "E3F2FD") // ベース背景
    static let professionalBackgroundLight = Color(hex: "F8FBFF") // ライト背景
    static let professionalText = Color(hex: "0D47A1")      // メインテキスト
    static let professionalTextSecondary = Color(hex: "1565C0") // セカンダリテキスト
    static let professionalCard = Color(hex: "F2F8FF")     // カード背景（ライトブルー）
    static let professionalBorder = Color(hex: "BBDEFB")    // ボーダー
}

/// 履歴管理画面のSwiftUIビュー
struct HistoryView: View {
    @ObservedObject var dataManager: ClipboardDataManager
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingClearAlert = false
    @State private var selectedCategory: UUID? = nil
    @State private var showingCategoryManager = false
    @State private var selectedFavoriteFolder: UUID? = nil
    @State private var showingFavoriteFolderManager = false
    
    var body: some View {
        VStack(spacing: 0) {
            // アニメーション付きタブビュー
            Picker("表示モード", selection: $selectedTab) {
                Text("履歴").tag(0)
                Text("お気に入り").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
            
            // 改善された検索バー
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("検索...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.professionalBackgroundLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.professionalBorder, lineWidth: 1)
                )
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
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
        .background(Color.professionalBackground)
    }
    
    // MARK: - 履歴リストビュー
    private var historyListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack {
                Text("コピー履歴 (\(filteredHistoryItems.count)件)")
                    .font(.headline)
                    .foregroundColor(Color.professionalText)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // カテゴリフィルター
                    Menu {
                        Button("すべてのカテゴリ") {
                            selectedCategory = nil
                        }
                        
                        ForEach(dataManager.categories) { category in
                            Button(category.name) {
                                selectedCategory = category.id
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12))
                            Text(selectedCategory == nil ? "すべて" : dataManager.getCategory(by: selectedCategory!).name)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("カテゴリ管理") {
                        showingCategoryManager = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.professionalBlueLight)
                    .foregroundColor(Color.professionalBlueDark)
                    .cornerRadius(6)
                    .font(.system(size: 13))
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("履歴をクリア") {
                        showingClearAlert = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                    .font(.system(size: 13))
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            Divider()
            
            // カード形式のリスト
            if filteredHistoryItems.isEmpty {
                emptyStateView(message: searchText.isEmpty ? "履歴がありません" : "検索結果がありません")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredHistoryItems.enumerated()), id: \.element.id) { index, item in
                            HistoryItemRow(
                                item: item,
                                category: dataManager.getCategory(by: item.categoryId),
                                onCopy: { copyToClipboard(item.content) },
                                onAddToFavorites: { dataManager.addToFavorites(item) },
                                onDelete: { dataManager.removeFromHistory(item) },
                                onChangeCategory: { categoryId in
                                    dataManager.changeItemCategory(item, to: categoryId)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    .background(Color.professionalCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.professionalBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.professionalBlue.opacity(0.1), radius: 6, x: 0, y: 3)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: filteredHistoryItems.count)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagerView(dataManager: dataManager)
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
            // ヘッダー
            HStack {
                Text("お気に入り (\(filteredFavoriteItems.count)件)")
                    .font(.headline)
                    .foregroundColor(Color.professionalText)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // お気に入りフォルダフィルター
                    Menu {
                        Button("すべてのフォルダ") {
                            selectedFavoriteFolder = nil
                        }
                        
                        ForEach(dataManager.favoriteFolders) { folder in
                            Button(folder.name) {
                                selectedFavoriteFolder = folder.id
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                            Text(selectedFavoriteFolder == nil ? "すべて" : dataManager.getFavoriteFolder(by: selectedFavoriteFolder!).name)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("フォルダ管理") {
                        showingFavoriteFolderManager = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.professionalBlueLight)
                    .foregroundColor(Color.professionalBlueDark)
                    .cornerRadius(6)
                    .font(.system(size: 13))
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            Divider()
            
            // カード形式のリスト
            if filteredFavoriteItems.isEmpty {
                emptyStateView(message: searchText.isEmpty ? "お気に入りがありません" : "検索結果がありません")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredFavoriteItems.enumerated()), id: \.element.id) { index, item in
                            FavoriteItemRow(
                                item: item,
                                folder: dataManager.getFavoriteFolder(by: item.favoriteFolderId ?? FavoriteFolder.defaultFolder.id),
                                onCopy: { copyToClipboard(item.content) },
                                onDelete: { dataManager.removeFromFavorites(item) },
                                onChangeFolder: { folderId in
                                    dataManager.changeFavoriteFolder(item, to: folderId)
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    .background(Color.professionalCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.professionalBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.professionalBlue.opacity(0.1), radius: 6, x: 0, y: 3)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: filteredFavoriteItems.count)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(isPresented: $showingFavoriteFolderManager) {
            FavoriteFolderManagerView(dataManager: dataManager)
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
                Text("履歴からお気に入りに追加できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - フィルタリング
    private var filteredHistoryItems: [ClipboardItem] {
        var items = dataManager.historyItems
        
        // カテゴリフィルター
        if let selectedCategory = selectedCategory {
            items = items.filter { $0.categoryId == selectedCategory }
        }
        
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
        
        return items.sorted { $0.timestamp > $1.timestamp }
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
                .help("お気に入りに追加")
                
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
    let folder: FavoriteFolder
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
                    
                    // フォルダバッジ
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
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                // フォルダ変更メニュー
                Menu {
                    ForEach([FavoriteFolder.defaultFolder]) { folder in
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
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("お気に入りフォルダ管理")
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
                        
                        HStack(spacing: 8) {
                            Text("色:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: newFolderColor) },
                                set: { newFolderColor = $0.toHex() }
                            ))
                            .frame(width: 40, height: 30)
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
                                        Button("削除") {
                                            dataManager.deleteFavoriteFolder(folder)
                                        }
                                        .foregroundColor(.red)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
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
    }
}

// MARK: - Color拡張
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        
        return String(format: "#%06x", rgb)
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

