import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 共通ボタンコンポーネント
struct ThemedButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case success
        case warning
        case danger
        case info
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ProfessionalBlueTheme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: ProfessionalBlueTheme.FontSize.xs))
                }
                Text(title)
                    .font(.system(size: ProfessionalBlueTheme.FontSize.sm, weight: .medium))
            }
            .padding(.horizontal, ProfessionalBlueTheme.Spacing.md)
            .padding(.vertical, ProfessionalBlueTheme.Spacing.sm)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(ProfessionalBlueTheme.CornerRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return ProfessionalBlueTheme.Colors.primaryLight
        case .secondary:
            return ProfessionalBlueTheme.Colors.backgroundLight
        case .success:
            return ProfessionalBlueTheme.Colors.success.opacity(0.1)
        case .warning:
            return ProfessionalBlueTheme.Colors.warning.opacity(0.1)
        case .danger:
            return ProfessionalBlueTheme.Colors.danger.opacity(0.1)
        case .info:
            return ProfessionalBlueTheme.Colors.info.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return ProfessionalBlueTheme.Colors.primaryDark
        case .secondary:
            return ProfessionalBlueTheme.Colors.text
        case .success:
            return ProfessionalBlueTheme.Colors.success
        case .warning:
            return ProfessionalBlueTheme.Colors.warning
        case .danger:
            return ProfessionalBlueTheme.Colors.danger
        case .info:
            return ProfessionalBlueTheme.Colors.info
        }
    }
}

// MARK: - 共通カードコンポーネント
struct ThemedCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, ProfessionalBlueTheme.Spacing.lg)
            .padding(.vertical, ProfessionalBlueTheme.Spacing.sm)
            .background(ProfessionalBlueTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: ProfessionalBlueTheme.CornerRadius.lg)
                    .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
            )
            .cornerRadius(ProfessionalBlueTheme.CornerRadius.lg)
            .shadow(
                color: ProfessionalBlueTheme.Colors.shadow.opacity(0.1),
                radius: 6,
                x: 0,
                y: 3
            )
    }
}

// MARK: - 共通検索バーコンポーネント
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    // 親からフォーカスを渡せるようにする（任意）
    let isFocused: FocusState<Bool>.Binding?
    
    init(text: Binding<String>, placeholder: String = "検索...", isFocused: FocusState<Bool>.Binding? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
    }
    
    var body: some View {
        HStack(spacing: ProfessionalBlueTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                .font(.system(size: ProfessionalBlueTheme.FontSize.sm))
            
            Group {
                if let isFocused = isFocused {
                    #if os(macOS)
                    AppKitSearchField(text: $text, placeholder: placeholder)
                        .focused(isFocused)
                    #else
                    TextField(placeholder, text: $text)
                        .focused(isFocused)
                    #endif
                } else {
                    #if os(macOS)
                    AppKitSearchField(text: $text, placeholder: placeholder)
                    #else
                    TextField(placeholder, text: $text)
                    #endif
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: ProfessionalBlueTheme.FontSize.sm))
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                        .font(.system(size: ProfessionalBlueTheme.FontSize.sm))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, ProfessionalBlueTheme.Spacing.md)
        .padding(.vertical, ProfessionalBlueTheme.Spacing.sm)
        .background(ProfessionalBlueTheme.Colors.backgroundLight)
        .overlay(
            RoundedRectangle(cornerRadius: ProfessionalBlueTheme.CornerRadius.md)
                .stroke(ProfessionalBlueTheme.Colors.border, lineWidth: 1)
        )
        .cornerRadius(ProfessionalBlueTheme.CornerRadius.md)
    }
}

// MARK: - macOS向け NSSearchField ラッパー
#if os(macOS)
struct AppKitSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
            func makeNSView(context: Context) -> NSSearchField {
                let field = NSSearchField()
                field.placeholderString = placeholder
                field.isEditable = true
                field.isSelectable = true
                field.usesSingleLineMode = true
                field.cell?.wraps = false
                field.cell?.isScrollable = true
                field.delegate = context.coordinator
                
                // NSSearchFieldのデフォルトの枠線とフォーカスリングを無効化
                field.focusRingType = .none
                field.isBezeled = false
                field.isBordered = false
                field.drawsBackground = false
                
                // NSSearchFieldのデフォルトのアイコンとボタンを無効化
                field.searchMenuTemplate = nil
                field.sendsSearchStringImmediately = false
                field.sendsWholeSearchString = false
                
                // カスタムセルを使用してアイコンとボタンを非表示
                if let cell = field.cell as? NSSearchFieldCell {
                    cell.searchButtonCell = nil
                    cell.cancelButtonCell = nil
                }
        
        // 右クリックメニューを追加
        let menu = NSMenu()
        let pasteItem = NSMenuItem(title: "ペースト", action: #selector(Coordinator.paste(_:)), keyEquivalent: "v")
        pasteItem.target = context.coordinator
        menu.addItem(pasteItem)
        field.menu = menu
        
        return field
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: AppKitSearchField
        init(_ parent: AppKitSearchField) { self.parent = parent }
        
        @MainActor func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
        
        @MainActor @objc func paste(_ sender: Any?) {
            if let pasted = NSPasteboard.general.string(forType: .string) {
                parent.text.append(pasted)
            }
        }
    }
}
#endif

