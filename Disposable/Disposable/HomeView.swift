//
//  HomeView.swift
//  Disposable
//

import SwiftUI
import FirebaseFirestore
import SceneKit

extension Color {
    init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: cleanHexCode).scanHexInt64(&rgb) else {
            self = .clear
            return
        }

        let redValue = Double((rgb >> 16) & 0xFF) / 255.0
        let greenValue = Double((rgb >> 8) & 0xFF) / 255.0
        let blueValue = Double(rgb & 0xFF) / 255.0
        self.init(red: redValue, green: greenValue, blue: blueValue)
    }
}

struct HomeView: View {
    @Binding var isInEvent: Bool
    @Binding var eventData: [String: Any]?
    @Binding var deepLinkedEventId: String?

    @State private var participantsCount: Int = 0
    @State private var countdownText: String = ""
    @State private var qrCodeImage: UIImage?

    @State private var showEndEventAlert = false
    @State private var showEventDeletedAlert = false
    @State private var navigateToJoinFromQR = false
    @State private var showPreRevealSheet = false

    @State private var eventEndTime: Date = Date()
    @State private var revealSetting: String = "Immediately"
    @State private var phoneShowingBack = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#1F1F1F")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isInEvent, let eventData = eventData {
                        activePOVDashboard(eventData)
                    } else {
                        emptyHostDashboard
                    }

                    NavigationLink(
                        destination: JoinEventView(
                            isInEvent: $isInEvent,
                            eventData: $eventData,
                            initialEventId: deepLinkedEventId
                        ),
                        isActive: $navigateToJoinFromQR
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
            .onAppear {
                restoreEventState()

                if isInEvent {
                    fetchParticipantsCount()
                    startCountdown()
                    generateQRCode()
                    fetchUserRole()
                    checkIfEventStillExists()

                    Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                        checkIfEventStillExists()
                    }
                }

                if deepLinkedEventId != nil {
                    navigateToJoinFromQR = true
                }
            }
            .onChange(of: deepLinkedEventId) { newValue in
                if newValue != nil && !isInEvent {
                    navigateToJoinFromQR = true
                }
            }
            .sheet(isPresented: $showPreRevealSheet) {
                HostPreRevealOverviewView(
                    eventName: eventData?["eventName"] as? String ?? "Tetamu Event",
                    location: eventData?["location"] as? String ?? "",
                    guests: participantsCount,
                    shots: eventData?["numberOfPhotos"] as? Int ?? 0,
                    voiceNotesEnabled: eventData?["allowVoiceNotes"] as? Bool ?? true
                )
            }
            .alert("Event Deleted", isPresented: $showEventDeletedAlert) {
                Button("OK") { leaveEvent() }
            } message: {
                Text("The event has been deleted by the organizer. Returning to the homepage.")
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private func eventHeader(_ data: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data["eventName"] as? String ?? "Event Name")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack {
                Label(data["userName"] as? String ?? "Organizer", systemImage: "person.fill")
                Spacer()
                Label("\(participantsCount)", systemImage: "person.2.fill")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white.opacity(0.8))

            if let location = data["location"] as? String, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var countdownBlock: some View {
        Group {
            if revealSetting == "At the end" {
                VStack(spacing: 8) {
                    Text("Reveal in")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))

                    Text(countdownText == "00:00:00" ? "Photos are revealed" : countdownText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F6DEC0"))
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color(hex: "#1A2032"), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var qrBlock: some View {
        Group {
            if let qrCodeImage = qrCodeImage {
                VStack(spacing: 10) {
                    Image(uiImage: qrCodeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                        .padding(10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

                    buttonStyle(title: "Share QR Code", background: Color(hex: "#E8D7FF"), foreground: Color(hex: "#09121E"), action: shareQRCode)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func preRevealCard(_ data: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pre-Reveal Overview")
                .font(.headline)
                .foregroundColor(.white)

            Text("Track guests, captures, and voice notes before reveal.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.74))

            HStack {
                statPill(label: "Guests", value: "\(participantsCount)")
                statPill(label: "Shots", value: "\(data["numberOfPhotos"] as? Int ?? 0)")
                statPill(label: "Voice", value: (data["allowVoiceNotes"] as? Bool ?? true) ? "On" : "Off")
            }

            buttonStyle(title: "Open Pre-Reveal Overview", background: Color.white.opacity(0.16), foreground: .white) {
                showPreRevealSheet = true
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#141A2A"), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButtons(_ data: [String: Any]) -> some View {
        VStack(spacing: 10) {
            if let role = data["role"] as? String, role == "organizer" {
                buttonStyle(title: "Share Website", background: Color(hex: "#2A334A"), foreground: .white, action: shareEventWebsite)

                buttonStyle(title: "End Event", background: Color(hex: "#A64A5A"), foreground: .white) {
                    showEndEventAlert = true
                }
                .alert("Are you sure?", isPresented: $showEndEventAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("End Event", role: .destructive) { endEvent() }
                } message: {
                    Text("This event and all its photos will be permanently deleted.")
                }
            } else {
                buttonStyle(title: "Leave Event", background: Color(hex: "#2A334A"), foreground: .white, action: leaveEvent)
            }
        }
    }

    private func activePOVDashboard(_ data: [String: Any]) -> some View {
        POVDashboardLayout(
            eventName: data["eventName"] as? String ?? "Tetamu POV",
            subtitle: subtitle(for: data),
            statusText: countdownText.isEmpty ? "Guests are capturing memories" : "Reveal in \(countdownText)",
            phoneShowingBack: $phoneShowingBack,
            createDestination: CreateEventView(isInEvent: $isInEvent, eventData: $eventData),
            joinDestination: JoinEventView(isInEvent: $isInEvent, eventData: $eventData),
            galleryAction: { showPreRevealSheet = true },
            cameraAction: shareQRCode,
            editAction: { showPreRevealSheet = true },
            qrAction: shareQRCode,
            shareAction: shareEventWebsite
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { showEndEventAlert = true }) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.24), in: Circle())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
            .alert("Are you sure?", isPresented: $showEndEventAlert) {
                Button("Cancel", role: .cancel) {}
                Button("End Event", role: .destructive) { endEvent() }
            } message: {
                Text("This event and all its photos will be permanently deleted.")
            }
        }
    }

    private var emptyHostDashboard: some View {
        POVDashboardLayout(
            eventName: "February 4 POV",
            subtitle: "Share with friends!",
            statusText: "Ended 3 months ago",
            phoneShowingBack: $phoneShowingBack,
            createDestination: CreateEventView(isInEvent: $isInEvent, eventData: $eventData),
            joinDestination: JoinEventView(isInEvent: $isInEvent, eventData: $eventData),
            galleryAction: {},
            cameraAction: {},
            editAction: {},
            qrAction: {},
            shareAction: {}
        )
    }

    private func subtitle(for data: [String: Any]) -> String {
        if let location = data["location"] as? String, !location.isEmpty {
            return location
        }
        return "Share with friends!"
    }

    private func buttonStyle(title: String, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(background, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shareEventWebsite() {
        guard let eventId = eventData?["eventId"] as? String else { return }

        let eventURL = "https://guest.tetamu.app/html/template.html?eventId=\(eventId)"
        let message = "Check out the full gallery for the event! \(eventURL)"

        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func fetchUserRole() {
        guard let eventId = eventData?["eventId"] as? String,
              let userName = eventData?["userName"] as? String else { return }

        let db = Firestore.firestore()
        let participantsRef = db.collection("events").document(eventId).collection("participants")

        participantsRef.whereField("name", isEqualTo: userName).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching role: \(error.localizedDescription)")
            } else if let document = snapshot?.documents.first {
                let role = document.data()["role"] as? String ?? "participant"
                DispatchQueue.main.async {
                    eventData?["role"] = role
                }
            }
        }
    }

    private func fetchParticipantsCount() {
        guard let eventId = eventData?["eventId"] as? String else { return }

        let db = Firestore.firestore()
        let participantsRef = db.collection("events").document(eventId).collection("participants")

        participantsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching participants count: \(error.localizedDescription)")
                self.participantsCount = 0
            } else {
                self.participantsCount = snapshot?.documents.count ?? 0
            }
        }
    }

    private func startCountdown() {
        guard let duration = eventData?["duration"] as? Int,
              let startTime = eventData?["startTime"] as? Timestamp else { return }

        self.eventEndTime = startTime.dateValue().addingTimeInterval(TimeInterval(duration * 3600))
        self.revealSetting = eventData?["reveal"] as? String ?? "Immediately"

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let remainingTime = eventEndTime.timeIntervalSince(Date())
            if remainingTime > 0 {
                let hours = Int(remainingTime) / 3600
                let minutes = (Int(remainingTime) % 3600) / 60
                let seconds = Int(remainingTime) % 60
                self.countdownText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                self.countdownText = "00:00:00"
                timer.invalidate()
            }
        }
    }

    private func shareQRCode() {
        guard let qrCodeImage = qrCodeImage,
              let eventName = eventData?["eventName"] as? String,
              let eventId = eventData?["eventId"] as? String else { return }

        let message = "Scan this QR code to join \"\(eventName)\" or enter event code \"\(eventId)\" in Tetamu."
        let activityVC = UIActivityViewController(activityItems: [message, qrCodeImage], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func generateQRCode() {
        guard let eventId = eventData?["eventId"] as? String else { return }

        let url = "https://guest.tetamu.app/clip?eventId=\(eventId)"
        guard let data = url.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return }

        let transform = CGAffineTransform(scaleX: 12, y: 12)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            self.qrCodeImage = UIImage(cgImage: cgImage)
        }
    }

    private func restoreEventState() {
        if let savedData = UserDefaults.standard.data(forKey: "currentEventData"),
           var decodedData = try? JSONSerialization.jsonObject(with: savedData, options: []) as? [String: Any] {
            if let startTime = decodedData["startTime"] as? Double {
                decodedData["startTime"] = Timestamp(date: Date(timeIntervalSince1970: startTime))
            }

            self.eventData = decodedData
            self.isInEvent = UserDefaults.standard.bool(forKey: "isInEvent")
        }
    }

    private func endEvent() {
        guard let eventId = eventData?["eventId"] as? String else { return }

        let db = Firestore.firestore()
        let eventDocRef = db.collection("events").document(eventId)

        eventDocRef.collection("participants").getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }

        eventDocRef.collection("images").getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }

        eventDocRef.delete { error in
            if error == nil {
                UserDefaults.standard.removeObject(forKey: "currentEventData")
                UserDefaults.standard.set(false, forKey: "isInEvent")
                isInEvent = false
                eventData = nil
            }
        }
    }

    private func leaveEvent() {
        UserDefaults.standard.removeObject(forKey: "currentEventData")
        UserDefaults.standard.set(false, forKey: "isInEvent")

        DispatchQueue.main.async {
            isInEvent = false
            eventData = nil
        }
    }

    private func checkIfEventStillExists() {
        guard let eventId = eventData?["eventId"] as? String else { return }

        let db = Firestore.firestore()
        let eventRef = db.collection("events").document(eventId)

        eventRef.getDocument { document, error in
            if error != nil || document?.exists == false {
                showEventDeletedAlert = true
            }
        }
    }
}

private struct POVDashboardLayout<CreateDestination: View, JoinDestination: View>: View {
    let eventName: String
    let subtitle: String
    let statusText: String
    @Binding var phoneShowingBack: Bool
    let createDestination: CreateDestination
    let joinDestination: JoinDestination
    let galleryAction: () -> Void
    let cameraAction: () -> Void
    let editAction: () -> Void
    let qrAction: () -> Void
    let shareAction: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var phoneRestingAngle: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = max(CGFloat(515), proxy.size.height - 190)
            let phoneHeight = min(CGFloat(350), max(CGFloat(295), heroHeight * 0.56))

            VStack(spacing: 10) {
                ZStack {
                    LinearGradient(
                        colors: phoneShowingBack
                            ? [Color(hex: "#111635"), Color(hex: "#34105A"), Color(hex: "#17071E")]
                            : [Color(hex: "#806552"), Color(hex: "#3D2F28"), Color(hex: "#0B0908")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 9) {
                        Spacer().frame(height: 18)

                        Text(eventName)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))

                        SwipeablePhoneMockup(
                            eventName: eventName,
                            showingBack: $phoneShowingBack,
                            dragOffset: $dragOffset,
                            restingAngle: $phoneRestingAngle
                        )
                        .frame(height: phoneHeight)
                        .padding(.top, 2)

                        Text(statusText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.45))

                        HStack(spacing: 9) {
                            dashboardToolButton(systemName: phoneShowingBack ? "photo.on.rectangle.angled" : "camera", action: phoneShowingBack ? galleryAction : cameraAction)
                            dashboardToolButton(systemName: "pencil", action: editAction)
                            dashboardToolButton(systemName: "qrcode", action: qrAction)
                            dashboardToolButton(systemName: "square.and.arrow.up", action: shareAction)
                        }
                        .padding(.horizontal, 10)

                        Capsule()
                            .fill(.white)
                            .frame(width: 112, height: 3)
                            .opacity(0.86)
                            .padding(.bottom, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)

                VStack(spacing: 10) {
                    NavigationLink(destination: createDestination) {
                        actionRow(
                            icon: "calendar.badge.plus",
                            title: "Schedule a POV Camera",
                            subtitle: "For parties, planned events, & weddings",
                            background: Color(hex: "#5C4EEA"),
                            foreground: .white
                        )
                    }

                    NavigationLink(destination: joinDestination) {
                        actionRow(
                            icon: "bolt.fill",
                            title: "Instant POV Camera",
                            subtitle: "For friends, trips, & when you're together",
                            background: Color(hex: "#2D3038"),
                            foreground: .white
                        )
                    }
                }
                .padding(.horizontal, 0)

                bottomBar
                    .padding(.horizontal, 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(Color.black)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
    }

    private func dashboardToolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }

    private func actionRow(icon: String, title: String, subtitle: String, background: Color, foreground: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .frame(width: 24)
                .foregroundStyle(foreground.opacity(0.72))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(foreground.opacity(0.74))
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
    }

    private var bottomBar: some View {
        HStack(spacing: 28) {
            Image(systemName: "plus.square")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color(hex: "#8478FF"))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(hex: "#272052"), in: RoundedRectangle(cornerRadius: 7))

            Image(systemName: "camera")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity)

            Image(systemName: "person")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 54)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.black)
    }
}

