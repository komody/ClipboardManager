import SwiftUI

/// 履歴管理画面のSwiftUIビュー
struct HistoryView: View {
    @ObservedObject var dataManager: ClipboardDataManager
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingClearAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // タブビュー
            Picker("表示モード", selection: $selectedTab) {
                Text("履歴").tag(0)
                Text("お気に入り").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("検索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("クリア") {
                        searchText = ""
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            // コンテンツエリア
            if selectedTab == 0 {
                historyListView
            } else {
                favoritesListView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - 履歴リストビュー
    private var historyListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack {
                Text("コピー履歴 (\(filteredHistoryItems.count)件)")
                    .font(.headline)
                
                Spacer()
                
                Button("履歴をクリア") {
                    showingClearAlert = true
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red)
            }
            .padding()
            
            Divider()
            
            // リスト
            if filteredHistoryItems.isEmpty {
                emptyStateView(message: searchText.isEmpty ? "履歴がありません" : "検索結果がありません")
            } else {
                List(filteredHistoryItems) { item in
                    HistoryItemRow(
                        item: item,
                        onCopy: { copyToClipboard(item.content) },
                        onAddToFavorites: { dataManager.addToFavorites(item) },
                        onDelete: { dataManager.removeFromHistory(item) }
                    )
                }
            }
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
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // リスト
            if filteredFavoriteItems.isEmpty {
                emptyStateView(message: searchText.isEmpty ? "お気に入りがありません" : "検索結果がありません")
            } else {
                List(filteredFavoriteItems) { item in
                    FavoriteItemRow(
                        item: item,
                        onCopy: { copyToClipboard(item.content) },
                        onDelete: { dataManager.removeFromFavorites(item) }
                    )
                }
            }
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
        if searchText.isEmpty {
            return dataManager.historyItems
        } else {
            return dataManager.historyItems.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var filteredFavoriteItems: [ClipboardItem] {
        if searchText.isEmpty {
            return dataManager.favoriteItems
        } else {
            return dataManager.favoriteItems.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
            }
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
    let onCopy: () -> Void
    let onAddToFavorites: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
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
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .font(.body)
                    .lineLimit(3)
                
                Text("お気に入り")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
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

