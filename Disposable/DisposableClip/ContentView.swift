import Foundation
import SwiftUI
import UIKit
import FirebaseStorage
import SDWebImageSwiftUI
import PhotosUI
import AVFoundation

private extension Color {
    init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: cleanHexCode).scanHexInt64(&rgb) else {
            self = .clear
            return
        }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

struct ContentView: View {
    enum GuestStep {
        case welcome
        case name
        case camera
        case voice
        case locked
    }

    @State var eventId: String? = nil
    @State private var photos: [String] = []
    @State private var userName: String = ""
    @State private var eventName: String = "Tetamu Event"
    @State private var hostName: String = "Host"
    @State private var eventLocation: String = ""

    @State private var hasAcceptedTerms: Bool = false
    @State private var currentStep: GuestStep = .welcome

    @State private var showingImagePicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var showingCamera = false
    @StateObject private var cameraController = ClipCameraController()

    @State private var maxShots: Int = 10
    @State private var shotsTaken: Int = 0
    @State private var timer: Timer?

    @State private var showDownloadAlert = false

    @State private var allowVoiceNotes = true
    @State private var voiceMaxSeconds = 120
    @State private var revealMode = "Immediately"
    @State private var revealAtDate: Date?

    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecordingVoice = false
    @State private var voiceElapsed = 0
    @State private var voiceTimer: Timer?

