import SwiftUI
import Speech

struct ContentView: View {
    @State private var transcript = ""
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    
    @State private var chatGPTResponse = ""
    @State private var isFetching = false
    
    private let chatGPTManager = ChatGPTManager()

    var body: some View {
        VStack(spacing: 40) {
            Text(transcript)
                .padding()
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
                isRecording.toggle()
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .foregroundColor(.white)
                    .padding()
                    .background(isRecording ? Color.red : Color.blue)
                    .cornerRadius(8)
            }
            
            Button(action: {
                isFetching = true
                chatGPTManager.getResponse(prompt: transcript) { result in
                    DispatchQueue.main.async {
                        isFetching = false
                        switch result {
                        case .success(let response):
                            chatGPTResponse = response
                        case .failure(let error):
                            chatGPTResponse = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }) {
                Text("Enter")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Text(chatGPTResponse)
                .padding()
        }
        .padding()
    }

    func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognition is not available on this device.")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Could not create a SFSpeechAudioBufferRecognitionRequest.")
        }

        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                transcript = result.bestTranscription.formattedString
            }

            if error != nil {
                stopRecording()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("Could not start the audio engine: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