private struct SwipeablePhoneMockup: View {
    let eventName: String
    @Binding var showingBack: Bool
    @Binding var dragOffset: CGFloat
    @Binding var restingAngle: Double
    @State private var isCompletingFlip = false

    var body: some View {
        ZStack {
            Phone3DSceneView(
                eventName: eventName,
                angle: currentAngle,
                warmReflection: !showingBack
            )
                .frame(width: 280, height: 350)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .scaleEffect((1 - min(abs(dragOffset) / 900, 0.08)) * (isCompletingFlip ? 1.08 : 1))
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let shouldFlip = abs(value.translation.width) > 36 || abs(value.predictedEndTranslation.width) > 95

                    if shouldFlip {
                        let direction = value.translation.width < 0 ? -1.0 : 1.0
                        restingAngle += direction * 180
                        showingBack = isBackFacing(restingAngle)
                        dragOffset = 0

                        withAnimation(.easeOut(duration: 0.24)) {
                            isCompletingFlip = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                            withAnimation(.easeInOut(duration: 0.82)) {
                                isCompletingFlip = false
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.42)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private var currentAngle: Double {
        restingAngle + clampedPreviewAngle
    }

    private var clampedPreviewAngle: Double {
        let rawAngle = Double(dragOffset / 2.2)
        return min(max(rawAngle, -68), 68)
    }

    private func isBackFacing(_ angle: Double) -> Bool {
        let halfTurns = Int((angle / 180).rounded())
        return !abs(halfTurns).isMultiple(of: 2)
    }
}

private struct Phone3DSceneView: UIViewRepresentable, Animatable {
    let eventName: String
    var angle: Double
    let warmReflection: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.scene = context.coordinator.scene
        context.coordinator.build(eventName: eventName)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(eventName: eventName, angle: angle, warmReflection: warmReflection)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        let scene = SCNScene()
        private let phoneNode = SCNNode()
        private var currentEventName = ""
        private var currentAngle: Double = 0
        private var activeFlipTarget: Double?
        private let ambientLight = SCNLight()
        private let keyLight = SCNLight()
        private let fillLight = SCNLight()
        private let rimLight = SCNLight()
        private var tapeNode: SCNNode?
        private var frontTitleNode: SCNNode?

        init() {
            scene.rootNode.addChildNode(phoneNode)
            configureCamera()
            configureLights()
        }

        func build(eventName: String) {
            currentEventName = eventName
            phoneNode.childNodes.forEach { $0.removeFromParentNode() }

            if loadBundledIPhoneModel(eventName: eventName) {
                return
            }

            buildFallbackPhone(eventName: eventName)
        }

        func update(eventName: String, angle: Double, warmReflection: Bool) {
            if currentEventName != eventName {
                build(eventName: eventName)
            }

            updateLighting(warmReflection: warmReflection)

            let delta = abs(angle - currentAngle)
            let isReleaseFlip = delta > 80

            if let activeFlipTarget, abs(activeFlipTarget - angle) < 0.5 {
                return
            }

            if !isReleaseFlip {
                activeFlipTarget = nil
                phoneNode.removeAction(forKey: "dashboard-flip")
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0
                phoneNode.eulerAngles.y = radians(for: angle)
                SCNTransaction.commit()
                currentAngle = angle
                return
            }

            activeFlipTarget = angle
            phoneNode.removeAction(forKey: "dashboard-flip")
            let flip = SCNAction.rotateTo(
                x: CGFloat(phoneNode.eulerAngles.x),
                y: CGFloat(radians(for: angle)),
                z: CGFloat(phoneNode.eulerAngles.z),
                duration: 1.35,
                usesShortestUnitArc: false
            )
            flip.timingMode = .easeInEaseOut
            phoneNode.runAction(flip, forKey: "dashboard-flip") { [weak self] in
                DispatchQueue.main.async {
                    self?.currentAngle = angle
                    self?.activeFlipTarget = nil
                }
            }
        }

        private func radians(for angle: Double) -> Float {
            Float(angle * .pi / 180)
        }

        private func loadBundledIPhoneModel(eventName: String) -> Bool {
            guard let url = Bundle.main.url(forResource: "iPhone_17_Pro", withExtension: "usdz"),
                  let modelScene = try? SCNScene(url: url) else {
                return false
            }

            let wrapper = SCNNode()
            for child in modelScene.rootNode.childNodes {
                wrapper.addChildNode(child.clone())
            }
            normalizeModel(wrapper)
            wrapper.eulerAngles.x = -0.08
            wrapper.eulerAngles.y = .pi
            phoneNode.addChildNode(wrapper)

            addTapeLabel(eventName: eventName, z: 0.29, facesBack: true)
            return true
        }

        private func normalizeModel(_ node: SCNNode) {
            let bounds = node.boundingBox
            let min = bounds.min
            let max = bounds.max
            let width = max.x - min.x
            let height = max.y - min.y
            let depth = max.z - min.z
            let largest = Swift.max(width, Swift.max(height, depth))
            guard largest > 0 else { return }

            let targetHeight: Float = 3.1
            let scale = targetHeight / largest
            node.scale = SCNVector3(scale, scale, scale)

            let center = SCNVector3(
                (min.x + max.x) / 2,
                (min.y + max.y) / 2,
                (min.z + max.z) / 2
            )
            node.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
        }

        private func buildFallbackPhone(eventName: String) {
            addPhoneBody()
            addFrontFace(eventName: eventName)
            addBackFace(eventName: eventName)
            addSideButtons()
        }

        private func configureCamera() {
            let camera = SCNCamera()
            camera.fieldOfView = 36
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 6.2)
            scene.rootNode.addChildNode(cameraNode)
        }

        private func configureLights() {
            scene.lightingEnvironment.intensity = 1.55

            ambientLight.type = .ambient
            ambientLight.intensity = 250
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)

            keyLight.type = .directional
            keyLight.intensity = 980
            keyLight.castsShadow = true
            keyLight.shadowMode = .deferred
            keyLight.shadowRadius = 7
            keyLight.shadowColor = UIColor.black.withAlphaComponent(0.32)
            let keyNode = SCNNode()
            keyNode.light = keyLight
            keyNode.eulerAngles = SCNVector3(-0.55, -0.42, -0.2)
            scene.rootNode.addChildNode(keyNode)

            fillLight.type = .omni
            fillLight.intensity = 430
            let fillNode = SCNNode()
            fillNode.light = fillLight
            fillNode.position = SCNVector3(-2.1, 1.2, 3.6)
            scene.rootNode.addChildNode(fillNode)

            rimLight.type = .spot
            rimLight.intensity = 760
            rimLight.spotInnerAngle = 18
            rimLight.spotOuterAngle = 54
            let rimNode = SCNNode()
            rimNode.light = rimLight
            rimNode.position = SCNVector3(2.2, 1.8, -2.6)
            rimNode.eulerAngles = SCNVector3(-0.25, 2.45, 0)
            scene.rootNode.addChildNode(rimNode)

            updateLighting(warmReflection: true)
        }

        private func updateLighting(warmReflection: Bool) {
            if warmReflection {
                ambientLight.color = UIColor(red: 0.36, green: 0.25, blue: 0.19, alpha: 1)
                keyLight.temperature = 3600
                fillLight.color = UIColor(red: 0.72, green: 0.5, blue: 0.36, alpha: 1)
                rimLight.color = UIColor(red: 1, green: 0.78, blue: 0.52, alpha: 1)
            } else {
                ambientLight.color = UIColor(red: 0.22, green: 0.18, blue: 0.36, alpha: 1)
                keyLight.temperature = 4300
                fillLight.color = UIColor(red: 0.58, green: 0.5, blue: 1, alpha: 1)
                rimLight.color = UIColor(red: 0.9, green: 0.78, blue: 1, alpha: 1)
            }
        }

        private func addPhoneBody() {
            let body = SCNBox(width: 1.55, height: 3.05, length: 0.26, chamferRadius: 0.18)
            body.materials = [material(UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 1), roughness: 0.75, metalness: 0.18)]
            phoneNode.addChildNode(SCNNode(geometry: body))

            let metalEdge = SCNBox(width: 1.62, height: 3.12, length: 0.3, chamferRadius: 0.2)
            metalEdge.materials = [material(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1), roughness: 0.45, metalness: 0.7)]
            let edgeNode = SCNNode(geometry: metalEdge)
            edgeNode.opacity = 0.72
            phoneNode.addChildNode(edgeNode)
        }

