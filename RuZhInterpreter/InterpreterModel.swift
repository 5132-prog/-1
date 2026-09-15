import AVFoundation
import Speech
import Translation

@MainActor
@Observable
final class InterpreterModel {
    struct Entry: Identifiable {
        let id = UUID()
        let russian: String
        var chinese: String?
        var failed = false
    }

    private struct Pending {
        let id: UUID
        let text: String
    }

    enum Phase: Equatable {
        case idle
        case starting
        case listening
        case denied
        case unavailable
    }

    var phase: Phase = .idle
    var partialRussian = ""
    var entries: [Entry] = []
    var statusText = ""
    var translationConfig: TranslationSession.Configuration?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var translationSession: TranslationSession?
    private var pendingTranslations: [Pending] = []
    private var isDraining = false

    var isListening: Bool { phase == .listening || phase == .starting }

    // MARK: - 翻译会话

    func prepare() {
        guard translationConfig == nil else { return }
        translationConfig = makeTranslationConfig()
    }

    private func makeTranslationConfig() -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: "ru"),
            target: Locale.Language(identifier: "zh-Hans")
        )
    }

    func handleSession(_ session: TranslationSession) async {
        translationSession = session
        do {
            try await session.prepareTranslation()
        } catch {
            statusText = "翻译模型准备中，首次使用可能需要联网下载…"
        }
        await drainPendingTranslations()
    }

    private func drainPendingTranslations() async {
        guard !isDraining, let session = translationSession else { return }
        isDraining = true
        defer { isDraining = false }
        while !pendingTranslations.isEmpty {
            let item = pendingTranslations.removeFirst()
            do {
                let response = try await session.translate(item.text)
                if let index = entries.firstIndex(where: { $0.id == item.id }) {
                    entries[index].chinese = response.targetText
                }
            } catch {
                if let index = entries.firstIndex(where: { $0.id == item.id }) {
                    entries[index].failed = true
                }
                statusText = "翻译失败：可能是俄语→中文翻译模型尚未下载。请打开系统自带「翻译」App，添加俄语和简体中文并下载语言包后重试。"
                return
            }
        }
    }

    // MARK: - 语音识别

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        Task { await startListeningAsync() }
    }

    private func startListeningAsync() async {
        guard phase == .idle || phase == .unavailable || phase == .denied else { return }
        phase = .starting
        statusText = ""

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            phase = .denied
            statusText = "未获得语音识别权限，请在 设置 → 隐私与安全性 → 语音识别 中允许本 App。"
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            phase = .denied
            statusText = "未获得麦克风权限，请在 设置 → 隐私与安全性 → 麦克风 中允许本 App。"
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            phase = .unavailable
            statusText = "俄语识别服务暂不可用，请检查网络后重试。"
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                phase = .unavailable
                statusText = "无法访问麦克风，请检查权限后重试。"
                return
            }

            startRecognitionTask(recognizer: recognizer, format: format)
            audioEngine.prepare()
            try audioEngine.start()
            phase = .listening
            statusText = "正在聆听俄语……说完一句会自动翻译"
        } catch {
            phase = .unavailable
            statusText = "启动失败：\(error.localizedDescription)"
        }
    }

    private func startRecognitionTask(recognizer: SFSpeechRecognizer, format: AVAudioFormat) {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognitionResult(result, error: error)
            }
        }
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: (any Error)?) {
        guard phase == .listening else { return }
        if let result {
            let text = result.bestTranscription.formattedString
            partialRussian = text
            if result.isFinal {
                partialRussian = ""
                let utterance = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !utterance.isEmpty {
                    finishUtterance(utterance)
                }
                restartRecognitionTask()
                return
            }
        }
        if error != nil {
            // 服务器识别在静音一段时间后会自动结束任务，这里重启继续听。
            restartRecognitionTask()
        }
    }

    private func finishUtterance(_ text: String) {
        let entry = Entry(russian: text, chinese: nil)
        entries.append(entry)
        pendingTranslations.append(Pending(id: entry.id, text: text))
        Task { await drainPendingTranslations() }
    }

    private func restartRecognitionTask() {
        guard let recognizer = speechRecognizer, phase == .listening else { return }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        startRecognitionTask(recognizer: recognizer, format: format)
    }

    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        partialRussian = ""
        phase = .idle
        statusText = entries.isEmpty ? "点击按钮开始同传" : "已暂停，再次点击可继续"
    }

    func clearTranscript() {
        entries.removeAll()
        pendingTranslations.removeAll()
        statusText = ""
    }
}
