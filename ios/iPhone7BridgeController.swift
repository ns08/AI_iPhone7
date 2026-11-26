import Foundation
import AVFoundation
import CallKit
import Contacts
import MediaPlayer
import Speech
import UIKit

final class iPhone7BridgeController: NSObject, CXCallObserverDelegate {
    static let shared = iPhone7BridgeController()

    private let synthesizer = AVSpeechSynthesizer()
    private let callObserver = CXCallObserver()
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private let contactStore = CNContactStore()

    private var timer: Timer?
    private var relayUrl = URL(string: "https://soni08.website/remote/relay.php")!
    private var deviceId = "iphone7-main"
    private var token = "change-me-token"

    private var aiEnabled = false
    private var isRecordingNotificationsSinceTrigger = false
    private var recordedNotifications: [(app: String, text: String)] = []
    private var pendingCandidates: [(name: String, phone: String)] = []

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: DispatchQueue.main)
    }

    func startPolling(interval: TimeInterval = 0.8) {
        UIApplication.shared.isIdleTimerDisabled = true
        configureBackgroundAudioSession()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollCommands()
        }
    }

    private func configureBackgroundAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
        try? session.setActive(true)
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if !call.hasConnected && !call.hasEnded && !call.isOutgoing {
            aiEnabled = true
            speakOnDevice("着信があります。AIアシスタントを自動起動しました。")
        }
    }

    func speakOnDevice(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func openAmazonSearch(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let appUrl = URL(string: "com.amazon.mobile.shopping://www.amazon.co.jp/s?k=\(encoded)"),
           UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
            return
        }
        if let webUrl = URL(string: "https://www.amazon.co.jp/s?k=\(encoded)") {
            UIApplication.shared.open(webUrl)
        }
    }

    func playLocalMusic(query: String) {
        let mediaQuery = MPMediaQuery.songs()
        if !query.isEmpty {
            let pred = MPMediaPropertyPredicate(
                value: query,
                forProperty: MPMediaItemPropertyTitle,
                comparisonType: .contains
            )
            mediaQuery.addFilterPredicate(pred)
        }
        if let items = mediaQuery.items, !items.isEmpty {
            musicPlayer.setQueue(with: MPMediaItemCollection(items: items))
            musicPlayer.play()
            speakOnDevice("本体の音楽を再生します。")
        } else {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let shortcutUrl = URL(string: "shortcuts://run-shortcut?name=PlayLocalMusic&input=text&text=\(encoded)") {
                UIApplication.shared.open(shortcutUrl)
            }
        }
    }

    func searchContactsAndCall(nameQuery: String) {
        let cleaned = nameQuery.replacingOccurrences(of: "さん", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        contactStore.requestAccess(for: .contacts) { [weak self] granted, _ in
            guard let self = self, granted else {
                DispatchQueue.main.async {
                    self?.speakOnDevice("連絡先へのアクセス許可がありません。")
                }
                return
            }

            let request = CNContactFetchRequest(keysToFetch: [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ])

            var matches: [(name: String, phone: String)] = []
            try? self.contactStore.enumerateContacts(with: request) { contact, _ in
                let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
                if fullName.localizedCaseInsensitiveContains(cleaned) {
                    for p in contact.phoneNumbers {
                        let digits = p.value.stringValue.filter { $0.isNumber || $0 == "+" }
                        if !digits.isEmpty {
                            matches.append((name: fullName.isEmpty ? cleaned : fullName, phone: digits))
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                if matches.isEmpty {
                    self.speakOnDevice("\(cleaned)さんの連絡先が見つかりませんでした。")
                } else if matches.count == 1 {
                    self.dialPhone(matches[0].phone, label: matches[0].name)
                } else {
                    self.pendingCandidates = Array(matches.prefix(5))
                    let parts = self.pendingCandidates.enumerated().map { idx, item in
                        let last4 = String(item.phone.filter { $0.isNumber }.suffix(4)).map { String($0) }.joined(separator: " ")
                        return "\(idx + 1)番目は\(item.name)、下4桁は\(last4)"
                    }
                    self.speakOnDevice("候補が\(self.pendingCandidates.count)件あります。\(parts.joined(separator: "。"))。何番目にかけますか。")
                }
            }
        }
    }

    private func dialPhone(_ phone: String, label: String) {
        if let url = URL(string: "tel://\(phone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            speakOnDevice("\(label)に電話をかけます。")
        }
    }

    func openLineCall() {
        if let url = URL(string: "line://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    func openTeamsReply(text: String) {
        UIPasteboard.general.string = text
        if let url = URL(string: "msteams://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            speakOnDevice("返信内容をコピーしてTeamsを開きました。")
        }
    }

    func handleVoiceText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !pendingCandidates.isEmpty {
            let idx: Int? = {
                if trimmed.contains("1") || trimmed.contains("いち") { return 0 }
                if trimmed.contains("2") || trimmed.contains("に") { return 1 }
                if trimmed.contains("3") || trimmed.contains("さん") { return 2 }
                if trimmed.contains("4") || trimmed.contains("よん") { return 3 }
                if trimmed.contains("5") || trimmed.contains("ご") { return 4 }
                return nil
            }()
            if let i = idx, pendingCandidates.indices.contains(i) {
                let chosen = pendingCandidates[i]
                pendingCandidates.removeAll()
                dialPhone(chosen.phone, label: chosen.name)
                return
            }
        }

        if trimmed.contains("AIと話したい") {
            aiEnabled = true
            speakOnDevice("AI会話モードを有効にしました。")
            return
        }

        if trimmed.contains("今までの通知内容を教えて") {
            if !isRecordingNotificationsSinceTrigger {
                isRecordingNotificationsSinceTrigger = true
                recordedNotifications.removeAll()
                speakOnDevice("今から通知内容を記録します。次に言われたときに読み上げます。")
            } else {
                let items = recordedNotifications
                recordedNotifications.removeAll()
                if items.isEmpty {
                    speakOnDevice("記録された通知はありません。")
                } else {
                    let msg = items.enumerated().map { idx, it in
                        "\(idx + 1)つ目、アプリ名は\(it.app)、通知内容は\(it.text)"
                    }.joined(separator: "。")
                    speakOnDevice(msg)
                }
            }
            return
        }

        if trimmed.contains("Amazon") || trimmed.contains("アマゾン") {
            let q = trimmed.replacingOccurrences(of: "Amazon", with: "")
                .replacingOccurrences(of: "アマゾン", with: "")
                .replacingOccurrences(of: "注文", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            openAmazonSearch(query: q)
            speakOnDevice("アマゾンで\(q)を検索します。")
            return
        }

        if trimmed.contains("音楽") {
            let q = trimmed.replacingOccurrences(of: "音楽", with: "")
                .replacingOccurrences(of: "再生", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            playLocalMusic(query: q)
            return
        }

        if trimmed.hasSuffix("電話して") {
            let target = trimmed.replacingOccurrences(of: "に電話して", with: "")
                .replacingOccurrences(of: "電話して", with: "")
            searchContactsAndCall(nameQuery: target)
            return
        }

        if trimmed.contains("LINE") && trimmed.contains("通話") {
            openLineCall()
            return
        }

        if trimmed.contains("Teams") && trimmed.contains("返信") {
            openTeamsReply(text: trimmed)
            return
        }

        if aiEnabled {
            speakOnDevice("AIモードで応答しました。\(trimmed)")
        }
    }

    private func pollCommands() {
        var req = URLRequest(url: relayUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "role": "device",
            "device_id": deviceId,
            "token": token
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let commands = json["commands"] as? [[String: Any]] else { return }

            DispatchQueue.main.async {
                for cmd in commands {
                    let type = cmd["type"] as? String ?? ""
                    switch type {
                    case "amazon_order":
                        let q = cmd["query"] as? String ?? ""
                        self.openAmazonSearch(query: q)
                        self.speakOnDevice("アマゾンで\(q)を検索します")
                    case "play_local_music":
                        let q = cmd["query"] as? String ?? ""
                        self.playLocalMusic(query: q)
                    case "voice_command":
                        let text = cmd["text"] as? String ?? ""
                        self.handleVoiceText(text)
                    default:
                        break
                    }
                }
            }
        }.resume()
    }
}