        private func addFrontFace(eventName: String) {
            let screen = SCNBox(width: 1.38, height: 2.83, length: 0.025, chamferRadius: 0.14)
            screen.materials = [material(UIColor(red: 0.48, green: 0.38, blue: 0.3, alpha: 1), roughness: 0.55, metalness: 0.05)]
            let screenNode = SCNNode(geometry: screen)
            screenNode.position.z = 0.155
            phoneNode.addChildNode(screenNode)

            let island = SCNCapsule(capRadius: 0.045, height: 0.42)
            island.materials = [material(.black)]
            let islandNode = SCNNode(geometry: island)
            islandNode.eulerAngles.z = .pi / 2
            islandNode.position = SCNVector3(0, 1.28, 0.18)
            phoneNode.addChildNode(islandNode)

            frontTitleNode = textNode(eventName, size: 0.045, color: .white, extrusion: 0.002)
            frontTitleNode?.position = SCNVector3(-0.26, -0.9, 0.19)
            phoneNode.addChildNode(frontTitleNode!)

            let takePhoto = SCNBox(width: 1.12, height: 0.18, length: 0.015, chamferRadius: 0.025)
            takePhoto.materials = [material(.white)]
            let buttonNode = SCNNode(geometry: takePhoto)
            buttonNode.position = SCNVector3(0, -1.12, 0.19)
            phoneNode.addChildNode(buttonNode)
        }

