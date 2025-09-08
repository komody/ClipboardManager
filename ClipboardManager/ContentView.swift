import SwiftUI

/// メインのコンテンツビュー（通常は使用されませんが、SwiftUIプロジェクトとして必要）
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.on.clipboard")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("クリップボードマネージャー")
                .font(.title)
            Text("メニューバーからアクセスしてください")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

