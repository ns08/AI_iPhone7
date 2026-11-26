import SwiftUI

struct ContentView: View {
    @State private var statusText = "iPhone 7 Web連携 待機中"
    @State private var testCommand = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("iPhone 7 Web Remote")
                .font(.title2).bold()
            Text(statusText)
                .font(.footnote)
            Button("連携ポーリング開始（スリープ抑止）") {
                iPhone7BridgeController.shared.startPolling()
                statusText = "スターレンタルサーバーと連携中"
            }
            Button("音声出力テスト") {
                iPhone7BridgeController.shared.speakOnDevice("アイフォンセブンで音声出力を確認しました")
            }
            TextField("テスト音声コマンド入力", text: $testCommand)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("コマンド実行") {
                iPhone7BridgeController.shared.handleVoiceText(testCommand)
            }
        }
        .padding()
    }
}