// MARK: - 共通アイテム行コンポーネント
struct ItemRow: View {
    let item: ClipboardItem
    let category: Category?
    let folder: FavoriteFolder?
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onChangeCategory: (() -> Void)?
    let onChangeFolder: (() -> Void)?
    
    init(
        item: ClipboardItem,
        category: Category? = nil,
        folder: FavoriteFolder? = nil,
        onCopy: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onChangeCategory: (() -> Void)? = nil,
        onChangeFolder: (() -> Void)? = nil
    ) {
        self.item = item
        self.category = category
        self.folder = folder
        self.onCopy = onCopy
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
        self.onChangeCategory = onChangeCategory
        self.onChangeFolder = onChangeFolder
    }
    
    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: ProfessionalBlueTheme.Spacing.sm) {
                // メインコンテンツ
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: ProfessionalBlueTheme.Spacing.xs) {
                        Text(item.displayText)
                            .font(.system(size: ProfessionalBlueTheme.FontSize.sm))
                            .foregroundColor(ProfessionalBlueTheme.Colors.text)
                            .lineLimit(3)
                        
                        Text(item.timestamp, style: .time)
                            .font(.system(size: ProfessionalBlueTheme.FontSize.xs))
                            .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
                    }
                    
                    Spacer()
                    
                    // アクションボタン
                    HStack(spacing: ProfessionalBlueTheme.Spacing.xs) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: ProfessionalBlueTheme.FontSize.xs))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onToggleFavorite) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: ProfessionalBlueTheme.FontSize.xs))
                                .foregroundColor(item.isFavorite ? .red : ProfessionalBlueTheme.Colors.textMuted)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: ProfessionalBlueTheme.FontSize.xs))
                                .foregroundColor(ProfessionalBlueTheme.Colors.danger)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // カテゴリ・フォルダ情報
                HStack(spacing: ProfessionalBlueTheme.Spacing.sm) {
                    if let category = category {
                        CategoryBadge(category: category, onChange: onChangeCategory)
                    }
                    
                    if let folder = folder {
                        FolderBadge(folder: folder, onChange: onChangeFolder)
                    }
                }
            }
        }
    }
}

// MARK: - カテゴリバッジコンポーネント
struct CategoryBadge: View {
    let category: Category
    let onChange: (() -> Void)?
    
    var body: some View {
        HStack(spacing: ProfessionalBlueTheme.Spacing.xs) {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 8, height: 8)
            
            Text(category.name)
                .font(.system(size: ProfessionalBlueTheme.FontSize.xs, weight: .medium))
                .foregroundColor(ProfessionalBlueTheme.Colors.textSecondary)
            
            if onChange != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
            }
        }
        .padding(.horizontal, ProfessionalBlueTheme.Spacing.sm)
        .padding(.vertical, ProfessionalBlueTheme.Spacing.xs)
        .background(ProfessionalBlueTheme.Colors.primaryLight)
        .cornerRadius(ProfessionalBlueTheme.CornerRadius.sm)
        .onTapGesture {
            onChange?()
        }
    }
}

// MARK: - フォルダバッジコンポーネント
struct FolderBadge: View {
    let folder: FavoriteFolder
    let onChange: (() -> Void)?
    
    var body: some View {
        HStack(spacing: ProfessionalBlueTheme.Spacing.xs) {
            Image(systemName: "folder.fill")
                .font(.system(size: 8))
                .foregroundColor(Color(hex: folder.color))
            
            Text(folder.name)
                .font(.system(size: ProfessionalBlueTheme.FontSize.xs, weight: .medium))
                .foregroundColor(ProfessionalBlueTheme.Colors.textSecondary)
            
            if onChange != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(ProfessionalBlueTheme.Colors.textMuted)
            }
        }
        .padding(.horizontal, ProfessionalBlueTheme.Spacing.sm)
        .padding(.vertical, ProfessionalBlueTheme.Spacing.xs)
        .background(ProfessionalBlueTheme.Colors.primaryLight)
        .cornerRadius(ProfessionalBlueTheme.CornerRadius.sm)
        .onTapGesture {
            onChange?()
        }
    }
}
