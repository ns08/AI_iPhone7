# iPhone 7 全ファイル統合＆GitHub Actions ビルドパッケージ

## 同梱ファイル
- `.github/workflows/ios-github-build.yml` — GitHub Actions（`macos-14`）でプロジェクト生成・`xcodebuild` ビルド・成果物アーカイブを行うワークフロー
- `project.yml` — `iPhone7WebRemote`（`iOS: "15.0"`）の XcodeGen 定義
- `ios/Info.plist` — 権限説明・URLスキーム・バックグラウンドモード定義
- `ios/iPhone7WebRemoteApp.swift`, `ios/ContentView.swift`, `ios/iPhone7BridgeController.swift` — iPhone 7 向け Swift ソース一式
- `web/index.html`, `web/relay.php` — スターレンタルサーバー配置用 Web コンソールと中継 PHP

## GitHub でのビルド手順
1. ZIP を解凍し、内容を GitHub リポジトリのルートに配置して `push` します。
2. GitHub の **Actions** タブから **Build iPhone 7 iOS App on GitHub** の実行結果と **Artifacts**（`iphone7-github-build-output`）を確認します。
3. iPhone 7 実機へ導入する際は、ご自身の Apple Developer アカウントで署名（Signing）を行ってください。