    private var shotsLeft: Int {
        max(maxShots - shotsTaken, 0)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0E1022"), Color(hex: "#090B14")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch currentStep {
            case .welcome:
                welcomeStep
            case .name:
                nameStep
            case .camera:
                cameraStep
            case .voice:
                voiceStep
            case .locked:
                lockedStep
            }
        }
        .onAppear {
            if let eventId {
                fetchEventData(eventId: eventId)
                fetchImagesForEvent(eventId: eventId)
            }
            restoreUserState()
            startReloadingImages()
        }
        .onDisappear {
            stopReloadingImages()
            stopVoiceRecording(save: false)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: handleUserActivity)
        .fullScreenCover(isPresented: $showingCamera) {
            ClipCameraView(
                controller: cameraController,
                eventName: eventName,
                shotsLeft: shotsLeft,
                onCapture: { image in
                    uploadPhoto(image: image)
                    shotsTaken += 1
                },
                onClose: {
                    showingCamera = false
                }
            )
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)

            Text("Welcome to")
                .foregroundColor(.white.opacity(0.76))

            Text(eventName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Capture moments and leave a message for the couple.")
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button("Join as a Guest") {
                currentStep = .name
            }
            .buttonStyle(TetamuPrimaryButtonStyle())
            .padding(.top, 6)
        }
        .padding(24)
    }

    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("Nice to meet you")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("What's your name?")
                .foregroundColor(.white.opacity(0.78))

            TextField("Your Name", text: $userName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)

            Toggle(isOn: $hasAcceptedTerms) {
                Text("I accept Terms and Privacy")
                    .foregroundColor(.white.opacity(0.9))
            }
            .tint(Color(hex: "#E8D7FF"))

            HStack(spacing: 10) {
                Link("Terms", destination: URL(string: "https://guest.tetamu.app/terms-co")!)
                Text("·")
                    .foregroundColor(.white.opacity(0.5))
                Link("Privacy", destination: URL(string: "https://guest.tetamu.app/privacy")!)
            }
            .font(.footnote)

            Button("Continue") {
                completeJoinFlow()
            }
            .buttonStyle(TetamuPrimaryButtonStyle())
            .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasAcceptedTerms)
            .opacity(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasAcceptedTerms ? 0.5 : 1)
        }
        .padding(24)
    }

    private var cameraStep: some View {
        NavigationView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(eventName)
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text(eventLocation.isEmpty ? "Tap camera to start" : eventLocation)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                }

                HStack {
                    statPill(title: "Shots Left", value: "\(shotsLeft)")
                    statPill(title: "Photos", value: "\(photos.count)")
                    statPill(title: "Voice", value: allowVoiceNotes ? "On" : "Off")
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.element) { _, photoUrl in
                            WebImage(url: URL(string: photoUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 124)
                                .clipped()
                                .cornerRadius(10)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: { showingCamera = true }) {
                        Label("Open Camera", systemImage: "camera")
                    }
                    .buttonStyle(TetamuPrimaryButtonStyle())
                    .disabled(shotsLeft <= 0)
                    .opacity(shotsLeft <= 0 ? 0.5 : 1)

                    Button(action: { showingImagePicker = true }) {
                        Label("Upload", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(TetamuSecondaryButtonStyle())
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(images: $selectedImages)
                            .onDisappear {
                                for image in selectedImages {
                                    guard shotsTaken < maxShots else { break }
                                    uploadPhoto(image: image)
                                    shotsTaken += 1
                                }
                                selectedImages.removeAll()
                            }
                    }
                }

                if allowVoiceNotes {
                    Button("Continue to Voice Guestbook") {
                        currentStep = .voice
                    }
                    .buttonStyle(TetamuSecondaryButtonStyle())
                }

                Button("Reveal Status") {
                    currentStep = isRevealLocked() ? .locked : .camera
                }
                .font(.footnote.bold())
                .foregroundColor(.white.opacity(0.78))

                Button(action: { showDownloadAlert = true }) {
                    Label("Download in Browser", systemImage: "arrow.down.circle")
                        .foregroundColor(.white.opacity(0.82))
                }
                .alert(isPresented: $showDownloadAlert) {
                    Alert(
                        title: Text("Download Photos"),
                        message: Text("Open browser gallery for full download support."),
                        primaryButton: .default(Text("Open Browser")) {
                            if let eventId, let url = URL(string: "https://guest.tetamu.app/html/template.html?eventId=\(eventId)") {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding(14)
            .navigationBarHidden(true)
        }
    }

    private var voiceStep: some View {
        VStack(spacing: 16) {
            Text("Voice Guestbook")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("Leave a heartfelt message for the couple")
                .foregroundColor(.white.opacity(0.78))

            Text(formatVoiceTime(voiceElapsed))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#E8D7FF"))

            Text("Max \(voiceMaxSeconds / 60) min")
                .foregroundColor(.white.opacity(0.72))

            HStack(spacing: 10) {
                Button(isRecordingVoice ? "Recording..." : "Record") {
                    startVoiceRecording()
                }
                .buttonStyle(TetamuPrimaryButtonStyle())
                .disabled(isRecordingVoice)

                Button("Stop") {
                    stopVoiceRecording(save: true)
                }
                .buttonStyle(TetamuSecondaryButtonStyle())
                .disabled(!isRecordingVoice)
            }

            Button("Continue") {
                currentStep = isRevealLocked() ? .locked : .camera
            }
            .buttonStyle(TetamuSecondaryButtonStyle())
        }
        .padding(24)
    }

    private var lockedStep: some View {
        VStack(spacing: 14) {
            Text("All set")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            if let revealAtDate {
                Text("Memories reveal at")
                    .foregroundColor(.white.opacity(0.76))
                Text(revealAtDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.title3.bold())
                    .foregroundColor(Color(hex: "#E8D7FF"))
            } else {
                Text("Your photos are safe with us.")
                    .foregroundColor(.white.opacity(0.76))
            }

            Button("Back to Camera") {
                currentStep = .camera
            }
            .buttonStyle(TetamuPrimaryButtonStyle())
        }
        .padding(24)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.74))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func completeJoinFlow() {
        let cleaned = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, hasAcceptedTerms else { return }

        userName = cleaned
        UserDefaults.standard.set(cleaned, forKey: "clip_user_name")

        if let eventId {
            addUserToEvent(eventId: eventId, userName: cleaned)
        }

        currentStep = .camera
    }

    private func restoreUserState() {
        if let cached = UserDefaults.standard.string(forKey: "clip_user_name"), !cached.isEmpty {
            userName = cached
            hasAcceptedTerms = true
            currentStep = .camera
        }
    }

    func startReloadingImages() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            if let eventId {
                fetchImagesForEvent(eventId: eventId)
            }
        }
    }

    func stopReloadingImages() {
        timer?.invalidate()
        timer = nil
    }

    func handleUserActivity(_ userActivity: NSUserActivity) {
        guard let incomingURL = userActivity.webpageURL else { return }
        let extracted = extractEventId(from: incomingURL)
        eventId = extracted
        if let extracted {
            fetchEventData(eventId: extracted)
            fetchImagesForEvent(eventId: extracted)
            if !userName.isEmpty {
                addUserToEvent(eventId: extracted, userName: userName)
            }
        }
    }

    func extractEventId(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "eventId" })?.value
    }

    func fetchEventData(eventId: String) {
        let firestoreURL = "https://firestore.googleapis.com/v1/projects/disposable-53b41/databases/(default)/documents/events/\(eventId)"
        guard let url = URL(string: firestoreURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                print("Error fetching event data: \(error)")
                return
            }
            guard let data else { return }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = jsonResponse["fields"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.eventName = (fields["eventName"] as? [String: Any])?["stringValue"] as? String ?? "Tetamu Event"
                        self.hostName = (fields["userName"] as? [String: Any])?["stringValue"] as? String ?? "Host"
                        self.eventLocation = (fields["location"] as? [String: Any])?["stringValue"] as? String ?? ""

                        if let count = (fields["numberOfPhotos"] as? [String: Any])?["integerValue"] as? String,
                           let parsed = Int(count) {
                            self.maxShots = parsed
                        }

                        self.allowVoiceNotes = ((fields["allowVoiceNotes"] as? [String: Any])?["booleanValue"] as? Bool) ?? true
                        if let maxVoice = (fields["voiceNoteMaxSeconds"] as? [String: Any])?["integerValue"] as? String,
                           let parsed = Int(maxVoice) {
                            self.voiceMaxSeconds = parsed
                        }
                        self.revealMode = (fields["reveal"] as? [String: Any])?["stringValue"] as? String ?? "Immediately"

                        if let durationRaw = (fields["duration"] as? [String: Any])?["integerValue"] as? String,
                           let duration = Int(durationRaw),
                           let startMap = fields["startTime"] as? [String: Any],
                           let ts = startMap["timestampValue"] as? String,
                           let startDate = ISO8601DateFormatter().date(from: ts) {
                            self.revealAtDate = startDate.addingTimeInterval(TimeInterval(duration * 3600))
                        } else {
                            self.revealAtDate = nil
                        }
                    }
                }
            } catch {
                print("Error parsing event data: \(error)")
            }
        }.resume()
    }

    func fetchImagesForEvent(eventId: String) {
        let imagesCollectionURL = "https://firestore.googleapis.com/v1/projects/disposable-53b41/databases/(default)/documents/events/\(eventId)/images"
        guard let imagesURL = URL(string: imagesCollectionURL) else { return }

        URLSession.shared.dataTask(with: imagesURL) { data, _, error in
            if let error {
                print("Error fetching images: \(error)")
                return
            }
            guard let data else { return }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = jsonResponse["documents"] as? [[String: Any]] {
                    let urls = documents.compactMap { document -> String? in
                        guard let fields = document["fields"] as? [String: Any],
                              let urlField = fields["url"] as? [String: Any],
                              let urlString = urlField["stringValue"] as? String else {
                            return nil
                        }
                        return urlString
                    }

                    DispatchQueue.main.async {
                        self.photos = urls
                    }
                }
            } catch {
                print("Error parsing images JSON: \(error)")
            }
        }.resume()
    }

    func addUserToEvent(eventId: String, userName: String) {
        let userDefaultsKey = "com.disposableclip.userId"
        let deviceId: String

        if let savedUserId = UserDefaults.standard.string(forKey: userDefaultsKey),
           savedUserId != "00000000-0000-0000-0000-000000000000" {
            deviceId = savedUserId
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: userDefaultsKey)
        }

        let firestoreURL = "https://firestore.googleapis.com/v1/projects/disposable-53b41/databases/(default)/documents/events/\(eventId)/participants"

        let participantData: [String: Any] = [
            "fields": [
                "userId": ["stringValue": deviceId],
                "role": ["stringValue": "participant"],
                "name": ["stringValue": userName]
            ]
        ]

        guard let url = URL(string: firestoreURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: participantData)

        URLSession.shared.dataTask(with: request).resume()
    }

    func uploadPhoto(image: UIImage) {
        guard let eventId else { return }

        if let imageData = image.jpegData(compressionQuality: 0.85) {
            let fileName = "\(userName)_\(Date().timeIntervalSince1970).jpg"
            let storagePath = "events/\(eventId)/\(fileName)"
            let storageRef = Storage.storage().reference().child(storagePath)

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            storageRef.putData(imageData, metadata: metadata) { _, error in
                if let error {
                    print("Upload error: \(error)")
                    return
                }

                storageRef.downloadURL { url, error in
                    if let error {
                        print("Download URL error: \(error)")
                        return
                    }
                    guard let downloadURL = url else { return }

                    let firestoreURL = "https://firestore.googleapis.com/v1/projects/disposable-53b41/databases/(default)/documents/events/\(eventId)/images"
                    var request = URLRequest(url: URL(string: firestoreURL)!)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "fields": [
                            "url": ["stringValue": downloadURL.absoluteString],
                            "timestamp": ["stringValue": Date().iso8601],
                            "owner": ["stringValue": userName],
                            "source": ["stringValue": "app-clip-camera"]
                        ]
                    ]

                    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    URLSession.shared.dataTask(with: request).resume()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        fetchImagesForEvent(eventId: eventId)
                    }
                }
            }
        }
    }

    private func startVoiceRecording() {
        guard allowVoiceNotes else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(Date().timeIntervalSince1970).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecordingVoice = true
            voiceElapsed = 0

            voiceTimer?.invalidate()
            voiceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                voiceElapsed += 1
                if voiceElapsed >= voiceMaxSeconds {
                    stopVoiceRecording(save: true)
                }
            }
        } catch {
            print("Voice recording failed: \(error)")
        }
    }

    private func stopVoiceRecording(save: Bool) {
        guard isRecordingVoice else { return }

        voiceTimer?.invalidate()
        voiceTimer = nil

        audioRecorder?.stop()
        isRecordingVoice = false

        guard save, let url = audioRecorder?.url else { return }
        uploadVoiceNote(fileURL: url)
    }

    private func uploadVoiceNote(fileURL: URL) {
        guard let eventId else { return }
        let safeName = userName.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeName)_voice_\(Date().timeIntervalSince1970).m4a"
        let storagePath = "events/\(eventId)/voice/\(fileName)"
        let storageRef = Storage.storage().reference().child(storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        storageRef.putFile(from: fileURL, metadata: metadata) { _, error in
            if let error {
                print("Voice upload error: \(error)")
                return
            }
            storageRef.downloadURL { url, error in
                if let error {
                    print("Voice URL error: \(error)")
                    return
                }
                guard let downloadURL = url else { return }

                let firestoreURL = "https://firestore.googleapis.com/v1/projects/disposable-53b41/databases/(default)/documents/events/\(eventId)/voiceNotes"
                guard let endpoint = URL(string: firestoreURL) else { return }
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "fields": [
                        "url": ["stringValue": downloadURL.absoluteString],
                        "timestamp": ["stringValue": Date().iso8601],
                        "owner": ["stringValue": userName],
                        "source": ["stringValue": "app-clip-voice"]
                    ]
                ]

                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                URLSession.shared.dataTask(with: request).resume()
            }
        }
    }

    private func formatVoiceTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func isRevealLocked() -> Bool {
        guard revealMode == "At the end", let revealAtDate else { return false }
        return Date() < revealAtDate
    }
}

private struct TetamuPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(Color(hex: "#09121E"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(hex: "#E8D7FF"), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TetamuSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// Full-Screen View for Swiping through Photos
struct FullScreenPhotoView: View {
    var photos: [String]
    @Binding var selectedPhotoIndex: Int
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.top, 40)

            TabView(selection: $selectedPhotoIndex) {
                ForEach(0..<photos.count, id: \.self) { index in
                    WebImage(url: URL(string: photos[index]))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .edgesIgnoringSafeArea(.all)
        }
        .gesture(DragGesture().onEnded { gesture in
            if gesture.translation.height > 100 || gesture.translation.height < -100 {
                presentationMode.wrappedValue.dismiss()
            }
        })
    }
}

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            var pickedImages: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                pickedImages.append(image)
                            }
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.images = pickedImages
            }
        }
    }
}