        private func addBackFace(eventName: String) {
            addCameraBump()
            addTapeLabel(eventName: eventName, z: -0.17, facesBack: false)
        }

        private func addTapeLabel(eventName: String, z: Float, facesBack: Bool) {
            let tape = SCNPlane(width: 1.08, height: 0.26)
            let tapeMaterial = SCNMaterial()
            tapeMaterial.diffuse.contents = tapeTexture(eventName: eventName)
            tapeMaterial.roughness.contents = 0.9
            tapeMaterial.isDoubleSided = false
            tape.materials = [tapeMaterial]

            tapeNode = SCNNode(geometry: tape)
            tapeNode?.position = SCNVector3(0, 0.45, z)
            tapeNode?.eulerAngles.z = -0.06
            tapeNode?.eulerAngles.y = facesBack ? .pi : 0
            phoneNode.addChildNode(tapeNode!)
        }

        private func tapeTexture(eventName: String) -> UIImage {
            let size = CGSize(width: 520, height: 128)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                UIColor(red: 0.64, green: 0.59, blue: 0.66, alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 18).fill()

                UIColor(red: 0.46, green: 0.43, blue: 0.48, alpha: 0.22).setStroke()
                let border = UIBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 14)
                border.lineWidth = 4
                border.stroke()

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byTruncatingTail

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 42, weight: .black),
                    .foregroundColor: UIColor(red: 0.08, green: 0.07, blue: 0.1, alpha: 1),
                    .paragraphStyle: paragraph
                ]
                eventName.draw(
                    with: rect.insetBy(dx: 34, dy: 36),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attributes,
                    context: nil
                )
            }
        }

        private func addCameraBump() {
            let bump = SCNBox(width: 0.54, height: 0.58, length: 0.08, chamferRadius: 0.08)
            bump.materials = [material(UIColor(red: 0.14, green: 0.13, blue: 0.18, alpha: 1), roughness: 0.62, metalness: 0.1)]
            let bumpNode = SCNNode(geometry: bump)
            bumpNode.position = SCNVector3(-0.43, 1.04, -0.19)
            phoneNode.addChildNode(bumpNode)

            addLens(x: -0.55, y: 1.15)
            addLens(x: -0.34, y: 1.15)
            addLens(x: -0.55, y: 0.93)

            let flash = SCNSphere(radius: 0.045)
            flash.materials = [material(UIColor(white: 0.84, alpha: 1), roughness: 0.2)]
            let flashNode = SCNNode(geometry: flash)
            flashNode.position = SCNVector3(-0.34, 0.94, -0.24)
            phoneNode.addChildNode(flashNode)
        }

        private func addLens(x: Float, y: Float) {
            let lens = SCNCylinder(radius: 0.09, height: 0.055)
            lens.materials = [material(UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1), roughness: 0.22, metalness: 0.3)]
            let node = SCNNode(geometry: lens)
            node.eulerAngles.x = .pi / 2
            node.position = SCNVector3(x, y, -0.25)
            phoneNode.addChildNode(node)

            let ring = SCNTorus(ringRadius: 0.092, pipeRadius: 0.014)
            ring.materials = [material(UIColor(red: 0.42, green: 0.31, blue: 0.75, alpha: 1), roughness: 0.35, metalness: 0.45)]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(x, y, -0.282)
            phoneNode.addChildNode(ringNode)
        }

        private func addSideButtons() {
            let buttonMaterial = material(UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1), roughness: 0.35, metalness: 0.65)
            for y in [Float(0.75), Float(0.45)] {
                let button = SCNBox(width: 0.035, height: 0.24, length: 0.07, chamferRadius: 0.015)
                button.materials = [buttonMaterial]
                let node = SCNNode(geometry: button)
                node.position = SCNVector3(-0.84, y, 0.02)
                phoneNode.addChildNode(node)
            }
        }

        private func textNode(_ text: String, size: CGFloat, color: UIColor, extrusion: CGFloat) -> SCNNode {
            let geometry = SCNText(string: text, extrusionDepth: extrusion)
            geometry.font = UIFont.systemFont(ofSize: size, weight: .black)
            geometry.flatness = 0.2
            geometry.materials = [material(color)]
            let node = SCNNode(geometry: geometry)
            node.scale = SCNVector3(1, 1, 1)
            return node
        }

        private func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.roughness.contents = roughness
            mat.metalness.contents = metalness
            return mat
        }
    }
}

private struct HostPreRevealOverviewView: View {
    @Environment(\.dismiss) private var dismiss

    let eventName: String
    let location: String
    let guests: Int
    let shots: Int
    let voiceNotesEnabled: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: "#0D1020"), Color(hex: "#0A0D16")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text(eventName)
                        .font(.title.bold())
                        .foregroundColor(.white)

                    if !location.isEmpty {
                        Text(location)
                            .foregroundColor(.white.opacity(0.75))
                    }

                    HStack(spacing: 10) {
                        miniCard(title: "Guests", value: "\(guests)")
                        miniCard(title: "Shots/Guest", value: "\(shots)")
                        miniCard(title: "Voice", value: voiceNotesEnabled ? "On" : "Off")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Before reveal")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Use this as your host control snapshot before memories unlock.")
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    Spacer()

                    Button("Close") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#09121E"))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(Color(hex: "#E8D7FF"), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
            }
        }
    }

    private func miniCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
