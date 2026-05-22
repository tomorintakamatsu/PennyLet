import SwiftUI
import Speech
import AVFoundation

struct VoiceInputView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var transcript = ""
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var error: String?

    // Real recognition engines
    private let speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var onResult: ((amount: Double?, category: String?, merchant: String?, note: String?)) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if authorizationStatus == .denied || authorizationStatus == .restricted {
                    deniedView
                } else {
                    recordingView

                    if !transcript.isEmpty {
                        ScrollView {
                            Text(transcript)
                                .font(.body)
                                .padding()
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                        if !isRecording {
                            Button(viewModel.loc("Analyze")) {
                                Task { await analyzeTranscript() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isProcessing)

                            if isProcessing {
                                ProgressView(viewModel.loc("Extracting details..."))
                            }
                        }
                    }
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle(viewModel.loc("Voice Input"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) { stopAndDismiss() }
                }
            }
            .onAppear {
                authorizationStatus = SFSpeechRecognizer.authorizationStatus()
                if authorizationStatus == .notDetermined {
                    SFSpeechRecognizer.requestAuthorization { status in
                        authorizationStatus = status
                    }
                }
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text(viewModel.loc("Microphone access required"))
                .font(.headline)
            Text(viewModel.loc("Enable in Settings > Privacy > Microphone"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 36))
                    .foregroundStyle(isRecording ? .red : .secondary)
            }
            .onTapGesture {
                if isRecording { stopRecording() } else { startRecording() }
            }

            if isRecording {
                Text(viewModel.loc("Listening..."))
                    .font(.headline)
                    .foregroundStyle(.red)
            } else {
                Text(viewModel.loc("Tap to speak"))
                    .font(.headline)
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = viewModel.loc("Speech recognition unavailable.")
            return
        }
        transcript = ""
        error = nil
        isRecording = true

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, err in
            if let result {
                transcript = result.bestTranscription.formattedString
            }
            if err != nil || result?.isFinal == true {
                stopRecording()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.error = viewModel.loc("Audio engine failed to start.")
            isRecording = false
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func stopAndDismiss() {
        if isRecording { stopRecording() }
        dismiss()
    }

    // MARK: - Analysis

    private func analyzeTranscript() async {
        guard !transcript.isEmpty else { return }
        isProcessing = true
        error = nil

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": [
                "amount": ["type": "number"],
                "type": ["type": "string"],
                "category": ["type": "string"],
                "merchant": ["type": "string"],
                "note": ["type": "string"],
                "date": ["type": "string"],
            ],
            "required": ["amount"],
        ]

        let prompt = """
        Extract transaction details from this spoken text: "\(transcript)"
        Recognize the amount, whether it's an expense or income, the category
        (food_dining, groceries, transportation, shopping, entertainment,
        health_fitness, utilities, rent, travel, education, personal_care, income, other),
        the merchant/store name if mentioned, and any relevant notes.
        Return as JSON.
        """

        do {
            let result = try await AIClient.shared.invokeLLM(
                prompt: prompt,
                responseJSONSchema: schema,
                modelTier: viewModel.isPro ? .pro : .standard
            )
            guard let jsonData = result.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                // Fallback to regex
                parseWithRegex()
                return
            }
            let amount = dict["amount"] as? Double
            let category = dict["category"] as? String
            let merchant = dict["merchant"] as? String
            let note = dict["note"] as? String
            onResult((amount, category, merchant, note ?? transcript))
            dismiss()
        } catch {
            parseWithRegex()
        }
        isProcessing = false
    }

    private func parseWithRegex() {
        var amount: Double?
        var merchant: String?
        var category: String?

        let lowercased = transcript.lowercased()

        if let match = transcript.range(of: #"\$?\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let amt = String(transcript[match]).replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            amount = Double(amt)
        }

        if let match = transcript.range(of: #"at\s+(\w+)"#, options: [.regularExpression, .caseInsensitive]) {
            merchant = String(transcript[match]).replacingOccurrences(of: "at ", with: "")
        }

        if lowercased.contains("lunch") || lowercased.contains("dinner") || lowercased.contains("food") { category = "food_dining" }
        else if lowercased.contains("uber") || lowercased.contains("lyft") || lowercased.contains("gas") { category = "transportation" }
        else if lowercased.contains("amazon") || lowercased.contains("walmart") { category = "shopping" }

        onResult((amount, category, merchant, transcript))
        dismiss()
    }
}
