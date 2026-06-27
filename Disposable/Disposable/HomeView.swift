//
//  HomeView.swift
//  Disposable
//

import SwiftUI
import SceneKit
import PhotosUI
import AVFoundation

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
    @Binding var selectedHomeTab: HomeDashboardTab
    let openSettingsTab: () -> Void

    @State private var participantsCount: Int = 0
    @State private var countdownText: String = ""
    @State private var qrCodeImage: UIImage?

    @State private var showEndEventAlert = false
    @State private var showEventDeletedAlert = false
    @State private var navigateToJoinFromQR = false
    @State private var showPreRevealSheet = false
    @State private var isHomeModalPresented = false
    @State private var currentHomeModal: HomeDashboardModal = .details
    @State private var homeModalMeasuredHeight: CGFloat = 640

    @State private var eventEndTime: Date = Date()
    @State private var revealSetting: String = "Immediately"
    @State private var homeEventName = "Your Event"
    @State private var phoneShowingBack = false
    @State private var hasInitializedDashboardControls = false
    @State private var selectedGuestLimit = 10
    @State private var selectedPhotosPerPerson = 10
    @State private var selectedRevealOption = "12 hours after"
    @State private var selectedFilterOption = "Disposable film"
    @State private var selectedShareTemplate: QRShareTemplateStyle = .plain
    @State private var selectedShareBackground: QRShareBackground = .warm
    @State private var selectedShareQRColor: QRShareColor = .black
    @State private var coverDraft = HomeCoverDraft()
    @State private var isCameraFlowPresented = false
    @State private var showQRScanner = false
    @State private var showCreateFlow = false
    @State private var myCreatedEvents: [[String: Any]] = []

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

                }
            }
            .navigationDestination(isPresented: $navigateToJoinFromQR) {
                JoinEventView(
                    isInEvent: $isInEvent,
                    eventData: $eventData,
                    initialEventId: deepLinkedEventId
                )
            }
            .onAppear {
                restoreEventState()
                loadMyCreatedEvents()

                syncHomeEventName()
                phoneShowingBack = false
                initializeDashboardControlsIfNeeded()

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
            .onChange(of: deepLinkedEventId) { _, newValue in
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
            .fullScreenCover(isPresented: $showCreateFlow) {
                CreatePOVFlowView(
                    hostFirstName: hostFirstName,
                    onPublish: { newDict, newDraft in
                        addCreatedEvent(newDict)
                        coverDraft = newDraft
                        isInEvent = true
                        eventData = newDict
                        homeEventName = newDict["eventName"] as? String ?? homeEventName
                        syncHomeEventName()
                        generateQRCode()
                        selectedHomeTab = .cameras
                    }
                )
            }
            .sheet(isPresented: $isHomeModalPresented, onDismiss: {
                currentHomeModal = .details
            }) {
                homeModalView(for: currentHomeModal)
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(28)
                    .presentationBackground(Color.clear)
                    .presentationDetents(homeModalDetents)
                    .interactiveDismissDisabled(true)
            }
            .fullScreenCover(isPresented: $isCameraFlowPresented) {
                POVCameraFlowView(
                    eventID: currentEventID,
                    userName: currentUserName,
                    eventName: homeEventName,
                    endDateText: "Ends on 23 May",
                    shotsAllowed: selectedPhotosPerPerson,
                    coverDraft: coverDraft
                )
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                QRScannerSheet(
                    dismissAction: { showQRScanner = false },
                    scanAction: handleScannedQRCode
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
                .font(.satoshi(size: 30, weight: .bold))
                .foregroundColor(.white)

            HStack {
                Label(data["userName"] as? String ?? "Organizer", systemImage: "person.fill")
                Spacer()
                Label("\(participantsCount)", systemImage: "person.2.fill")
            }
            .font(.satoshi(.subheadline, weight: .medium))
            .foregroundColor(.white.opacity(0.8))

            if let location = data["location"] as? String, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.satoshi(.footnote))
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
                        .font(.satoshi(.footnote, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))

                    Text(countdownText == "00:00:00" ? "Photos are revealed" : countdownText)
                        .font(.satoshi(size: 30, weight: .bold))
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
                .font(.satoshi(.headline, weight: .bold))
                .foregroundColor(.white)

            Text("Track guests, captures, and voice notes before reveal.")
                .font(.satoshi(.subheadline))
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
                .font(.satoshi(.headline, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.satoshi(.caption2))
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
            eventName: homeEventName,
            coverDraft: coverDraft,
            subtitle: subtitle(for: data),
            statusText: dashboardStatusText(for: data),
            selectedTab: $selectedHomeTab,
            phoneShowingBack: $phoneShowingBack,
            scheduleAction: { showCreateFlow = true },
            instantAction: { showCreateFlow = true },
            galleryAction: { showQRScanner = true },
            cameraAction: { isCameraFlowPresented = true },
            editAction: { presentHomeModal(.details) },
            qrAction: { presentHomeModal(.share) },
            shareAction: { presentHomeModal(.share) },
            settingsTabAction: openSettingsTab,
            myCreatedEvents: myCreatedEvents,
            openCameraForEvent: { dict in
                eventData = dict
                homeEventName = dict["eventName"] as? String ?? homeEventName
                syncHomeEventName()
                isCameraFlowPresented = true
            }
        )
        .alert("Are you sure?", isPresented: $showEndEventAlert) {
            Button("Cancel", role: .cancel) {}
            Button("End Event", role: .destructive) { endEvent() }
        } message: {
            Text("This event and all its photos will be permanently deleted.")
        }
    }

    private var emptyHostDashboard: some View {
        POVDashboardLayout(
            eventName: homeEventName,
            coverDraft: coverDraft,
            subtitle: "Share with friends!",
            statusText: "Up to 10 Guests • Ends 23 May at 23:59",
            selectedTab: $selectedHomeTab,
            phoneShowingBack: $phoneShowingBack,
            scheduleAction: { showCreateFlow = true },
            instantAction: { showCreateFlow = true },
            galleryAction: { showQRScanner = true },
            cameraAction: { isCameraFlowPresented = true },
            editAction: { presentHomeModal(.details) },
            qrAction: { presentHomeModal(.share) },
            shareAction: { presentHomeModal(.share) },
            settingsTabAction: openSettingsTab,
            myCreatedEvents: myCreatedEvents,
            openCameraForEvent: { dict in
                eventData = dict
                homeEventName = dict["eventName"] as? String ?? homeEventName
                syncHomeEventName()
                isCameraFlowPresented = true
            }
        )
    }

    @ViewBuilder
    private func homeModalView(for modal: HomeDashboardModal) -> some View {
        ZStack(alignment: .bottom) {
            HomeEventDetailsSheet(
                summary: dashboardSummary(),
                eventName: $homeEventName,
                coverDraft: $coverDraft,
                saveEventNameAction: saveEventName,
                saveCoverDraftAction: saveCoverDraft
            ) { selection in
                navigateHomeModal(to: selection)
            } dismissAction: {
                dismissHomeModal()
            }
            .allowsHitTesting(modal == .details)

            if modal == .share {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                homeModalPage(for: modal)
                    .id(modal.id)
                    .transition(childOverlayTransition)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: modal)
        .onPreferenceChange(HomeSheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            guard modal != .share else { return }
            let persistentButtonHeight: CGFloat = modal == .details ? 76 : 0
            let detentHeight = clampedHomeModalHeight(height + persistentButtonHeight)
            guard abs(homeModalMeasuredHeight - detentHeight) > 1 else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                homeModalMeasuredHeight = detentHeight
            }
        }
    }

    @ViewBuilder
    private func homeModalPage(for modal: HomeDashboardModal) -> some View {
        let summary = dashboardSummary()

        switch modal {
        case .details:
            EmptyView()
        case .guests:
            GuestLimitSheet(
                summary: summary,
                selectedLimit: $selectedGuestLimit,
                backAction: { navigateHomeModal(to: .details) },
                dismissAction: dismissHomeModal
            )
        case .ended:
            EventEndSheet(
                summary: summary,
                backAction: { navigateHomeModal(to: .details) },
                dismissAction: dismissHomeModal
            )
        case .reveal:
            RevealPhotosSheet(
                summary: summary,
                selectedReveal: $selectedRevealOption,
                backAction: { navigateHomeModal(to: .details) },
                dismissAction: dismissHomeModal
            )
        case .filter:
            FilterSelectionSheet(
                summary: summary,
                selectedFilter: $selectedFilterOption,
                backAction: { navigateHomeModal(to: .details) },
                dismissAction: dismissHomeModal
            )
        case .photos:
            PhotosPerPersonSheet(
                summary: summary,
                selectedPhotos: $selectedPhotosPerPerson,
                backAction: { navigateHomeModal(to: .details) },
                dismissAction: dismissHomeModal
            )
        case .share:
            ShareEventCardSheet(
                summary: summary,
                qrCodeImage: qrCodeImage,
                selectedTemplate: $selectedShareTemplate,
                selectedBackground: $selectedShareBackground,
                selectedQRColor: $selectedShareQRColor,
                dismissAction: dismissHomeModal,
                shareAction: shareSelectedQRCodeTemplate
            )
        }
    }

    private var childOverlayTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.78, anchor: .bottom).combined(with: .move(edge: .bottom)),
            removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .move(edge: .bottom))
        )
    }

    private func presentHomeModal(_ modal: HomeDashboardModal) {
        currentHomeModal = modal
        homeModalMeasuredHeight = contentHeight(for: modal)
        if modal == .share { generateQRCode() }
        isHomeModalPresented = true
    }

    private func navigateHomeModal(to modal: HomeDashboardModal) {
        guard currentHomeModal != modal else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            homeModalMeasuredHeight = contentHeight(for: modal)
            currentHomeModal = modal
        }
    }

    private func dismissHomeModal() {
        isHomeModalPresented = false
    }

    private func handleScannedQRCode(_ scannedValue: String) {
        showQRScanner = false

        if let eventId = extractEventId(from: scannedValue) {
            deepLinkedEventId = eventId
            navigateToJoinFromQR = true
        }
    }

    private func extractEventId(from scannedValue: String) -> String? {
        if let url = URL(string: scannedValue),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let eventId = components.queryItems?.first(where: { $0.name == "eventId" })?.value,
           !eventId.isEmpty {
            return eventId
        }

        let trimmed = scannedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var currentEventID: String {
        eventData?["eventId"] as? String ?? "noEvent"
    }

    private var currentUserName: String {
        eventData?["userName"] as? String ?? "anonymous"
    }

    private var hostFirstName: String {
        let full = currentUserName == "anonymous"
            ? (myCreatedEvents.first?["userName"] as? String ?? "")
            : currentUserName
        return full.components(separatedBy: " ").first ?? full
    }

    private func loadMyCreatedEvents() {
        if let data = UserDefaults.standard.data(forKey: "myCreatedEvents"),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let filtered = arr.filter(isValidStoredEvent)
            myCreatedEvents = filtered
            if filtered.count != arr.count {
                saveMyCreatedEvents()
            }
        }
    }

    private func saveMyCreatedEvents() {
        if let data = try? JSONSerialization.data(withJSONObject: myCreatedEvents) {
            UserDefaults.standard.set(data, forKey: "myCreatedEvents")
        }
    }

    private func addCreatedEvent(_ dict: [String: Any]) {
        myCreatedEvents.removeAll { ($0["eventId"] as? String) == (dict["eventId"] as? String) }
        myCreatedEvents.insert(dict, at: 0)
        saveMyCreatedEvents()
    }

    private var homeModalDetents: Set<PresentationDetent> {
        [.height(homeModalMeasuredHeight)]
    }

    private func clampedHomeModalHeight(_ height: CGFloat) -> CGFloat {
        let minimumHeight: CGFloat = 360
        let maximumHeight = UIScreen.main.bounds.height * 0.995
        return min(max(height, minimumHeight), maximumHeight)
    }

    private func contentHeight(for modal: HomeDashboardModal) -> CGFloat {
        switch modal {
        case .details:
            return 724
        case .guests:
            return 560
        case .ended:
            return 700
        case .reveal:
            return 430
        case .filter:
            return 460
        case .photos:
            return 450
        case .share:
            return UIScreen.main.bounds.height
        }
    }

    private func dashboardSummary() -> HomeEventSummary {
        let data = eventData ?? [:]
        let endDate = endDateText(from: data)

        return HomeEventSummary(
            eventName: homeEventName,
            guestLimit: selectedGuestLimit,
            photosPerPerson: selectedPhotosPerPerson,
            reveal: selectedRevealOption,
            filter: selectedFilterOption,
            endedText: endDate
        )
    }

    private func initializeDashboardControlsIfNeeded() {
        guard !hasInitializedDashboardControls else { return }
        let data = eventData ?? [:]
        syncHomeEventName()
        selectedPhotosPerPerson = data["numberOfPhotos"] as? Int ?? 10
        selectedGuestLimit = data["guestLimit"] as? Int ?? max(participantsCount, 10)
        selectedRevealOption = revealTitle(from: data["reveal"] as? String)
        selectedFilterOption = filterTitle(from: data["filterStyle"] as? String)
        hasInitializedDashboardControls = true
    }

    private func filterTitle(from value: String?) -> String {
        switch value {
        case "vintage":
            return "Disposable film"
        case "none":
            return "None"
        default:
            return "Disposable film"
        }
    }

    private func revealTitle(from value: String?) -> String {
        switch value {
        case "Immediately":
            return "During"
        case "At the end":
            return "12 hours after"
        default:
            return "12 hours after"
        }
    }

    private func endDateText(from data: [String: Any]) -> String {
        guard let duration = data["duration"] as? Int,
              let startTimeRaw = data["startTime"] as? Double else {
            return "Sat 23 May • 23:59 GMT+8"
        }
        let endDate = Date(timeIntervalSince1970: startTimeRaw).addingTimeInterval(TimeInterval(duration * 3600))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • HH:mm"
        return "\(formatter.string(from: endDate)) GMT+8"
    }

    private func dashboardStatusText(for data: [String: Any]) -> String {
        let guestLimit = data["guestLimit"] as? Int ?? selectedGuestLimit
        guard let duration = data["duration"] as? Int,
              let startTimeRaw = data["startTime"] as? Double else {
            return "Up to \(guestLimit) Guests • Ends 23 May at 23:59"
        }
        let endDate = Date(timeIntervalSince1970: startTimeRaw).addingTimeInterval(TimeInterval(duration * 3600))
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM 'at' HH:mm"
        return "Up to \(guestLimit) Guests • Ends \(formatter.string(from: endDate))"
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

        let eventURL = "https://tetamu.app/clip?eventId=\(eventId)"
        let message = "Check out the full gallery for the event! \(eventURL)"

        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func fetchUserRole() {
        // Role is stored locally in eventData when joining/creating
    }

    private func fetchParticipantsCount() {
        guard let eventId = eventData?["eventId"] as? String else { return }
        Task {
            let count = (try? await SupabaseManager.shared.fetchGuestCount(eventId: eventId)) ?? 0
            await MainActor.run { participantsCount = count }
        }
    }

    private func startCountdown() {
        guard let duration = eventData?["duration"] as? Int,
              let startTimeRaw = eventData?["startTime"] as? Double else { return }

        self.eventEndTime = Date(timeIntervalSince1970: startTimeRaw).addingTimeInterval(TimeInterval(duration * 3600))
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
              let eventId = eventData?["eventId"] as? String else { return }

        let message = "Scan this QR code to join \"\(homeEventName)\" or enter event code \"\(eventId)\" in Tetamu."
        let activityVC = UIActivityViewController(activityItems: [message, qrCodeImage], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func shareSelectedQRCodeTemplate() {
        let summary = dashboardSummary()
        let content = QRShareTemplateCard(
            summary: summary,
            qrCodeImage: qrCodeImage,
            template: selectedShareTemplate,
            background: selectedShareBackground,
            qrColor: selectedShareQRColor,
            displayMode: .export
        )
        .frame(width: 1080, height: 1620)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        guard let renderedImage = renderer.uiImage else {
            shareQRCode()
            return
        }

        let activityVC = UIActivityViewController(activityItems: [renderedImage], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func generateQRCode() {
        // Prefer myCreatedEvents (guaranteed Supabase-backed) over stale eventData
        let eventId = (myCreatedEvents.first?["eventId"] as? String)
            ?? (eventData?["eventId"] as? String)
        guard let eventId, !eventId.isEmpty else { return }

        let url = "https://tetamu.app/clip?eventId=\(eventId)"
        guard let data = url.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return }

        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return }

        // Composite black QR onto white background — prevents transparent/black-box display
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        self.qrCodeImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func restoreEventState() {
        if let savedData = UserDefaults.standard.data(forKey: "currentEventData"),
           let decodedData = try? JSONSerialization.jsonObject(with: savedData, options: []) as? [String: Any],
           isValidStoredEvent(decodedData),
           UserDefaults.standard.bool(forKey: "isInEvent") {
            eventData = decodedData
            isInEvent = true
            syncHomeEventName()
        } else {
            UserDefaults.standard.removeObject(forKey: "currentEventData")
            UserDefaults.standard.set(false, forKey: "isInEvent")
            eventData = nil
            isInEvent = false
        }
    }

    private func syncHomeEventName() {
        if let storedName = eventData?["eventName"] as? String,
           !storedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            homeEventName = storedName
        } else if homeEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            homeEventName = "Your Event"
        }

        coverDraft.title = eventData?["coverTitle"] as? String ?? homeEventName
        coverDraft.subtitle = eventData?["coverSubtitle"] as? String ?? coverDraft.subtitle
        coverDraft.buttonTitle = eventData?["coverButtonTitle"] as? String ?? coverDraft.buttonTitle
        if let styleRaw = eventData?["coverStyle"] as? String,
           let style = HomeCoverStyle(rawValue: styleRaw) {
            coverDraft.style = style
        }
    }

    private func saveEventName(_ newValue: String) {
        let trimmedName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Your Event" : trimmedName

        homeEventName = resolvedName
        eventData?["eventName"] = resolvedName
        persistCurrentEventDataLocally()

        // Supabase: event name updates handled server-side; local state persisted below
    }

    private func saveCoverDraft(_ draft: HomeCoverDraft) {
        let resolvedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? homeEventName : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        coverDraft = draft
        coverDraft.title = resolvedTitle
        saveEventName(resolvedTitle)

        eventData?["coverTitle"] = resolvedTitle
        eventData?["coverSubtitle"] = draft.subtitle
        eventData?["coverButtonTitle"] = draft.buttonTitle
        eventData?["coverStyle"] = draft.style.rawValue
        persistCurrentEventDataLocally()

        guard let eventId = eventData?["eventId"] as? String else { return }

        if let image = draft.image,
           let jpegData = image.jpegData(compressionQuality: 0.82) {
            Task {
                let coverURL = try? await SupabaseManager.shared.uploadCoverImage(
                    eventId: eventId,
                    jpegData: jpegData
                )
                await MainActor.run {
                    if let coverURL {
                        eventData?["coverImageUrl"] = coverURL
                        persistCurrentEventDataLocally()
                    }
                }
            }
        }
    }

    private func persistCurrentEventDataLocally() {
        guard let eventData,
              let encodedData = try? JSONSerialization.data(withJSONObject: eventData, options: []) else { return }
        UserDefaults.standard.set(encodedData, forKey: "currentEventData")
        UserDefaults.standard.set(isInEvent, forKey: "isInEvent")
    }

    private func isValidStoredEvent(_ dict: [String: Any]) -> Bool {
        guard let eventId = dict["eventId"] as? String else { return false }
        let trimmedId = eventId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty, trimmedId != "noEvent" else { return false }
        return true
    }

    private func endEvent() {
        guard let eventId = eventData?["eventId"] as? String else { return }
        Task {
            try? await SupabaseManager.shared.deleteEvent(id: eventId)
            await MainActor.run {
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
        Task {
            do {
                _ = try await SupabaseManager.shared.fetchEvent(id: eventId)
            } catch {
                await MainActor.run { showEventDeletedAlert = true }
            }
        }
    }
}

private enum HomeDashboardModal: Identifiable {
    case details
    case guests
    case ended
    case reveal
    case filter
    case photos
    case share

    var id: String {
        switch self {
        case .details: return "details"
        case .guests: return "guests"
        case .ended: return "ended"
        case .reveal: return "reveal"
        case .filter: return "filter"
        case .photos: return "photos"
        case .share: return "share"
        }
    }
}

private struct HomeSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HomeEventSummary {
    let eventName: String
    let guestLimit: Int
    let photosPerPerson: Int
    let reveal: String
    let filter: String
    let endedText: String
}

private enum HomeCoverStyle: String, CaseIterable, Identifiable {
    case polaroid
    case starter
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .polaroid: return "Polaroid"
        case .starter: return "Starter"
        case .minimal: return "Clean"
        }
    }
}

private struct HomeCoverDraft {
    var style: HomeCoverStyle = .polaroid
    var title: String = "Your Event"
    var subtitle: String = "Invite your guests"
    var buttonTitle: String = "Take Photos"
    var image: UIImage?
}

private enum QRShareTemplateStyle: String, CaseIterable, Identifiable {
    case plain
    case sparkles
    case midnight
    case garden
    case ticket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "Plain QR Code"
        case .sparkles: return "Sparkles"
        case .midnight: return "Midnight"
        case .garden: return "Garden Party"
        case .ticket: return "Ticket Stub"
        }
    }

    var subtitle: String {
        switch self {
        case .plain: return "Clean and fast to scan"
        case .sparkles: return "Elegant event invite"
        case .midnight: return "Bold dark poster"
        case .garden: return "Soft floral card"
        case .ticket: return "Keepsake pass"
        }
    }
}

private enum QRShareBackground: String, CaseIterable, Identifiable {
    case warm
    case cream
    case charcoal
    case blush
    case ocean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warm: return "Warm"
        case .cream: return "Cream"
        case .charcoal: return "Charcoal"
        case .blush: return "Blush"
        case .ocean: return "Ocean"
        }
    }

    var colors: [Color] {
        switch self {
        case .warm: return [Color(hex: "#6B5B52"), Color(hex: "#332C3F"), Color(hex: "#171822")]
        case .cream: return [Color(hex: "#FFF8ED"), Color(hex: "#EBD7B8"), Color(hex: "#C7A982")]
        case .charcoal: return [Color(hex: "#161923"), Color(hex: "#080A10"), Color(hex: "#1F2230")]
        case .blush: return [Color(hex: "#FFDCE7"), Color(hex: "#DDB6A1"), Color(hex: "#826A72")]
        case .ocean: return [Color(hex: "#DDF7FF"), Color(hex: "#7EA8B8"), Color(hex: "#1C3B4A")]
        }
    }
}

private enum QRShareColor: String, CaseIterable, Identifiable {
    case black
    case violet
    case espresso
    case forest
    case ivory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .violet: return "Violet"
        case .espresso: return "Espresso"
        case .forest: return "Forest"
        case .ivory: return "Ivory"
        }
    }

    var color: Color {
        switch self {
        case .black: return .black
        case .violet: return Color(hex: "#554DE8")
        case .espresso: return Color(hex: "#2C1E18")
        case .forest: return Color(hex: "#183E34")
        case .ivory: return Color(hex: "#FFF8ED")
        }
    }
}

private enum QRShareDisplayMode {
    case preview
    case export
}

private struct HomeEventDetailsSheet: View {
    let summary: HomeEventSummary
    @Binding var eventName: String
    @Binding var coverDraft: HomeCoverDraft
    let saveEventNameAction: (String) -> Void
    let saveCoverDraftAction: (HomeCoverDraft) -> Void
    let selectAction: (HomeDashboardModal) -> Void
    let dismissAction: () -> Void

    @Namespace private var coverEditorNamespace
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @FocusState private var titleFieldFocused: Bool
    @State private var guestsCanViewGallery = true
    @State private var expandingSelection: HomeDashboardModal?
    @State private var inlineExpandedSelection: HomeDashboardModal?
    @State private var isCoverEditorPresented = false
    @State private var selectedCoverPhotoItem: PhotosPickerItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            HomeSheetContainer {
                VStack(spacing: 10) {
                HStack {
                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.satoshi(size: 22, weight: .medium))
                            .foregroundStyle(.black.opacity(0.55))
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.06), in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 12) {
                        if isEditingTitle {
                            TextField("Event name", text: $titleDraft)
                                .font(.satoshi(size: 22, weight: .black))
                                .foregroundStyle(.black)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($titleFieldFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    commitTitleEdit()
                                }
                        } else {
                            Text(summary.eventName)
                                .font(.satoshi(size: 22, weight: .black))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        if isEditingTitle {
                            Button(action: commitTitleEdit) {
                                Image(systemName: "checkmark")
                                    .font(.satoshi(.headline, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 34)
                                    .background(Color.black, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)

                            Button(action: cancelTitleEdit) {
                                Image(systemName: "xmark")
                                    .font(.satoshi(.headline, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.5))
                                    .frame(width: 38, height: 34)
                                    .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: beginTitleEdit) {
                                Image(systemName: "pencil")
                                    .font(.satoshi(size: 18, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.55))
                                    .frame(width: 46, height: 30)
                                    .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.satoshi(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(width: 36, height: 36)
                }

                HomeDetailsCoverSection(
                    summary: summary,
                    coverDraft: coverDraft,
                    namespace: coverEditorNamespace,
                    editAction: openCoverEditor,
                    photoSelection: $selectedCoverPhotoItem
                )

                VStack(spacing: 0) {
                    settingRowOrInlinePanel(
                        .guests,
                        icon: "person.2",
                        title: "Number of Guests",
                        value: "Up to \(summary.guestLimit) participants"
                    )
                    HomeDivider()
                    settingRowOrInlinePanel(
                        .ended,
                        icon: "calendar",
                        title: "Ended",
                        value: summary.endedText
                    )
                    HomeDivider()
                    settingRowOrInlinePanel(
                        .reveal,
                        icon: "hourglass",
                        title: "Reveal Photos",
                        value: summary.reveal
                    )
                    HomeDivider()
                    settingRowOrInlinePanel(
                        .filter,
                        icon: "photo",
                        title: "Filter",
                        value: summary.filter
                    )
                    HomeDivider()
                    settingRowOrInlinePanel(
                        .photos,
                        icon: "camera",
                        title: "Photos per Person",
                        value: "\(summary.photosPerPerson) photos"
                    )
                }

                HStack(spacing: 16) {
                    Image(systemName: "lock.open")
                        .font(.satoshi(size: 21, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                        .frame(width: 34)

                    Text("Guests can view gallery")
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundStyle(.black.opacity(0.85))

                    Spacer()

                    Toggle("", isOn: $guestsCanViewGallery)
                        .labelsHidden()
                        .tint(Color.black)
                        .scaleEffect(1.05)
                }
                .frame(height: 64)
                .padding(.top, 2)
                }
                .padding(.bottom, 10)
            }
            .opacity(isCoverEditorPresented ? 0.18 : 1)
            .blur(radius: isCoverEditorPresented ? 5 : 0)
            .allowsHitTesting(!isCoverEditorPresented)
            .accessibilityHidden(isCoverEditorPresented)
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if inlineExpandedSelection == nil && !isCoverEditorPresented {
                    VStack(spacing: 0) {
                        Button(action: dismissAction) {
                            Text("Dismiss")
                                .font(.satoshi(size: 18, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black, in: RoundedRectangle(cornerRadius: 26))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.white
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }

            if let inlineExpandedSelection {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            self.inlineExpandedSelection = nil
                        }
                    }

                HomeInlineExpandedPanel(
                    modal: inlineExpandedSelection,
                    summary: summary,
                    closeAction: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            self.inlineExpandedSelection = nil
                        }
                    }
                )
                .padding(.bottom, 10)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82, anchor: .top).combined(with: .move(edge: .bottom)).combined(with: .opacity),
                    removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
                ))
            }

            if isCoverEditorPresented {
                HomeCoverEditorScreen(
                    draft: $coverDraft,
                    namespace: coverEditorNamespace,
                    doneAction: closeCoverEditor
                )
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .onAppear {
            titleDraft = eventName
            if coverDraft.title == "Your Event", eventName != coverDraft.title {
                coverDraft.title = eventName
            }
        }
        .onChange(of: eventName) { _, newValue in
            if !isEditingTitle {
                titleDraft = newValue
            }
            if !isCoverEditorPresented {
                coverDraft.title = newValue
            }
        }
        .onChange(of: selectedCoverPhotoItem) { _, item in
            loadSelectedCoverPhoto(item)
        }
    }

    private func openCoverEditor() {
        coverDraft.title = eventName
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            isCoverEditorPresented = true
        }
    }

    private func closeCoverEditor() {
        saveCoverDraftAction(coverDraft)
        withAnimation(.spring(response: 0.44, dampingFraction: 0.9)) {
            isCoverEditorPresented = false
        }
    }

    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    coverDraft.image = image.coverEditorPreparedImage()
                }
                saveCoverDraftAction(coverDraft)
                selectedCoverPhotoItem = nil
            }
        }
    }

    private func beginTitleEdit() {
        titleDraft = eventName
        isEditingTitle = true
        titleFieldFocused = true
    }

    private func cancelTitleEdit() {
        titleDraft = eventName
        isEditingTitle = false
        titleFieldFocused = false
    }

    private func commitTitleEdit() {
        saveEventNameAction(titleDraft)
        titleDraft = eventName
        isEditingTitle = false
        titleFieldFocused = false
    }

    private func expandThenSelect(_ selection: HomeDashboardModal) {
        guard expandingSelection == nil else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            expandingSelection = selection
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                inlineExpandedSelection = inlineExpandedSelection == selection ? nil : selection
                expandingSelection = nil
            }
        }
    }

    @ViewBuilder
    private func settingRowOrInlinePanel(_ selection: HomeDashboardModal, icon: String, title: String, value: String) -> some View {
        HomeSettingRow(
            icon: icon,
            title: title,
            value: value,
            expanded: expandingSelection == selection || inlineExpandedSelection == selection,
            appearance: .light
        ) {
            expandThenSelect(selection)
        }
    }

    @ViewBuilder
    private func inlineChildPanel(_ selection: HomeDashboardModal) -> some View {
        if inlineExpandedSelection == selection {
            HomeInlineExpandedPanel(
                modal: selection,
                summary: summary,
                closeAction: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        inlineExpandedSelection = nil
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.94, anchor: .top).combined(with: .opacity),
                removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
            ))
        }
    }
}

private struct GuestLimitSheet: View {
    let summary: HomeEventSummary
    @Binding var selectedLimit: Int
    let backAction: () -> Void
    let dismissAction: () -> Void

    private let guestLevels = [10, 25, 50, 75, 100, 150, 250]

    private var filledSegments: Int {
        (guestLevels.firstIndex(of: selectedLimit) ?? 0) + 1
    }

    var body: some View {
        HomeExpandedSheet(
            icon: "person.2",
            title: "Number of Guests",
            value: "Up to \(selectedLimit) participants",
            description: "Pricing scales for more guests. Upgrade at any time, even after publishing. Guests can participate without downloading the app by scanning a QR code or opening a link.",
            backAction: backAction,
            dismissAction: dismissAction
        ) {
            VStack(alignment: .leading, spacing: 18) {
                SegmentedSelectionBar(
                    options: guestLevels,
                    filledSegments: filledSegments,
                    selectedValue: selectedLimit
                ) { level in
                    selectedLimit = level
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(guestLevels, id: \.self) { level in
                        SelectableButtonPill(
                            title: "\(level)",
                            subtitle: level == 10 ? "Current" : (level <= 25 ? "$5" : "Upgrade"),
                            selected: selectedLimit == level
                        ) {
                            selectedLimit = level
                        }
                    }
                }

                HStack {
                    Text("Up to \(selectedLimit) guests")
                        .font(.satoshi(.title3, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(selectedLimit <= 10 ? "Current Level" : "$5 Upgrade")
                        .font(.satoshi(.title3, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
        }
    }
}

private struct HomeInlineExpandedPanel: View {
    let modal: HomeDashboardModal
    let summary: HomeEventSummary
    let closeAction: () -> Void

    @State private var focusedGuestLimit = 10
    @State private var selectedEndDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 23, minute: 59)) ?? Date()
    @State private var visibleEndMonth = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 1)) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.satoshi(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.satoshi(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(value)
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Text(description)
                        .font(.satoshi(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: closeAction) {
                    Image(systemName: "chevron.up")
                        .font(.satoshi(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            HomeDivider(appearance: .dark)
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1D2027"), Color(hex: "#171922")],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch modal {
        case .guests:
            GuestFocusedSelector(selectedLimit: $focusedGuestLimit)
        case .ended:
            EndingCalendarSelector(
                selectedDate: $selectedEndDate,
                visibleMonth: $visibleEndMonth
            )
        case .reveal:
            inlinePills(["During", "After", "12 hours after", "24 hours after"], selected: summary.reveal)
        case .filter:
            HStack(spacing: 12) {
                CompactFilterCard(title: "None", selected: summary.filter == "None", warm: false)
                CompactFilterCard(title: "Disposable Film", selected: summary.filter != "None", warm: true)
            }
        case .photos:
            inlinePills(["5", "10", "15", "20", "25"], selected: "\(summary.photosPerPerson)")
        case .details, .share:
            EmptyView()
        }
    }

    private var guestLimitFallback: Int {
        max(summary.guestLimit, 10)
    }

    private func inlinePills(_ options: [String], selected: String) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { option in
                SelectablePill(option, selected: option == selected)
            }
        }
    }

    private var icon: String {
        switch modal {
        case .guests: return "person.2"
        case .ended: return "calendar"
        case .reveal: return "hourglass"
        case .filter: return "photo"
        case .photos: return "camera"
        case .details, .share: return "chevron.right"
        }
    }

    private var title: String {
        switch modal {
        case .guests: return "Number of Guests"
        case .ended: return "Ending"
        case .reveal: return "Reveal Photos"
        case .filter: return "Filter"
        case .photos: return "Photos per Person"
        case .details, .share: return ""
        }
    }

    private var value: String {
        switch modal {
        case .guests: return "Up to \(focusedGuestLimit) participants"
        case .ended: return formattedEndDate
        case .reveal: return summary.reveal
        case .filter: return summary.filter
        case .photos: return "\(summary.photosPerPerson) photos"
        case .details, .share: return ""
        }
    }

    private var description: String {
        switch modal {
        case .guests:
            return "Upgrade at any time, even after publishing."
        case .ended:
            return "Choose when the camera locks for submissions."
        case .reveal:
            return "Set when photos become visible in the gallery."
        case .filter:
            return "Set the visual style for Tetamu photos."
        case .photos:
            return "Set how many photos each guest can capture."
        case .details, .share:
            return ""
        }
    }

    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • HH:mm"
        return "\(formatter.string(from: selectedEndDate)) GMT+8"
    }
}

private struct EndingCalendarSelector: View {
    @Binding var selectedDate: Date
    @Binding var visibleMonth: Date

    private let calendar = Calendar.current
    private let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.satoshi(size: 21, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E84FF"))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Text(monthTitle)
                    .font(.satoshi(size: 18, weight: .black))
                    .foregroundStyle(.white)

                Image(systemName: "chevron.right")
                    .font(.satoshi(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E84FF"))

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.satoshi(size: 21, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E84FF"))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 14) {
                HStack {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.satoshi(size: 12, weight: .black))
                            .foregroundStyle(.white.opacity(0.44))
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 13) {
                    ForEach(calendarDays, id: \.self) { date in
                        if let date {
                            dayButton(for: date)
                        } else {
                            Color.clear.frame(height: 34)
                        }
                    }
                }
            }

            HStack {
                Text("Time")
                    .font(.satoshi(size: 17, weight: .black))
                    .foregroundStyle(.white)

                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .tint(Color(hex: "#8E84FF"))
                    .frame(width: 110)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func dayButton(for date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let active = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let day = calendar.component(.day, from: date)

        return Button {
            selectDay(date)
        } label: {
            Text("\(day)")
                .font(.satoshi(size: 18, weight: .medium))
                .foregroundStyle(selected ? Color(hex: "#9A90FF") : (active ? .white : .white.opacity(0.16)))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Circle()
                        .fill(selected ? Color(hex: "#302C5C") : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonth)
    }

    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let daysRange = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlankCount = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlankCount)
        for day in daysRange {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }

        while !days.count.isMultiple(of: 7) {
            days.append(nil)
        }

        return days
    }

    private func selectDay(_ date: Date) {
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        selectedDate = calendar.date(from: components) ?? date
    }

    private func previousMonth() {
        visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
    }

    private func nextMonth() {
        visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
    }
}

private struct GuestFocusedSelector: View {
    @Binding var selectedLimit: Int

    private let guestLevels = [10, 25, 50, 75, 100, 150, 250]

    private var selectedIndex: Int {
        guestLevels.firstIndex(of: selectedLimit) ?? 0
    }

//    private var priceText: String {
//        selectedLimit == 10 ? "FREE" : "$\(max(selectedIndex, 1) * 5)"
//    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SegmentedSelectionBar(
                options: guestLevels,
                filledSegments: selectedIndex + 1,
                selectedValue: selectedLimit
            ) { level in
                selectedLimit = level
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Up to \(selectedLimit)")
                    .font(.satoshi(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }

//            if selectedLimit > 10 {
//                Text("Each increase unlocks a larger guest tier and requires payment before publishing.")
//                    .font(.satoshi(size: 13, weight: .medium))
//                    .foregroundStyle(.white.opacity(0.42))
//                    .fixedSize(horizontal: false, vertical: true)
//            }
        }
        .onAppear {
            if !guestLevels.contains(selectedLimit) {
                selectedLimit = 10
            }
        }
    }
}

private struct RevealPhotosSheet: View {
    let summary: HomeEventSummary
    @Binding var selectedReveal: String
    let backAction: () -> Void
    let dismissAction: () -> Void

    private let options = ["During", "After", "12 hours after", "24 hours after"]

    var body: some View {
        HomeExpandedSheet(
            icon: "hourglass",
            title: "Reveal Photos",
            value: selectedReveal,
            description: "Adjust the waiting period for when the photos are revealed in the gallery after the end date.",
            backAction: backAction,
            dismissAction: dismissAction
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedReveal = option
                    } label: {
                        SelectablePill(option, selected: selectedReveal == option)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EventEndSheet: View {
    let summary: HomeEventSummary
    let backAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HomeExpandedSheet(
            icon: "calendar",
            title: "Ended",
            value: summary.endedText,
            description: "Customize when the camera will lock and submissions will no longer be allowed.",
            backAction: backAction,
            dismissAction: dismissAction
        ) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    SelectablePill("When I decide", selected: false)
                    SelectablePill("Choose a date", selected: true)
                }

                HStack {
                    Text("October 2023")
                        .font(.satoshi(.title2, weight: .black))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.satoshi(.title3, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E84FF"))
                    Spacer()
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
                .font(.satoshi(.title2, weight: .bold))
                .foregroundStyle(Color(hex: "#8E84FF"))

                CalendarMockup()

                HStack {
                    Text("Time")
                        .font(.satoshi(.title2, weight: .black))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("2:00 AM")
                        .font(.satoshi(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
    }
}

private struct FilterSelectionSheet: View {
    let summary: HomeEventSummary
    @Binding var selectedFilter: String
    let backAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HomeExpandedSheet(
            icon: "photo",
            title: "Filter",
            value: selectedFilter,
            description: "Adjust the look and style of each photo taken at the event. You can adjust this even after the event.",
            backAction: backAction,
            dismissAction: dismissAction
        ) {
            HStack(spacing: 14) {
                Button {
                    selectedFilter = "None"
                } label: {
                    FilterCard(title: "None", selected: selectedFilter == "None", warm: false)
                }
                .buttonStyle(.plain)

                Button {
                    selectedFilter = "Disposable film"
                } label: {
                    FilterCard(title: "Disposable Film", selected: selectedFilter != "None", warm: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PhotosPerPersonSheet: View {
    let summary: HomeEventSummary
    @Binding var selectedPhotos: Int
    let backAction: () -> Void
    let dismissAction: () -> Void

    private let photoOptions = [5, 10, 15, 20, 25]

    var body: some View {
        HomeExpandedSheet(
            icon: "camera",
            title: "Photos per Person",
            value: "\(selectedPhotos) photos",
            description: "Set how many photos each guest can capture during the event.",
            backAction: backAction,
            dismissAction: dismissAction
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SegmentedSelectionBar(
                    options: photoOptions,
                    filledSegments: (photoOptions.firstIndex(of: selectedPhotos) ?? 0) + 1,
                    selectedValue: selectedPhotos
                ) { amount in
                    selectedPhotos = amount
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(photoOptions, id: \.self) { amount in
                        SelectableButtonPill(
                            title: "\(amount)",
                            subtitle: "photos",
                            selected: selectedPhotos == amount
                        ) {
                            selectedPhotos = amount
                        }
                    }
                }
            }
        }
    }
}

private struct ShareEventCardSheet: View {
    let summary: HomeEventSummary
    let qrCodeImage: UIImage?
    @Binding var selectedTemplate: QRShareTemplateStyle
    @Binding var selectedBackground: QRShareBackground
    @Binding var selectedQRColor: QRShareColor
    let dismissAction: () -> Void
    let shareAction: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: selectedBackground.colors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        HStack {
                            Button(action: dismissAction) {
                                Image(systemName: "chevron.down")
                                    .font(.satoshi(.title, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)

                            Spacer()
                            VStack(spacing: 2) {
                                Text(selectedTemplate.title)
                                    .font(.satoshi(.title3, weight: .black))
                                    .foregroundStyle(.white)
                                Text("Swipe to change style")
                                    .font(.satoshi(.headline, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "lightbulb")
                                .font(.satoshi(.title3, weight: .medium))
                                .foregroundStyle(Color(hex: "#FFD324"))
                                .frame(width: 58, height: 58)
                                .background(Color.white.opacity(0.13), in: Circle())
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, max(geo.safeAreaInsets.top, 10))

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 18)

                        Spacer(minLength: 8)

                        TabView(selection: $selectedTemplate) {
                            ForEach(QRShareTemplateStyle.allCases) { template in
                                QRShareTemplateCard(
                                    summary: summary,
                                    qrCodeImage: qrCodeImage,
                                    template: template,
                                    background: selectedBackground,
                                    qrColor: selectedQRColor,
                                    displayMode: .preview
                                )
                                .padding(.horizontal, 38)
                                .tag(template)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 430)

                        HStack(spacing: 7) {
                            ForEach(QRShareTemplateStyle.allCases) { template in
                                Circle()
                                    .fill(selectedTemplate == template ? Color.white : Color.white.opacity(0.28))
                                    .frame(width: selectedTemplate == template ? 8 : 6, height: selectedTemplate == template ? 8 : 6)
                                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedTemplate)
                            }
                        }
                        .padding(.top, 4)

                        Color.clear
                            .frame(height: 180)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Menu {
                                ForEach(QRShareBackground.allCases) { background in
                                    Button(background.title) {
                                        selectedBackground = background
                                    }
                                }
                            } label: {
                                ShareOptionButton(icon: "rectangle.portrait", title: selectedBackground.title)
                            }

                            Menu {
                                ForEach(QRShareColor.allCases) { color in
                                    Button(color.title) {
                                        selectedQRColor = color
                                    }
                                }
                            } label: {
                                ShareOptionButton(icon: "circle.fill", title: selectedQRColor.title)
                            }
                        }
                        .padding(.horizontal, 18)

                        Button(action: shareAction) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.satoshi(.title3, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                    }
                    .padding(.top, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.12), Color.black.opacity(0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
    }
}

private struct QRShareTemplateCard: View {
    let summary: HomeEventSummary
    let qrCodeImage: UIImage?
    let template: QRShareTemplateStyle
    let background: QRShareBackground
    let qrColor: QRShareColor
    let displayMode: QRShareDisplayMode

    private var isExport: Bool {
        displayMode == .export
    }

    var body: some View {
        ZStack {
            cardBackground
            decorativeLayer

            VStack(spacing: isExport ? 42 : 18) {
                header
                qrBlock
                copyBlock
                Spacer(minLength: isExport ? 22 : 10)
                footer
            }
            .padding(isExport ? 78 : 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: isExport ? 0 : 26))
        .overlay {
            if !isExport {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(isExport ? 0 : 0.28), radius: 28, y: 18)
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch template {
        case .plain:
            Color.white
        case .sparkles:
            LinearGradient(colors: [Color.white, Color(hex: "#FFF7EA")], startPoint: .top, endPoint: .bottom)
        case .midnight:
            LinearGradient(colors: [Color(hex: "#11142A"), Color(hex: "#05070D")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .garden:
            LinearGradient(colors: [Color(hex: "#F7FFE9"), Color(hex: "#E4F0D0")], startPoint: .top, endPoint: .bottom)
        case .ticket:
            LinearGradient(colors: [Color(hex: "#FFF5DF"), Color(hex: "#E9CF9E")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    @ViewBuilder
    private var decorativeLayer: some View {
        switch template {
        case .plain:
            EmptyView()
        case .sparkles:
            SparklePattern()
                .foregroundStyle(Color(hex: "#C9A46E").opacity(0.72))
                .padding(isExport ? 80 : 24)
        case .midnight:
            ZStack {
                Circle()
                    .fill(Color(hex: "#554DE8").opacity(0.34))
                    .blur(radius: isExport ? 90 : 36)
                    .offset(x: isExport ? -280 : -95, y: isExport ? -430 : -138)
                Circle()
                    .fill(Color(hex: "#E8D7FF").opacity(0.22))
                    .blur(radius: isExport ? 110 : 46)
                    .offset(x: isExport ? 330 : 110, y: isExport ? 430 : 142)
            }
        case .garden:
            GardenPattern()
                .foregroundStyle(Color(hex: "#73946D").opacity(0.36))
                .padding(isExport ? 72 : 24)
        case .ticket:
            TicketPerforation()
                .stroke(Color(hex: "#8D6B38").opacity(0.35), style: StrokeStyle(lineWidth: isExport ? 8 : 2, dash: [10, 10]))
                .padding(.vertical, isExport ? 90 : 30)
        }
    }

    private var header: some View {
        VStack(spacing: isExport ? 14 : 5) {
            Text(summary.eventName.uppercased())
                .font(.satoshi(size: isExport ? 92 : 30, weight: .regular))
                .tracking(isExport ? 10 : 3)
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground)
                .minimumScaleFactor(0.58)
                .lineLimit(2)

            Text(template.subtitle)
                .font(.satoshi(size: isExport ? 36 : 13, weight: .medium))
                .foregroundStyle(foreground.opacity(0.55))
        }
    }

    private var qrBlock: some View {
        qrContent
            .frame(width: isExport ? 430 : 142, height: isExport ? 430 : 142)
            .padding(isExport ? 32 : 12)
            .background(qrPlate, in: RoundedRectangle(cornerRadius: isExport ? 42 : 15))
            .overlay(
                RoundedRectangle(cornerRadius: isExport ? 42 : 15)
                    .stroke(foreground.opacity(0.1), lineWidth: isExport ? 4 : 1)
            )
    }

    private var copyBlock: some View {
        VStack(spacing: isExport ? 16 : 6) {
            Text("We want your perspective from the night.")
                .font(.satoshi(size: isExport ? 36 : 13, weight: .bold))
                .foregroundStyle(foreground.opacity(0.82))
            Text("Scan the QR code and share photos. No app download required.")
                .font(.satoshi(size: isExport ? 31 : 11, weight: .medium))
                .foregroundStyle(foreground.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: isExport ? 14 : 5) {
                Image("TetamuIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isExport ? 34 : 13, height: isExport ? 34 : 13)
                    .clipShape(RoundedRectangle(cornerRadius: isExport ? 7 : 3))
                Text("tetamu")
                    .font(.satoshi(size: isExport ? 38 : 15, weight: .black))
            }
            Spacer()
            Text("February 10, 2024")
                .font(.satoshi(size: isExport ? 32 : 12, weight: .italic))
        }
        .foregroundStyle(foreground)
    }

    @ViewBuilder
    private var qrContent: some View {
        if let qrCodeImage {
            Image(uiImage: qrCodeImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(qrColor.color)
                .padding(isExport ? 26 : 8)
        }
    }

    private var foreground: Color {
        template == .midnight ? .white : Color(hex: "#17140F")
    }

    private var qrPlate: Color {
        qrColor == .ivory ? Color(hex: "#151722") : .white
    }
}

private struct SparklePattern: View {
    var body: some View {
        GeometryReader { proxy in
            let points: [(CGFloat, CGFloat, CGFloat)] = [
                (0.18, 0.14, 0.8), (0.72, 0.12, 0.55), (0.86, 0.28, 0.75),
                (0.22, 0.36, 0.48), (0.66, 0.42, 0.62), (0.14, 0.64, 0.72),
                (0.78, 0.68, 0.46), (0.32, 0.82, 0.62), (0.58, 0.9, 0.52)
            ]

            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                SparkleShape()
                    .frame(width: 18 * point.2, height: 18 * point.2)
                    .position(x: proxy.size.width * point.0, y: proxy.size.height * point.1)
            }
        }
    }
}

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.12, y: center.y - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        path.addLine(to: CGPoint(x: center.x + rect.width * 0.12, y: center.y + rect.height * 0.12))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.12, y: center.y + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX, y: center.y))
        path.addLine(to: CGPoint(x: center.x - rect.width * 0.12, y: center.y - rect.height * 0.12))
        path.closeSubpath()
        return path
    }
}

private struct GardenPattern: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<9, id: \.self) { index in
                let x = CGFloat((index * 37) % 91) / 100
                let y = CGFloat((index * 23 + 12) % 89) / 100
                Image(systemName: index.isMultiple(of: 2) ? "leaf.fill" : "camera.macro")
                    .font(.system(size: 22 + CGFloat(index % 3) * 6))
                    .rotationEffect(.degrees(Double(index * 31)))
                    .position(x: proxy.size.width * x, y: proxy.size.height * y)
            }
        }
    }
}

private struct TicketPerforation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct HomeExpandedSheet<Content: View>: View {
    let icon: String
    let title: String
    let value: String
    let description: String
    let backAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        icon: String,
        title: String,
        value: String,
        description: String,
        backAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.description = description
        self.backAction = backAction
        self.dismissAction = dismissAction
        self.content = content()
    }

    var body: some View {
        HomeChildOverlayContainer {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    if let backAction {
                        Button(action: backAction) {
                            Image(systemName: "chevron.left")
                                .font(.satoshi(.headline, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: icon)
                            .font(.satoshi(.title3, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .frame(width: 42, height: 42)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.satoshi(.headline, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                        Text(value)
                            .font(.satoshi(.title3, weight: .bold))
                            .foregroundStyle(.white)
                        Text(description)
                            .font(.satoshi(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }

                    Spacer()

                    if let dismissAction {
                        Button(action: dismissAction) {
                            Image(systemName: "chevron.down")
                                .font(.satoshi(.title3, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HomeDivider()
                content
            }
        }
    }
}

private struct HomeChildOverlayContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: HomeSheetHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .frame(maxWidth: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1B1D26"), Color(hex: "#15161E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 16)
        .padding(.horizontal, 0)
    }
}

private enum HomeCoverEditorTool: String, CaseIterable, Identifiable {
    case photo
    case title
    case subtitle
    case button

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "Add Photo"
        case .title: return "Title"
        case .subtitle: return "Subtitle"
        case .button: return "Button"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo"
        case .title: return "textformat"
        case .subtitle: return "calendar"
        case .button: return "arrow.right"
        }
    }
}

private struct HomeCoverEditorScreen: View {
    @Binding var draft: HomeCoverDraft
    let namespace: Namespace.ID
    let doneAction: () -> Void

    @State private var activeTool: HomeCoverEditorTool = .photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var textFieldFocused: Bool
    private let editorFieldID = "home-cover-editor-field"

    var body: some View {
        GeometryReader { proxy in
            let editorSafeBottom = max(proxy.safeAreaInsets.bottom, 12)
            let editorReserved: CGFloat = 84 + 6 + 34 + 88 + 58 + editorSafeBottom + 60
            let phoneHeight = min(max(proxy.size.height - editorReserved, 200), 360)
            let phoneWidth = min(proxy.size.width * 0.72, 260)

            ZStack {
                editorBackground(width: proxy.size.width, height: proxy.size.height)

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            header
                                .padding(.top, 18)

                            coverCarousel(width: phoneWidth, height: phoneHeight)
                                .frame(height: phoneHeight)
                                .padding(.top, 6)

                            editorField
                                .frame(minHeight: 34, alignment: .center)
                                .padding(.horizontal, 22)
                                .id(editorFieldID)

                            toolBar
                                .frame(height: 88)
                                .padding(.horizontal, 22)

                            Color.clear
                                .frame(height: 10)
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Button(action: doneAction) {
                            Text("Done")
                                .font(.satoshi(size: 18, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                        .padding(.bottom, editorSafeBottom)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.2), Color.black.opacity(0.36)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                    }
                    .onChange(of: textFieldFocused) { _, focused in
                        guard focused else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            scrollProxy.scrollTo(editorFieldID, anchor: .center)
                        }
                    }
                    .onChange(of: activeTool) { _, tool in
                        guard tool != .photo else { return }
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                scrollProxy.scrollTo(editorFieldID, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .matchedGeometryEffect(id: "cover-editor-card", in: namespace)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .onChange(of: selectedPhotoItem) { _, item in
            loadSelectedPhoto(item)
        }
    }

    private func editorBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let image = draft.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .blur(radius: 30)
                    .opacity(0.5)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    Color(hex: "#AFA78F").opacity(0.92),
                    Color(hex: "#755846").opacity(0.88),
                    Color(hex: "#272229").opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Color.black.opacity(0.08)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(draft.style.title)
                .font(.satoshi(size: 25, weight: draft.style == .polaroid ? .italic : .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)

            Text("Edit your cover screen")
                .font(.satoshi(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func coverCarousel(width: CGFloat, height: CGFloat) -> some View {
        TabView(selection: $draft.style) {
            ForEach(HomeCoverStyle.allCases) { style in
                Phone3DSceneView(
                    eventName: draft.title,
                    coverDraft: styledDraft(style),
                    angle: 180,
                    warmReflection: false
                )
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity)
                .tag(style)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func styledDraft(_ style: HomeCoverStyle) -> HomeCoverDraft {
        var copy = draft
        copy.style = style
        return copy
    }

    @ViewBuilder
    private var editorField: some View {
        switch activeTool {
        case .photo:
            Text(draft.image == nil ? "Choose a cover photo for the mockup." : "Cover photo selected. Tap Add Photo to change it.")
                .font(.satoshi(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .title:
            CoverEditorTextField(title: "Title", text: $draft.title)
                .focused($textFieldFocused)
        case .subtitle:
            CoverEditorTextField(title: "Subtitle", text: $draft.subtitle)
                .focused($textFieldFocused)
        case .button:
            CoverEditorTextField(title: "Button", text: $draft.buttonTitle)
                .focused($textFieldFocused)
        }
    }

    private var toolBar: some View {
        HStack(spacing: 10) {
            ForEach(HomeCoverEditorTool.allCases) { tool in
                if tool == .photo {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        toolButton(for: tool)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        activeTool = .photo
                    })
                } else {
                    Button {
                        activeTool = tool
                        textFieldFocused = true
                    } label: {
                        toolButton(for: tool)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toolButton(for tool: HomeCoverEditorTool) -> some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tool.icon)
                    .font(.satoshi(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(activeTool == tool ? 0.96 : 0.58))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white.opacity(activeTool == tool ? 0.16 : 0.09), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(activeTool == tool ? 0.16 : 0.05), lineWidth: 1)
                    )

                if tool == .photo {
                    Image(systemName: draft.image == nil ? "plus" : "checkmark")
                        .font(.satoshi(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black, in: Circle())
                        .offset(x: 8, y: -8)
                }
            }

            Text(tool.title)
                .font(.satoshi(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    draft.image = image.coverEditorPreparedImage()
                    activeTool = .photo
                }
            }
        }
    }
}

private struct CoverEditorTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.satoshi(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))

            TextField(title, text: $text)
                .font(.satoshi(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

private enum HomeCoverTextureRenderer {
    private static let textureSize = CGSize(width: 430, height: 920)
    private static let screenCornerRadius: CGFloat = 46

    static func image(for draft: HomeCoverDraft) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: textureSize, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = false
            return format
        }())

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: textureSize)
            UIColor.clear.setFill()
            UIRectFill(rect)

            context.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: screenCornerRadius).addClip()

            switch draft.style {
            case .polaroid:
                drawPolaroid(draft, in: rect, context: context.cgContext)
            case .starter:
                drawStarter(draft, in: rect, context: context.cgContext)
            case .minimal:
                drawMinimal(draft, in: rect, context: context.cgContext)
            }

            context.cgContext.restoreGState()
        }
    }

    private static func drawPolaroid(_ draft: HomeCoverDraft, in rect: CGRect, context: CGContext) {
        drawLinearGradient(
            colors: [
                UIColor(red: 0.58, green: 0.45, blue: 0.86, alpha: 1),
                UIColor(red: 0.95, green: 0.68, blue: 0.64, alpha: 1)
            ],
            in: rect,
            context: context
        )

        let cardRect = CGRect(x: 68, y: 286, width: 294, height: 278)
        context.saveGState()
        context.translateBy(x: cardRect.midX, y: cardRect.midY)
        context.rotate(by: -3.2 * .pi / 180)
        let localCard = CGRect(x: -cardRect.width / 2, y: -cardRect.height / 2, width: cardRect.width, height: cardRect.height)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: localCard, cornerRadius: 5).fill()

        let photoRect = CGRect(x: localCard.minX + 20, y: localCard.minY + 20, width: localCard.width - 40, height: 178)
        drawCoverPhoto(draft.image, in: photoRect, cornerRadius: 3)
        drawText(
            draft.subtitle,
            in: CGRect(x: photoRect.maxX - 118, y: photoRect.maxY - 29, width: 106, height: 24),
            font: .satoshi(size: 18, weight: .bold),
            color: UIColor(red: 0.9, green: 0.82, blue: 0.25, alpha: 1),
            alignment: .right
        )
        drawText(
            draft.title,
            in: CGRect(x: localCard.minX + 24, y: photoRect.maxY + 18, width: localCard.width - 48, height: 42),
            font: .satoshi(size: 28, weight: .italic),
            color: UIColor(red: 0.08, green: 0.07, blue: 0.09, alpha: 1),
            alignment: .center
        )
        context.restoreGState()

        drawCoverButton(draft.buttonTitle, rect: CGRect(x: 36, y: 796, width: 358, height: 58), dark: true)
        drawHomeIndicator(in: rect)
    }

    private static func drawStarter(_ draft: HomeCoverDraft, in rect: CGRect, context: CGContext) {
        UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1).setFill()
        UIRectFill(rect)

        drawText(
            draft.title,
            in: CGRect(x: 64, y: 418, width: rect.width - 128, height: 116),
            font: .satoshi(size: 44, weight: .black),
            color: .white,
            alignment: .center
        )
        UIColor.white.withAlphaComponent(0.12).setFill()
        UIRectFill(CGRect(x: 142, y: 542, width: 146, height: 1))
        drawText(
            draft.subtitle,
            in: CGRect(x: 84, y: 564, width: rect.width - 168, height: 34),
            font: .satoshi(size: 26, weight: .medium),
            color: UIColor.white.withAlphaComponent(0.58),
            alignment: .center
        )

        drawCoverButton(draft.buttonTitle, rect: CGRect(x: 36, y: 796, width: 358, height: 58), dark: false)
        drawHomeIndicator(in: rect)
    }

    private static func drawMinimal(_ draft: HomeCoverDraft, in rect: CGRect, context: CGContext) {
        UIColor.white.setFill()
        UIRectFill(rect)

        let photoRect = CGRect(x: 34, y: 72, width: rect.width - 68, height: 560)
        drawCoverPhoto(draft.image, in: photoRect, cornerRadius: 22)
        drawText(
            draft.title,
            in: CGRect(x: 44, y: 656, width: rect.width - 88, height: 82),
            font: .satoshi(size: 38, weight: .black),
            color: .black,
            alignment: .center
        )
        drawText(
            draft.subtitle,
            in: CGRect(x: 44, y: 738, width: rect.width - 88, height: 30),
            font: .satoshi(size: 20, weight: .bold),
            color: UIColor.black.withAlphaComponent(0.72),
            alignment: .center
        )

        drawCoverButton(draft.buttonTitle, rect: CGRect(x: 36, y: 796, width: 358, height: 58), dark: false)
        drawHomeIndicator(in: rect)
    }

    private static func drawCoverPhoto(_ image: UIImage?, in rect: CGRect, cornerRadius: CGFloat = 0) {
        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        guard let image else {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.saveGState()
            clipPath.addClip()
            drawLinearGradient(
                colors: [
                    UIColor(red: 0.88, green: 0.82, blue: 0.62, alpha: 1),
                    UIColor(red: 0.48, green: 0.39, blue: 0.36, alpha: 1),
                    UIColor(red: 0.2, green: 0.16, blue: 0.18, alpha: 1)
                ],
                in: rect,
                context: context
            )
            context.restoreGState()
            drawText(
                "photo",
                in: rect.insetBy(dx: 20, dy: 68),
                font: .satoshi(size: 18, weight: .medium),
                color: UIColor.white.withAlphaComponent(0.34),
                alignment: .center
            )
            return
        }

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        clipPath.addClip()
        image.drawAspectFill(in: rect)
        context.restoreGState()
    }

    private static func drawCoverButton(_ text: String, rect: CGRect, dark: Bool) {
        let fill = dark ? UIColor(red: 0.24, green: 0.18, blue: 0.25, alpha: 1) : UIColor.white
        let foreground = dark ? UIColor.white : UIColor.black
        fill.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()

        let title = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Take Photos" : text
        drawText(
            "\(title)  ->",
            in: rect.insetBy(dx: 18, dy: 16),
            font: .satoshi(size: 19, weight: .black),
            color: foreground,
            alignment: .center
        )
    }

    private static func drawHomeIndicator(in rect: CGRect) {
        UIColor.black.setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.midX - 66, y: 888, width: 132, height: 5), cornerRadius: 2.5).fill()
    }

    private static func drawLinearGradient(colors: [UIColor], in rect: CGRect, context: CGContext?) {
        guard let context,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map(\.cgColor) as CFArray,
                locations: nil
              ) else { return }

        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail

        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}

private extension UIImage {
    func coverEditorPreparedImage() -> UIImage {
        let targetSize = CGSize(width: 860, height: 1120)
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            return format
        }())

        return renderer.image { _ in
            drawAspectFill(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func drawAspectFill(in rect: CGRect) {
        let imageSize = size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        draw(in: drawRect)
    }
}

private struct HomeDetailsCoverSection: View {
    let summary: HomeEventSummary
    let coverDraft: HomeCoverDraft
    let namespace: Namespace.ID
    let editAction: () -> Void
    @Binding var photoSelection: PhotosPickerItem?

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: "#887B6E"), Color(hex: "#5A5858")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Button(action: editAction) {
                        HStack(spacing: 7) {
                            Text("Cover")
                                .font(.satoshi(size: 16, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.satoshi(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .zIndex(1)

                ZStack {
                    Phone3DSceneView(
                        eventName: summary.eventName,
                        coverDraft: coverDraft,
                        angle: 180,
                        warmReflection: false
                    )
                    .frame(width: 218, height: 258)
                    .offset(x: 6)

                    HStack {
                        Spacer()

                        VStack(spacing: 18) {
                            detailCoverTool(icon: "pencil", title: "Edit", action: editAction)
                            PhotosPicker(selection: $photoSelection, matching: .images) {
                                detailCoverButtonLabel(icon: "photo", title: "Photo")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 12)
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 268)
        .matchedGeometryEffect(id: "cover-editor-card", in: namespace)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func detailCoverTool(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            detailCoverButtonLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func detailCoverButtonLabel(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.satoshi(size: 21, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 46, height: 46)
                .background(Color.black.opacity(0.22), in: Circle())

            Text(title)
                .font(.satoshi(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))
        }
        .contentShape(Rectangle())
    }
}

private struct HomeSheetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: "#F2F2F2")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, max(proxy.safeAreaInsets.top - 8, 6))
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .background(
                    GeometryReader { contentProxy in
                        Color.clear.preference(key: HomeSheetHeightPreferenceKey.self, value: contentProxy.size.height)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

private struct SegmentedSelectionBar: View {
    let options: [Int]
    let filledSegments: Int
    let selectedValue: Int
    let selectAction: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, value in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectAction(value)
                    }
                } label: {
                    Rectangle()
                        .fill(index < filledSegments ? Color.black : Color.white.opacity(0.12))
                        .frame(height: 58)
                        .clipShape(SegmentedBarSegmentShape(
                            isFirst: index == 0,
                            isLast: index == options.count - 1,
                            radius: 12
                        ))
                        .overlay(alignment: .trailing) {
                            if index < options.count - 1 {
                                Rectangle()
                                    .fill(Color(hex: "#181A22"))
                                    .frame(width: 2)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if selectedValue == value {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                                    .padding(.bottom, 8)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SegmentedBarSegmentShape: Shape {
    let isFirst: Bool
    let isLast: Bool
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let topLeft = isFirst ? radius : 0
        let bottomLeft = isFirst ? radius : 0
        let topRight = isLast ? radius : 0
        let bottomRight = isLast ? radius : 0

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                radius: topRight,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                radius: bottomRight,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                radius: bottomLeft,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                radius: topLeft,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }
}

private struct HomeSettingRow: View {
    enum Appearance {
        case light
        case dark
    }

    let icon: String
    let title: String
    let value: String
    let expanded: Bool
    let appearance: Appearance
    let action: () -> Void

    init(
        icon: String,
        title: String,
        value: String,
        expanded: Bool = false,
        appearance: Appearance = .light,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.expanded = expanded
        self.appearance = appearance
        self.action = action
    }

    private var iconColor: Color {
        switch appearance {
        case .light: .black.opacity(0.5)
        case .dark: .white.opacity(0.6)
        }
    }

    private var titleColor: Color {
        switch appearance {
        case .light: .black.opacity(0.5)
        case .dark: .white.opacity(0.62)
        }
    }

    private var valueColor: Color {
        switch appearance {
        case .light: .black
        case .dark: .white.opacity(0.92)
        }
    }

    private var chevronColor: Color {
        switch appearance {
        case .light: .black.opacity(0.3)
        case .dark: .white.opacity(0.4)
        }
    }

    private var expandedBackgroundColor: Color {
        switch appearance {
        case .light: .black.opacity(0.05)
        case .dark: .white.opacity(0.05)
        }
    }

    private var expandedBorderColor: Color {
        switch appearance {
        case .light: .black.opacity(0.08)
        case .dark: .white.opacity(0.08)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.satoshi(size: 19, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.satoshi(size: 14, weight: .medium))
                        .foregroundStyle(titleColor)
                    Text(value)
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.satoshi(size: 21, weight: .medium))
                    .foregroundStyle(chevronColor)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.horizontal, expanded ? 12 : 0)
            .frame(height: expanded ? 76 : 58)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(expanded ? expandedBackgroundColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(expanded ? expandedBorderColor : Color.clear, lineWidth: 1)
            )
            .scaleEffect(expanded ? 1.015 : 1, anchor: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: expanded)
    }
}

private struct HomeDivider: View {
    enum Appearance {
        case light
        case dark
    }

    let appearance: Appearance

    init(appearance: Appearance = .light) {
        self.appearance = appearance
    }

    var body: some View {
        Rectangle()
            .fill(appearance == .light ? .black.opacity(0.08) : .white.opacity(0.08))
            .frame(height: 1)
    }
}

private struct SelectablePill: View {
    let title: String
    let selected: Bool

    init(_ title: String, selected: Bool) {
        self.title = title
        self.selected = selected
    }

    var body: some View {
        Text(title)
            .font(.satoshi(.headline, weight: .black))
            .foregroundStyle(selected ? Color(hex: "#9A90FF") : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(selected ? Color(hex: "#282154") : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color(hex: "#554DE8").opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

private struct SelectableButtonPill: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.satoshi(.headline, weight: .black))
                Text(subtitle)
                    .font(.satoshi(.caption2, weight: .medium))
                    .opacity(0.72)
            }
            .foregroundStyle(selected ? Color(hex: "#A79EFF") : .white.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(selected ? Color(hex: "#282154") : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color(hex: "#554DE8").opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarMockup: View {
    private let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let days = Array(1...31)

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.satoshi(.caption, weight: .black))
                        .foregroundStyle(.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 19) {
                ForEach(0..<6, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(days, id: \.self) { day in
                    Text("\(day)")
                        .font(.satoshi(.title2, weight: .medium))
                        .foregroundStyle(day < 23 ? .white.opacity(0.14) : .white)
                        .frame(width: 45, height: 45)
                        .background(day == 23 ? Color(hex: "#302C5C") : Color.clear, in: Circle())
                        .foregroundStyle(day == 23 ? Color(hex: "#9A90FF") : .white)
                }
            }
        }
    }
}

private struct FilterCard: View {
    let title: String
    let selected: Bool
    let warm: Bool

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    LinearGradient(
                        colors: warm ? [Color(hex: "#C48478"), Color(hex: "#2E246E")] : [Color(hex: "#6F5A58"), Color(hex: "#31343B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 46, height: 46)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 92, height: 78)
                    }
                    .opacity(0.78)
                }
                .frame(height: 150)

            Text(title)
                .font(.satoshi(.title3, weight: .black))
                .foregroundStyle(selected ? Color(hex: "#9A90FF") : .white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(selected ? Color(hex: "#282154") : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color(hex: "#554DE8").opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CompactFilterCard: View {
    let title: String
    let selected: Bool
    let warm: Bool

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    LinearGradient(
                        colors: warm ? [Color(hex: "#C48478"), Color(hex: "#2E246E")] : [Color(hex: "#6F5A58"), Color(hex: "#31343B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.78))
                        .frame(width: 58, height: 72)
                }
                .frame(height: 104)

            Text(title)
                .font(.satoshi(size: 14, weight: .black))
                .foregroundStyle(selected ? Color(hex: "#9A90FF") : .white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(selected ? Color(hex: "#282154") : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color(hex: "#554DE8").opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SharePreviewCard: View {
    let summary: HomeEventSummary
    let qrCodeImage: UIImage?
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 10 : 18) {
            if compact {
                Spacer()
            } else {
                VStack(spacing: 2) {
                    Text(summary.eventName)
                        .font(.satoshi(size: 25))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                    Text("Scan and share photos")
                        .font(.satoshi(.caption, weight: .medium))
                        .foregroundStyle(.black.opacity(0.42))
                }
                .padding(.top, 26)
            }

            qrContent
                .frame(width: compact ? 76 : 134, height: compact ? 76 : 134)
                .padding(8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: compact ? 8 : 13))

            if !compact {
                Text("We want your perspective from the night -\nscan the QR code and share photos!")
                    .font(.satoshi(.caption2, weight: .medium))
                    .foregroundStyle(.black.opacity(0.62))
                    .multilineTextAlignment(.center)

                Spacer()

                HStack {
                    Text("tetamu")
                        .font(.satoshi(.caption, weight: .black))
                    Spacer()
                    Text("February 10, 2024")
                        .font(.satoshi(.caption, weight: .medium))
                        .italic()
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder
    private var qrContent: some View {
        if let qrCodeImage {
            Image(uiImage: qrCodeImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
                .padding(8)
        }
    }
}

private struct ShareOptionButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.satoshi(.headline, weight: .black))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
    }
}

enum HomeDashboardTab {
    case create
    case cameras
}

private struct POVDashboardLayout: View {
    let eventName: String
    let coverDraft: HomeCoverDraft
    let subtitle: String
    let statusText: String
    @Binding var selectedTab: HomeDashboardTab
    @Binding var phoneShowingBack: Bool
    let scheduleAction: () -> Void
    let instantAction: () -> Void
    let galleryAction: () -> Void
    let cameraAction: () -> Void
    let editAction: () -> Void
    let qrAction: () -> Void
    let shareAction: () -> Void
    let settingsTabAction: () -> Void
    var myCreatedEvents: [[String: Any]] = []
    var openCameraForEvent: (([String: Any]) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var phoneRestingAngle: Double = 0
    @State private var heroPageIndex: Int = 0

    private var hasCreatedEvents: Bool {
        !myCreatedEvents.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top, 18)
            let safeBottom = proxy.safeAreaInsets.bottom
            let bottomReserve = max(safeBottom, 12) + 68 + 12
            let heroHeight = max(CGFloat(320), proxy.size.height - topInset - 40 - bottomReserve - 156)
            let phoneHeight = min(CGFloat(320), max(CGFloat(100), heroHeight - 260))
            let dashboardBackground = selectedTab == .cameras ? Color.white : Color(hex: "#11120D")

            VStack(spacing: 12) {
                Group {
                    switch selectedTab {
                    case .create:
                        createDashboardContent(heroHeight: heroHeight, phoneHeight: phoneHeight)
                    case .cameras:
                        CamerasTabPage(
                            events: myCreatedEvents,
                            openCameraForEvent: openCameraForEvent ?? { _ in cameraAction() },
                            joinAction: galleryAction
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, topInset + 40)
            .padding(.bottom, bottomReserve)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(dashboardBackground)
            .overlay(alignment: .bottomTrailing) {
                if selectedTab == .cameras {
                    Button(action: scheduleAction) {
                        Image(systemName: "plus")
                            .font(.satoshi(size: 33, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Color.black, in: Circle())
                            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 22)
                    .padding(.bottom, max(safeBottom, 12) + 78)
                }
            }
            .overlay(alignment: .bottom) {
                bottomBar(safeBottom: safeBottom, showsTopBorder: selectedTab != .cameras)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .background(selectedTab == .cameras ? Color.white : Color(hex: "#11120D"))
        .ignoresSafeArea(edges: [.top, .bottom])
        .onAppear {
            phoneRestingAngle = 180
            phoneShowingBack = true
            dragOffset = 0
        }
    }

    private func createDashboardContent(heroHeight: CGFloat, phoneHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            if myCreatedEvents.count > 1 {
                VStack(spacing: 8) {
                    TabView(selection: $heroPageIndex) {
                        ForEach(Array(myCreatedEvents.enumerated()), id: \.offset) { i, dict in
                            EventHeroCard(
                                dict: dict,
                                activeCoverDraft: coverDraft,
                                isActive: i == 0,
                                phoneHeight: phoneHeight,
                                phoneShowingBack: $phoneShowingBack,
                                dragOffset: $dragOffset,
                                restingAngle: $phoneRestingAngle,
                                editAction: editAction,
                                cameraAction: cameraAction,
                                shareAction: shareAction,
                                qrAction: qrAction
                            )
                            .tag(i)
                            .padding(.horizontal, 16)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: heroHeight)

                    HStack(spacing: 6) {
                        ForEach(0..<myCreatedEvents.count, id: \.self) { i in
                            Circle()
                                .fill(i == heroPageIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == heroPageIndex ? 8 : 6, height: i == heroPageIndex ? 8 : 6)
                                .animation(.spring(response: 0.3), value: heroPageIndex)
                        }
                    }
                }
            } else {
                homeHeroCard(phoneHeight: phoneHeight, isOnboarding: !hasCreatedEvents)
                    .frame(height: heroHeight)
            }

            if hasCreatedEvents {
                Button(action: scheduleAction) {
                    actionRow(
                        icon: "plus.square",
                        title: "Create an event",
                        subtitle: "Set up your Tetamu event and share it with guests"
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func homeHeroCard(phoneHeight: CGFloat, isOnboarding: Bool = false) -> some View {
        let heroGradient = LinearGradient(
            colors: [Color(hex: "#8C8073"), Color(hex: "#69635F"), Color(hex: "#555152")],
            startPoint: .top,
            endPoint: .bottom
        )

        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(isOnboarding ? "WELCOME TO TETAMU" : "HOSTING")
                    .font(.satoshi(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.3)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))

                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            ZStack {
                Text(isOnboarding ? "Create one event.\nCollect every memory." : eventName)
                    .font(.satoshi(size: isOnboarding ? 32 : 29, weight: .italic))
                    .foregroundStyle(.white)
                    .lineLimit(isOnboarding ? 2 : 1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if !isOnboarding {
                    HStack {
                        Spacer()

                        Button(action: editAction) {
                            Image(systemName: "pencil")
                                .font(.satoshi(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 52, height: 38)
                                .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 22)

            Text(isOnboarding ? "Start with a cover, share one QR or link, and let guests fill the gallery together." : subtitle)
                .font(.satoshi(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            SwipeablePhoneMockup(
                eventName: isOnboarding ? "Your Event" : eventName,
                coverDraft: coverDraft,
                showingBack: $phoneShowingBack,
                dragOffset: $dragOffset,
                restingAngle: $phoneRestingAngle
            )
            .frame(height: phoneHeight)
            .padding(.top, 14)

            Group {
                if isOnboarding {
                    HStack(spacing: 10) {
                        onboardingPill(icon: "photo.on.rectangle", text: "Design the cover")
                        onboardingPill(icon: "qrcode", text: "Invite your guests")
                        onboardingPill(icon: "camera", text: "Collect the moments")
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 22)

                    Button(action: scheduleAction) {
                        HStack(spacing: 8) {
                            Text("Create an event")
                            Image(systemName: "arrow.right")
                        }
                        .font(.satoshi(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#F0B35E"), Color(hex: "#D86B7D"), Color(hex: "#7A5AF8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 15)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.horizontal, 22)
                } else {
                    Text(statusText)
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 20)

                    HStack(spacing: 14) {
                        dashboardToolButton(systemName: "camera", action: cameraAction)
                        dashboardToolButton(systemName: "square.and.arrow.up", action: shareAction)
                        dashboardToolButton(systemName: "qrcode", action: qrAction)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 22)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 34))
        .overlay(
            RoundedRectangle(cornerRadius: 34)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func onboardingPill(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.satoshi(size: 12, weight: .bold))
            Text(text)
                .font(.satoshi(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(.white.opacity(0.84))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color.white.opacity(0.09), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func dashboardToolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.satoshi(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.satoshi(size: 26, weight: .bold))
                .frame(width: 30)
                .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.satoshi(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                Text(subtitle)
                    .font(.satoshi(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.satoshi(size: 19, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.84))
        }
        .padding(.horizontal, 20)
        .frame(height: 66)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F0B35E"), Color(hex: "#D86B7D"), Color(hex: "#7A5AF8")],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    private func bottomBar(safeBottom: CGFloat, showsTopBorder: Bool = true) -> some View {
        HStack(spacing: 0) {
            bottomTabButton("plus.square", tab: .create)
            bottomTabButton("camera", tab: .cameras)
            externalBottomTabButton("gearshape", action: settingsTabAction)
        }
        .frame(height: 68)
        .padding(.horizontal, 34)
        .padding(.bottom, max(safeBottom, 12))
        .background(Color.white)
        .overlay(alignment: .top) {
            if showsTopBorder {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    private func bottomTabButton(_ systemName: String, tab: HomeDashboardTab, action: (() -> Void)? = nil) -> some View {
        let selected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selectedTab = tab
            }
            action?()
        } label: {
            Image(systemName: systemName)
                .font(.satoshi(size: 28, weight: .medium))
                .foregroundStyle(selected ? Color.black : Color.black.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.black.opacity(0.07))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func externalBottomTabButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.satoshi(size: 28, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }
}

// ── Swipeable event hero card (used in multi-event carousel) ──────────────────
private struct EventHeroCard: View {
    let dict: [String: Any]
    let activeCoverDraft: HomeCoverDraft
    let isActive: Bool
    let phoneHeight: CGFloat
    @Binding var phoneShowingBack: Bool
    @Binding var dragOffset: CGFloat
    @Binding var restingAngle: Double
    let editAction: () -> Void
    let cameraAction: () -> Void
    let shareAction: () -> Void
    let qrAction: () -> Void

    @State private var loadedImage: UIImage? = nil

    private var eventName: String { dict["eventName"] as? String ?? "" }
    private var coverImageUrl: String { dict["coverImageUrl"] as? String ?? "" }

    private var displayDraft: HomeCoverDraft {
        if isActive { return activeCoverDraft }
        var d = HomeCoverDraft()
        d.title = dict["coverTitle"] as? String ?? eventName
        d.subtitle = dict["coverSubtitle"] as? String ?? ""
        d.buttonTitle = dict["coverButtonTitle"] as? String ?? "Take Photos"
        if let raw = dict["coverStyle"] as? String {
            d.style = HomeCoverStyle(rawValue: raw) ?? .polaroid
        }
        d.image = loadedImage
        return d
    }

    private var endText: String {
        guard let ts = dict["endDate"] as? TimeInterval else { return "" }
        let df = DateFormatter()
        df.dateFormat = "d MMM • HH:mm"
        return "Ends \(df.string(from: Date(timeIntervalSince1970: ts)))"
    }

    private var guestLimit: Int { dict["guestLimit"] as? Int ?? 10 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("HOSTING")
                    .font(.satoshi(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.3)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            ZStack {
                Text(eventName)
                    .font(.satoshi(size: 29, weight: .italic))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    Button(action: editAction) {
                        Image(systemName: "pencil")
                            .font(.satoshi(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 52, height: 38)
                            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 22)

            Text("Share with friends!")
                .font(.satoshi(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)

            SwipeablePhoneMockup(
                eventName: displayDraft.title,
                coverDraft: displayDraft,
                showingBack: $phoneShowingBack,
                dragOffset: $dragOffset,
                restingAngle: $restingAngle
            )
            .frame(height: phoneHeight)
            .padding(.top, 14)

            Text("Up to \(guestLimit) Guests • \(endText)")
                .font(.satoshi(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                dashboardToolButton(systemName: "camera", action: cameraAction)
                dashboardToolButton(systemName: "square.and.arrow.up", action: shareAction)
                dashboardToolButton(systemName: "qrcode", action: qrAction)
            }
            .padding(.top, 12)
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color(hex: "#8C8073"), Color(hex: "#69635F"), Color(hex: "#555152")],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 34)
        )
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .task {
            guard !isActive, !coverImageUrl.isEmpty, let url = URL(string: coverImageUrl) else { return }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                loadedImage = img
            }
        }
    }

    private func dashboardToolButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.satoshi(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CamerasTabPage: View {
    var events: [[String: Any]] = []
    let openCameraForEvent: ([String: Any]) -> Void
    let joinAction: () -> Void

    private var featuredEvent: [String: Any]? {
        let now = Date()
        let sortedEvents = events.sorted { lhs, rhs in
            let lhsDate = (lhs["endDate"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .distantFuture
            let rhsDate = (rhs["endDate"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .distantFuture
            let lhsIsActive = lhsDate >= now
            let rhsIsActive = rhsDate >= now

            if lhsIsActive != rhsIsActive {
                return lhsIsActive && !rhsIsActive
            }

            return lhsDate < rhsDate
        }

        return sortedEvents.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Cameras")
                    .font(.satoshi(size: 30, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Button(action: joinAction) {
                    HStack(spacing: 9) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.satoshi(size: 17, weight: .bold))
                        Text("Join")
                            .font(.satoshi(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 17)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.07), in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 34)
            .padding(.bottom, 20)

            if let featuredEvent {
                Button { openCameraForEvent(featuredEvent) } label: {
                    FeaturedCameraBanner(eventDict: featuredEvent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)

            if !events.isEmpty {
                Text("ACTIVE")
                    .font(.satoshi(size: 15, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.top, 28)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(events.indices, id: \.self) { idx in
                            let ev = events[idx]
                            Button { openCameraForEvent(ev) } label: {
                                ActiveCameraCardFromDict(eventDict: ev)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.satoshi(size: 36, weight: .medium))
                        .foregroundStyle(.black.opacity(0.2))
                    Text("No active cameras")
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundStyle(.black.opacity(0.4))
                    Text("Tap + to create your first Tetamu event")
                        .font(.satoshi(size: 14))
                        .foregroundStyle(.black.opacity(0.28))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F2F2F2"))
    }
}

private struct FeaturedCameraBanner: View {
    let eventDict: [String: Any]
    @State private var coverImage: UIImage?

    private var eventName: String { eventDict["eventName"] as? String ?? "Event" }

    private var statusText: String {
        guard let endTs = eventDict["endDate"] as? TimeInterval else { return "Open now" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: Date(timeIntervalSince1970: endTs)).day ?? 0
        if days > 1 { return "\(days)d left" }
        if days == 1 { return "Ends tomorrow" }
        if days == 0 { return "Ends today" }
        return "Ended"
    }

    private var detailLine: String {
        let guests = (eventDict["guestLimit"] as? Int).map { "Up to \($0) guests" }
        let photos = (eventDict["numberOfPhotos"] as? Int).map { "\($0) photos each" }
        let gallery = (eventDict["galleryOpen"] as? Bool) == true ? "Gallery on" : "Gallery private"
        if let guests, let photos {
            return "\(guests) • \(photos)"
        }
        if let guests {
            return "\(guests) • \(gallery)"
        }
        if let photos {
            return "\(photos) • \(gallery)"
        }
        return gallery
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color(hex: "#CBC2F0"), Color(hex: "#8B816C"), Color(hex: "#59514B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear, .black.opacity(0.54)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 12) {
                Text("UP NEXT")
                    .font(.satoshi(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.82))

                Text(eventName)
                    .font(.satoshi(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(detailLine)
                    .font(.satoshi(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(statusText)
                        .font(.satoshi(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#2B2928"))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color(hex: "#E4D7C6"), in: Capsule())

                    HStack(spacing: 7) {
                        Text("Open Camera")
                        Image(systemName: "chevron.right")
                            .font(.satoshi(size: 14, weight: .bold))
                    }
                    .font(.satoshi(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.16), in: Capsule())
                }
            }
            .padding(22)
        }
        .frame(height: 248)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 22, y: 14)
        .onAppear { loadCover() }
    }

    private func loadCover() {
        guard let urlStr = eventDict["coverImageUrl"] as? String,
              let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let img = UIImage(data: data) {
                DispatchQueue.main.async { coverImage = img }
            }
        }.resume()
    }
}

private struct ActiveCameraCardFromDict: View {
    let eventDict: [String: Any]
    @State private var coverImage: UIImage?

    private var eventName: String { eventDict["eventName"] as? String ?? "Event" }
    private var daysLeft: String {
        guard let endTs = eventDict["endDate"] as? TimeInterval else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: Date(timeIntervalSince1970: endTs)).day ?? 0
        return days > 0 ? "\(days)d left" : "Ended"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = coverImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color(hex: "#2A2A2A")
                }
            }
            .frame(width: 152, height: 276)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if !daysLeft.isEmpty {
                Text(daysLeft)
                    .font(.satoshi(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#2B2928"))
                    .padding(.horizontal, 13)
                    .frame(height: 32)
                    .background(Color(hex: "#DDD0C0"), in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(eventName)
                    .font(.satoshi(size: 16, weight: .italic))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 7) {
                    Text("Open Camera")
                    Image(systemName: "chevron.right").font(.satoshi(size: 15, weight: .bold))
                }
                .font(.satoshi(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.74))
            }
            .padding(.horizontal, 13)
            .padding(.bottom, 16)
        }
        .frame(width: 152, height: 276)
        .onAppear { loadCover() }
    }

    private func loadCover() {
        guard let urlStr = eventDict["coverImageUrl"] as? String,
              let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data, let img = UIImage(data: data) {
                DispatchQueue.main.async { coverImage = img }
            }
        }.resume()
    }
}

private struct ActiveCameraCard: View {
    let eventName: String
    let coverDraft: HomeCoverDraft

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cameraImage
                .frame(width: 152, height: 276)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("8d left")
                .font(.satoshi(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#2B2928"))
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(Color(hex: "#DDD0C0"), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

            VStack(alignment: .leading, spacing: 6) {
                Text(eventName)
                    .font(.satoshi(size: 16, weight: .italic))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 7) {
                    Text("Open Camera")
                    Image(systemName: "chevron.right")
                        .font(.satoshi(size: 15, weight: .bold))
                }
                .font(.satoshi(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.74))
            }
            .padding(.horizontal, 13)
            .padding(.bottom, 16)
        }
        .frame(width: 152, height: 276)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cameraImage: some View {
        if let image = coverDraft.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image("CameraScreenMockup")
                .resizable()
                .scaledToFill()
        }
    }
}

private struct QRScannerSheet: View {
    let dismissAction: () -> Void
    let scanAction: (String) -> Void

    var body: some View {
        ZStack {
            QRScannerView(scanAction: scanAction)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()

                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.satoshi(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.34), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Spacer()

                Text("Scan your event QR code")
                    .font(.satoshi(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 48)
                    .background(Color.black.opacity(0.38), in: Capsule())

                Spacer()

                Button(action: dismissAction) {
                    Text("Done")
                        .font(.satoshi(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black)
    }
}

private struct QRScannerView: UIViewControllerRepresentable {
    let scanAction: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(scanAction: scanAction)
    }

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    final class Coordinator: NSObject {
        let scanAction: (String) -> Void
        var hasScanned = false

        init(scanAction: @escaping (String) -> Void) {
            self.scanAction = scanAction
        }
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var coordinator: QRScannerView.Coordinator?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureScanner()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureScanner() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else { return }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let coordinator,
              !coordinator.hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let value = metadataObject.stringValue else { return }

        coordinator.hasScanned = true
        session.stopRunning()
        coordinator.scanAction(value)
    }
}

private struct POVCameraFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let eventID: String
    let userName: String
    let eventName: String
    let endDateText: String
    let shotsAllowed: Int
    let coverDraft: HomeCoverDraft

    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            if authorizationStatus == .authorized {
                POVCameraLiveView(
                    eventID: eventID,
                    userName: userName,
                    eventName: eventName,
                    endDateText: endDateText,
                    shotsAllowed: shotsAllowed,
                    dismissAction: { dismiss() }
                )
            } else {
                POVCameraPermissionView(
                    eventName: eventName,
                    endDateText: endDateText,
                    shotsAllowed: shotsAllowed,
                    coverDraft: coverDraft,
                    dismissAction: { dismiss() },
                    requestAccessAction: requestCameraAccess
                )
            }
        }
        .onAppear {
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        default:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

private struct POVCameraPermissionView: View {
    let eventName: String
    let endDateText: String
    let shotsAllowed: Int
    let coverDraft: HomeCoverDraft
    let dismissAction: () -> Void
    let requestAccessAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let controlsClearance = safeBottom + 188
            let topSpacing = max(proxy.safeAreaInsets.top + 118, proxy.size.height * 0.24)

            ZStack {
                CameraStarterBackdrop(coverDraft: coverDraft)
                    .blur(radius: 10)
                    .overlay(Color.black.opacity(0.34))
                    .ignoresSafeArea()

                CameraChrome(
                    eventName: eventName,
                    endDateText: endDateText,
                    dimmed: true,
                    closeSystemName: "xmark",
                    dismissAction: dismissAction
                )

                VStack(spacing: 0) {
                    Spacer(minLength: topSpacing)

                    accessCard
                        .frame(maxWidth: min(proxy.size.width - 36, 420))
                        .padding(.horizontal, 18)

                    Spacer(minLength: controlsClearance)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CameraBottomControls(
                    shotsRemaining: shotsAllowed,
                    totalShots: shotsAllowed,
                    isFlashOn: false,
                    dimmed: true,
                    thumbnailImage: coverDraft.image,
                    flashAction: {},
                    shutterAction: {},
                    flipAction: {}
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.black)
    }

    private var accessCard: some View {
        VStack(spacing: 0) {
            Text("GRANT CAMERA ACCESS TO START")
                .font(.satoshi(size: 14, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.66))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 26)

            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)
                .padding(.horizontal, 22)
                .padding(.top, 20)

            HStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.satoshi(size: 30, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 72, height: 72)
                    .background(Color.white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Camera")
                        .font(.satoshi(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Unlock \(shotsAllowed) photos")
                        .font(.satoshi(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Button(action: requestAccessAction) {
                HStack(spacing: 10) {
                    Text("Allow Access")
                    Image(systemName: "arrow.right")
                }
                .font(.satoshi(size: 22, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
            }
            .buttonStyle(.plain)
        }
        .background(Color(hex: "#17181B").opacity(0.98), in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct POVCameraLiveView: View {
    let eventID: String
    let userName: String
    let eventName: String
    let endDateText: String
    let shotsAllowed: Int
    let dismissAction: () -> Void

    @StateObject private var camera = CameraModel()
    @State private var displayedShots = 0
    @State private var hasRolledInitialShots = false
    @State private var rollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            if let previewImage = camera.previewImage {
                Color.black.opacity(0.82).ignoresSafeArea()
                capturedPreview(image: previewImage)
            } else {
                CameraChrome(
                    eventName: eventName,
                    endDateText: endDateText,
                    dimmed: false,
                    closeSystemName: "xmark",
                    dismissAction: dismissAction
                )

                CameraBottomControls(
                    shotsRemaining: displayedShots,
                    totalShots: max(camera.maxPhotos, shotsAllowed),
                    isFlashOn: camera.isFlashOn,
                    dimmed: false,
                    thumbnailImage: nil,
                    flashAction: camera.toggleFlash,
                    shutterAction: camera.takePhoto,
                    flipAction: camera.switchCamera
                )
                .disabled(camera.remainingPhotos <= 0 && shotsAllowed <= 0)
            }
        }
        .background(Color.black)
        .onAppear {
            camera.eventID = eventID
            camera.userName = userName
            camera.remainingPhotos = max(camera.remainingPhotos, shotsAllowed)
            displayedShots = max(camera.remainingPhotos, shotsAllowed)
            camera.fetchRemainingPhotos()
        }
        .onChange(of: camera.remainingPhotos) { _, newValue in
            updateDisplayedShots(for: newValue)
        }
        .onChange(of: camera.maxPhotos) { _, _ in
            updateDisplayedShots(for: camera.remainingPhotos)
        }
        .onDisappear {
            rollTask?.cancel()
            camera.stopSession()
        }
    }

    private func capturedPreview(image: UIImage) -> some View {
        VStack(spacing: 18) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 18)

            HStack(spacing: 12) {
                Button(action: camera.retakePhoto) {
                    Text("Re-take")
                        .font(.satoshi(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: camera.savePhoto) {
                    Text("Save")
                        .font(.satoshi(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color(hex: "#5750E6"), in: Capsule())
                }
                .buttonStyle(.plain)
            }
                .padding(.horizontal, 18)
        }
    }

    private var shotRollKey: String {
        "\(eventID)-\(userName)"
    }

    private func updateDisplayedShots(for remaining: Int) {
        guard remaining >= 0 else { return }

        if CameraShotRollMemory.hasRolled(shotRollKey) {
            hasRolledInitialShots = true
            displayedShots = remaining
            return
        }

        if !hasRolledInitialShots, camera.maxPhotos > 0 {
            hasRolledInitialShots = true
            startInitialShotRoll(from: camera.maxPhotos, to: remaining)
            return
        }

        displayedShots = remaining
    }

    private func startInitialShotRoll(from total: Int, to remaining: Int) {
        rollTask?.cancel()
        displayedShots = total

        guard total != remaining else {
            CameraShotRollMemory.markRolled(shotRollKey)
            return
        }

        rollTask = Task { @MainActor in
            let direction = total > remaining ? -1 : 1
            var value = total

            while value != remaining && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 55_000_000)
                value += direction
                withAnimation(.easeOut(duration: 0.06)) {
                    displayedShots = value
                }
            }

            CameraShotRollMemory.markRolled(shotRollKey)
        }
    }
}

private struct CameraChrome: View {
    let eventName: String
    let endDateText: String
    let dimmed: Bool
    let closeSystemName: String
    let dismissAction: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Button(action: dismissAction) {
                    Image(systemName: closeSystemName)
                        .font(.satoshi(size: 27, weight: .medium))
                        .foregroundStyle(.white.opacity(dimmed ? 0.76 : 0.95))
                        .frame(width: 54, height: 54)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 7) {
                    HStack(spacing: 6) {
                        Text(eventName)
                            .font(.satoshi(size: 22, weight: .italic))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Image(systemName: "chevron.right")
                            .font(.satoshi(size: 15, weight: .bold))
                    }
                    Text(endDateText)
                        .font(.satoshi(size: 17, weight: .bold))
                }
                .foregroundStyle(.white.opacity(dimmed ? 0.38 : 0.92))
                .frame(maxWidth: 260)

                Spacer()

                CameraSideControls(dimmed: dimmed)
            }
            .padding(.horizontal, 22)
            .padding(.top, 48)

            Spacer()
        }
    }
}

private struct CameraSideControls: View {
    let dimmed: Bool

    var body: some View {
        VStack(spacing: 0) {
            sideIcon("gearshape")
            divider
            sideIcon("square.and.arrow.up")
            divider
            sideIcon("iphone.gen2.badge.plus")
            divider
            sideIcon("photo.badge.plus")
        }
        .foregroundStyle(.white.opacity(dimmed ? 0.3 : 0.95))
        .frame(width: 58)
        .background(Color.black.opacity(dimmed ? 0.12 : 0.28), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(dimmed ? 0.05 : 0.18), lineWidth: 1))
    }

    private func sideIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.satoshi(size: 23, weight: .medium))
            .frame(width: 58, height: 56)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(dimmed ? 0.05 : 0.18))
            .frame(height: 1)
            .padding(.horizontal, 7)
    }
}

private struct CameraBottomControls: View {
    let shotsRemaining: Int
    let totalShots: Int
    let isFlashOn: Bool
    let dimmed: Bool
    let thumbnailImage: UIImage?
    let flashAction: () -> Void
    let shutterAction: () -> Void
    let flipAction: () -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .center) {
                Button(action: flashAction) {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.satoshi(size: 31, weight: .bold))
                        .foregroundStyle(.white.opacity(dimmed ? 0.28 : 0.9))
                        .frame(width: 74)
                }
                .buttonStyle(.plain)
                .offset(y: -82)

                Spacer()

                Button(action: shutterAction) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(hex: "#D6D7DA")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 86, height: 86)
                        .overlay(Circle().stroke(Color.black, lineWidth: 4))
                        .overlay(Circle().stroke(Color.black.opacity(0.42), lineWidth: 1).padding(8))
                        .opacity(dimmed ? 0.25 : 1)
                }
                .buttonStyle(.plain)

                Spacer()

                submissionControl(thumbnailImage: thumbnailImage, dimmed: dimmed, flipAction: flipAction)
                .offset(y: -82)
            }
            .overlay(alignment: .bottomLeading) {
                FilmShotCounter(
                    shotsRemaining: shotsRemaining,
                    totalShots: totalShots,
                    dimmed: dimmed
                )
                .padding(.leading, 18)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(dimmed ? 0.72 : 0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .offset(y: 44),
                alignment: .bottom
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func submissionControl(thumbnailImage: UIImage?, dimmed: Bool, flipAction: @escaping () -> Void) -> some View {
        Button(action: flipAction) {
            CameraSubmissionThumbnail(thumbnailImage: thumbnailImage, dimmed: dimmed)
                .frame(width: 78, height: 78)
        }
        .buttonStyle(.plain)
        .frame(width: 74, height: 74)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "camera.fill")
                .font(.satoshi(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(dimmed ? 0.24 : 0.95))
                .offset(x: 4, y: -42)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if !dimmed {
                Text("Tap to manage submissions")
                    .font(.satoshi(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .bottomTrailing) {
                        Triangle()
                            .fill(Color.white)
                            .frame(width: 14, height: 10)
                            .offset(x: -12, y: 8)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: 8, y: -2)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct FilmShotCounter: View {
    let shotsRemaining: Int
    let totalShots: Int
    let dimmed: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            VStack(alignment: .leading, spacing: -3) {
                Text("\(shotsRemaining)")
                    .font(.satoshi(size: 38, weight: .black))
                    .italic()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText(value: Double(shotsRemaining)))

                if totalShots > 0 {
                    Text("\(totalShots)")
                        .font(.satoshi(size: 31, weight: .black))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white.opacity(dimmed ? 0.08 : 0.16))
                }
            }
            .frame(width: 54, alignment: .leading)
            .animation(.easeOut(duration: 0.08), value: shotsRemaining)

            Text("SHOTS\nREMAINING")
                .font(.satoshi(size: 12, weight: .black))
                .italic()
                .lineSpacing(-2)
                .padding(.bottom, 18)
        }
        .foregroundStyle(.white.opacity(dimmed ? 0.16 : 0.95))
        .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
    }
}

private enum CameraShotRollMemory {
    private static var rolledKeys = Set<String>()

    static func hasRolled(_ key: String) -> Bool {
        rolledKeys.contains(key)
    }

    static func markRolled(_ key: String) {
        rolledKeys.insert(key)
    }
}

private struct CameraSubmissionThumbnail: View {
    let thumbnailImage: UIImage?
    let dimmed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .fill(Color.white.opacity(0.12))
                .frame(width: 44, height: 60)
                .rotationEffect(.degrees(-8))
                .offset(x: -13, y: 5)

            Group {
                if let thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.72), Color(hex: "#8E8B42"), Color.black.opacity(0.92)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
            .frame(width: 54, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .rotationEffect(.degrees(10))
            .offset(x: 9, y: -2)
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .rotationEffect(.degrees(10))
                    .offset(x: 9, y: -2)
            )
        }
        .opacity(dimmed ? 0.24 : 0.95)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct CameraStarterBackdrop: View {
    let coverDraft: HomeCoverDraft

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#9F8F73"), Color(hex: "#60554D"), Color(hex: "#2D2E31")],
                startPoint: .top,
                endPoint: .bottom
            )

            if let image = coverDraft.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.55)
            }
        }
    }
}

private struct SwipeablePhoneMockup: View {
    let eventName: String
    let coverDraft: HomeCoverDraft
    @Binding var showingBack: Bool
    @Binding var dragOffset: CGFloat
    @Binding var restingAngle: Double
    @State private var isCompletingFlip = false

    var body: some View {
        ZStack {
            Phone3DSceneView(
                eventName: eventName,
                coverDraft: coverDraft,
                angle: currentAngle,
                warmReflection: !showingBack
            )
            .frame(width: 310, height: 380)
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
    let coverDraft: HomeCoverDraft
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
        context.coordinator.build(eventName: eventName, coverDraft: coverDraft, initialAngle: angle)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(eventName: eventName, coverDraft: coverDraft, angle: angle, warmReflection: warmReflection)
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
        private var displayMaterial: SCNMaterial?
        private var fallbackScreenMaterial: SCNMaterial?
        private var currentTextureKey = ""

        init() {
            scene.rootNode.addChildNode(phoneNode)
            configureCamera()
            configureLights()
        }

        func build(eventName: String, coverDraft: HomeCoverDraft, initialAngle: Double) {
            currentEventName = eventName
            phoneNode.childNodes.forEach { $0.removeFromParentNode() }
            displayMaterial = nil
            fallbackScreenMaterial = nil
            currentTextureKey = ""
            setAngleImmediately(initialAngle)

            if loadBundledIPhoneModel(eventName: eventName, coverDraft: coverDraft) {
                return
            }

            buildFallbackPhone(eventName: eventName, coverDraft: coverDraft)
        }

        func update(eventName: String, coverDraft: HomeCoverDraft, angle: Double, warmReflection: Bool) {
            if currentEventName != eventName {
                build(eventName: eventName, coverDraft: coverDraft, initialAngle: angle)
            }

            updateScreenTexture(coverDraft: coverDraft)
            updateLighting(warmReflection: warmReflection)

            let delta = abs(angle - currentAngle)
            let isReleaseFlip = delta > 80

            if let activeFlipTarget, abs(activeFlipTarget - angle) < 0.5 {
                return
            }

            if !isReleaseFlip {
                activeFlipTarget = nil
                phoneNode.removeAction(forKey: "dashboard-flip")
                setAngleImmediately(angle)
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

        private func setAngleImmediately(_ angle: Double) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            phoneNode.eulerAngles.y = radians(for: angle)
            SCNTransaction.commit()
            currentAngle = angle
            activeFlipTarget = nil
        }

        private func loadBundledIPhoneModel(eventName: String, coverDraft: HomeCoverDraft) -> Bool {
            guard let url = Bundle.main.url(forResource: "iPhone_17_Pro", withExtension: "usdz"),
                  let modelScene = try? SCNScene(url: url) else {
                return false
            }

            let wrapper = SCNNode()
            for child in modelScene.rootNode.childNodes {
                wrapper.addChildNode(child.clone())
            }
            let modelHalfDepth = normalizeModel(wrapper)
            attachCameraScreenTexture(to: wrapper, coverDraft: coverDraft)
            wrapper.eulerAngles.x = 0
            wrapper.eulerAngles.y = .pi
            phoneNode.addChildNode(wrapper)

            let surfaceOffset: Float = 0.004
            addTapeLabel(eventName: eventName, z: modelHalfDepth + surfaceOffset, facesBack: false)
            return true
        }

        private func normalizeModel(_ node: SCNNode) -> Float {
            let bounds = node.boundingBox
            let min = bounds.min
            let max = bounds.max
            let width = max.x - min.x
            let height = max.y - min.y
            let depth = max.z - min.z
            let largest = Swift.max(width, Swift.max(height, depth))
            guard largest > 0 else { return 0.137 }

            let targetHeight: Float = 3.1
            let scale = targetHeight / largest
            let center = SCNVector3(
                (min.x + max.x) / 2,
                (min.y + max.y) / 2,
                (min.z + max.z) / 2
            )

            node.scale = SCNVector3(scale, scale, scale)
            node.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
            return (depth * scale) / 2
        }

        private func attachCameraScreenTexture(to root: SCNNode, coverDraft: HomeCoverDraft) {
            let screenImage = cameraScreenImage(coverDraft: coverDraft)
            func visit(_ node: SCNNode) {
                if let geometry = node.geometry {
                    if geometry.materials.contains(where: { $0.name == "Display" }) {
                        let bounds = node.boundingBox
                        let width = (bounds.max.x - bounds.min.x) * 0.985
                        let height = (bounds.max.y - bounds.min.y) * 0.985
                        let displayPlane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
                        let material = SCNMaterial()
                        material.diffuse.contents = screenImage
                        material.diffuse.wrapS = .clamp
                        material.diffuse.wrapT = .clamp
                        material.diffuse.magnificationFilter = .linear
                        material.diffuse.minificationFilter = .linear
                        material.emission.contents = screenImage
                        material.blendMode = .alpha
                        material.transparencyMode = .aOne
                        material.isDoubleSided = false
                        material.writesToDepthBuffer = false
                        material.readsFromDepthBuffer = false
                        material.lightingModel = .constant
                        displayPlane.materials = [material]
                        displayMaterial = material

                        let displayNode = SCNNode(geometry: displayPlane)
                        displayNode.position = SCNVector3(
                            (bounds.min.x + bounds.max.x) / 2,
                            (bounds.min.y + bounds.max.y) / 2,
                            bounds.max.z + 0.0001
                        )
                        displayNode.renderingOrder = 80
                        node.addChildNode(displayNode)

                        geometry.materials.forEach { material in
                            if material.name == "Display" {
                                material.diffuse.contents = UIColor.black
                                material.emission.contents = UIColor.black
                            }
                        }
                        return
                    }
                }

                for child in node.childNodes {
                    visit(child)
                }
            }

            visit(root)
        }

        private func buildFallbackPhone(eventName: String, coverDraft: HomeCoverDraft) {
            addPhoneBody()
            addFrontFace(eventName: eventName, coverDraft: coverDraft)
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

        private func addFrontFace(eventName: String, coverDraft: HomeCoverDraft) {
            let screen = SCNBox(width: 1.38, height: 2.83, length: 0.025, chamferRadius: 0.14)
            let screenMaterial = material(UIColor(red: 0.48, green: 0.38, blue: 0.3, alpha: 1), roughness: 0.55, metalness: 0.05)
            screenMaterial.diffuse.contents = cameraScreenImage(coverDraft: coverDraft)
            screenMaterial.emission.contents = cameraScreenImage(coverDraft: coverDraft)
            screenMaterial.blendMode = .alpha
            screenMaterial.transparencyMode = .aOne
            screenMaterial.lightingModel = .constant
            fallbackScreenMaterial = screenMaterial
            screen.materials = [screenMaterial]
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

        private func addTapeLabel(eventName: String, parent: SCNNode? = nil, z: Float, facesBack: Bool, followsModelTilt: Bool = false) {
            let tape = SCNPlane(width: 1.16, height: 0.29)
            let tapeMaterial = SCNMaterial()
            tapeMaterial.diffuse.contents = tapeTexture(eventName: eventName)
            tapeMaterial.roughness.contents = 0.95
            tapeMaterial.metalness.contents = 0
            tapeMaterial.isDoubleSided = true
            tapeMaterial.writesToDepthBuffer = false
            tapeMaterial.readsFromDepthBuffer = true
            tape.materials = [tapeMaterial]

            let tapeNode = SCNNode(geometry: tape)
            tapeNode.position = SCNVector3(0, 0.34, z)
            tapeNode.eulerAngles.x = followsModelTilt ? -0.08 : 0
            tapeNode.eulerAngles.z = 0
            tapeNode.eulerAngles.y = facesBack ? .pi : 0
            tapeNode.renderingOrder = 30

            self.tapeNode = tapeNode
            (parent ?? phoneNode).addChildNode(tapeNode)
        }

        private func tapeTexture(eventName: String) -> UIImage {
            let size = CGSize(width: 520, height: 128)
            let renderer = UIGraphicsImageRenderer(size: size, format: {
                let format = UIGraphicsImageRendererFormat()
                format.scale = 2
                format.opaque = false
                return format
            }())

            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                UIColor.clear.setFill()
                UIRectFill(rect)

                let tapeRect = rect.insetBy(dx: 16, dy: 18)
                let tapePath = UIBezierPath()
                tapePath.move(to: CGPoint(x: tapeRect.minX + 13, y: tapeRect.minY + 7))
                tapePath.addLine(to: CGPoint(x: tapeRect.minX + 74, y: tapeRect.minY + 2))
                tapePath.addLine(to: CGPoint(x: tapeRect.midX - 10, y: tapeRect.minY + 8))
                tapePath.addLine(to: CGPoint(x: tapeRect.maxX - 62, y: tapeRect.minY + 0))
                tapePath.addLine(to: CGPoint(x: tapeRect.maxX - 8, y: tapeRect.minY + 9))
                tapePath.addLine(to: CGPoint(x: tapeRect.maxX - 15, y: tapeRect.midY - 4))
                tapePath.addLine(to: CGPoint(x: tapeRect.maxX - 5, y: tapeRect.maxY - 9))
                tapePath.addLine(to: CGPoint(x: tapeRect.maxX - 70, y: tapeRect.maxY - 2))
                tapePath.addLine(to: CGPoint(x: tapeRect.midX + 24, y: tapeRect.maxY - 8))
                tapePath.addLine(to: CGPoint(x: tapeRect.minX + 62, y: tapeRect.maxY - 1))
                tapePath.addLine(to: CGPoint(x: tapeRect.minX + 7, y: tapeRect.maxY - 10))
                tapePath.addLine(to: CGPoint(x: tapeRect.minX + 15, y: tapeRect.midY + 2))
                tapePath.close()

                UIColor(red: 0.59, green: 0.58, blue: 0.62, alpha: 0.95).setFill()
                tapePath.fill()

                UIColor.white.withAlphaComponent(0.08).setFill()
                UIBezierPath(roundedRect: tapeRect.insetBy(dx: 26, dy: 12), cornerRadius: 10).fill()

                UIColor(red: 0.24, green: 0.23, blue: 0.27, alpha: 0.18).setStroke()
                tapePath.lineWidth = 3
                tapePath.stroke()

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byTruncatingTail

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.satoshi(size: 35, weight: .italic),
                    .foregroundColor: UIColor(red: 0.12, green: 0.1, blue: 0.16, alpha: 0.86),
                    .paragraphStyle: paragraph
                ]
                eventName.draw(
                    with: rect.insetBy(dx: 52, dy: 40),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: attributes,
                    context: nil
                )
            }
        }

        private func addCameraScreenOverlay(z: Float) {
            let screen = SCNPlane(width: 1.31, height: 2.8)
            let material = SCNMaterial()
            material.diffuse.contents = cameraScreenImage(coverDraft: HomeCoverDraft())
            material.emission.contents = UIColor.black
            material.blendMode = .alpha
            material.transparencyMode = .aOne
            material.roughness.contents = 0.82
            material.metalness.contents = 0
            material.isDoubleSided = false
            material.writesToDepthBuffer = false
            material.readsFromDepthBuffer = true
            material.lightingModel = .constant
            screen.materials = [material]

            let screenNode = SCNNode(geometry: screen)
            screenNode.position = SCNVector3(0, 0, z)
            screenNode.eulerAngles.y = .pi
            screenNode.renderingOrder = 18
            phoneNode.addChildNode(screenNode)
        }

        private func updateScreenTexture(coverDraft: HomeCoverDraft) {
            let key = textureKey(for: coverDraft)
            guard currentTextureKey != key else { return }

            let image = cameraScreenImage(coverDraft: coverDraft)
            displayMaterial?.diffuse.contents = image
            displayMaterial?.emission.contents = image
            fallbackScreenMaterial?.diffuse.contents = image
            fallbackScreenMaterial?.emission.contents = image
            currentTextureKey = key
        }

        private func cameraScreenImage(coverDraft: HomeCoverDraft) -> UIImage {
            HomeCoverTextureRenderer.image(for: coverDraft)
        }

        private func textureKey(for coverDraft: HomeCoverDraft) -> String {
            let imageKey = coverDraft.image.map { "\(Unmanaged.passUnretained($0).toOpaque())" } ?? "none"
            return [
                coverDraft.style.rawValue,
                coverDraft.title,
                coverDraft.subtitle,
                coverDraft.buttonTitle,
                imageKey
            ].joined(separator: "|")
        }

        private func cameraScreenTexture() -> UIImage {
            let size = CGSize(width: 430, height: 920)
            let renderer = UIGraphicsImageRenderer(size: size, format: {
                let format = UIGraphicsImageRendererFormat()
                format.scale = 2
                format.opaque = true
                return format
            }())

            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                let cg = context.cgContext

                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor(red: 0.78, green: 0.78, blue: 0.74, alpha: 1).cgColor,
                        UIColor(red: 0.49, green: 0.48, blue: 0.45, alpha: 1).cgColor,
                        UIColor(red: 0.28, green: 0.23, blue: 0.21, alpha: 1).cgColor
                    ] as CFArray,
                    locations: [0, 0.55, 1]
                )
                cg.drawLinearGradient(gradient!, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

                UIColor(red: 0.88, green: 0.78, blue: 0.58, alpha: 0.45).setFill()
                let table = UIBezierPath()
                table.move(to: CGPoint(x: -35, y: 105))
                table.addLine(to: CGPoint(x: 345, y: -38))
                table.addLine(to: CGPoint(x: 428, y: 84))
                table.addLine(to: CGPoint(x: 42, y: 250))
                table.close()
                table.fill()

                UIColor.black.withAlphaComponent(0.18).setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height)).fill(with: .sourceAtop, alpha: 0.16)

                let blurOverlay = UIColor(red: 0.72, green: 0.72, blue: 0.68, alpha: 0.22)
                blurOverlay.setFill()
                UIBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 0), cornerRadius: 32).fill(with: .screen, alpha: 0.26)

                drawCameraHUD(eventName: currentEventName, in: rect)
            }
        }

        private func drawCameraHUD(eventName: String, in rect: CGRect) {
            let titleFont = UIFont.satoshi(size: 29, weight: .black)
            let subtitleFont = UIFont.satoshi(size: 15, weight: .medium)

            UIColor.white.withAlphaComponent(0.95).setFill()
            "3:46".draw(at: CGPoint(x: 48, y: 22), withAttributes: [.font: UIFont.satoshi(size: 22, weight: .bold), .foregroundColor: UIColor.white])
            eventName.draw(
                in: CGRect(x: 70, y: 78, width: rect.width - 140, height: 38),
                withAttributes: [.font: titleFont, .foregroundColor: UIColor.white, .paragraphStyle: centeredParagraph()]
            )
            "Tap to invite friends!".draw(
                in: CGRect(x: 70, y: 114, width: rect.width - 140, height: 24),
                withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.white.withAlphaComponent(0.82), .paragraphStyle: centeredParagraph()]
            )

            drawRoundedControl(rect: CGRect(x: 364, y: 83, width: 42, height: 42), text: "⚙")
            drawRoundedControl(rect: CGRect(x: 365, y: 405, width: 40, height: 40), text: "↯")
            drawRoundedControl(rect: CGRect(x: 365, y: 453, width: 40, height: 40), text: "⚡")

            drawRoundedControl(rect: CGRect(x: 91, y: 760, width: 52, height: 52), text: "1x")
            drawRoundedControl(rect: CGRect(x: 288, y: 760, width: 52, height: 52), text: "↻")

            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 176, y: 744, width: 78, height: 78)).fill()
            UIColor(red: 0.45, green: 0.47, blue: 0.92, alpha: 1).setStroke()
            let shutterRing = UIBezierPath(ovalIn: CGRect(x: 169, y: 737, width: 92, height: 92))
            shutterRing.lineWidth = 6
            shutterRing.stroke()

            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 842, width: rect.width, height: 78)).fill()
            "6".draw(at: CGPoint(x: 34, y: 853), withAttributes: [.font: UIFont.satoshi(size: 48, weight: .black), .foregroundColor: UIColor.white])
            "SHOTS\nREMAINING".draw(
                in: CGRect(x: 88, y: 862, width: 120, height: 52),
                withAttributes: [.font: UIFont.satoshi(size: 18, weight: .italic), .foregroundColor: UIColor.white]
            )
        }

        private func drawRoundedControl(rect: CGRect, text: String) {
            UIColor(red: 0.14, green: 0.11, blue: 0.16, alpha: 0.68).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
            text.draw(in: rect.insetBy(dx: 5, dy: 8), withAttributes: [
                .font: UIFont.satoshi(size: 19, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: centeredParagraph()
            ])
        }

        private func centeredParagraph() -> NSMutableParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            return paragraph
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
            geometry.font = UIFont.satoshi(size: size, weight: .black)
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
                        .font(.satoshi(.title, weight: .bold))
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
                            .font(.satoshi(.headline, weight: .bold))
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
                .font(.satoshi(.headline, weight: .bold))
                .foregroundColor(.white)
            Text(title)
                .font(.satoshi(.caption2))
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - CreatePOVFlowView

private struct CreatePOVFlowView: View {
    let hostFirstName: String
    let onPublish: (_ eventDict: [String: Any], _ coverDraft: HomeCoverDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Namespace private var coverNS

    private enum FlowStep { case name, configure }
    @State private var flowStep: FlowStep = .name

    private enum ExpandedSetting { case ending, reveal, filter, photos }
    @State private var expandedSetting: ExpandedSetting? = nil
    @State private var expandingRow: ExpandedSetting? = nil

    // Name step
    @State private var eventName = ""

    // Configure step
    @State private var endDate: Date = {
        var c = DateComponents(); c.day = 6; c.hour = 23; c.minute = 59
        return Calendar.current.date(byAdding: c, to: Date()) ?? Date()
    }()
    @State private var endDateVisibleMonth: Date = {
        var c = DateComponents(); c.day = 1
        return Calendar.current.date(byAdding: c, to: Date()) ?? Date()
    }()
    @State private var revealMode = "At the end"
    @State private var filterStyle = "Disposable film"
    @State private var photosPerPerson = 10
    @State private var showGallery = true
    @State private var coverDraft = HomeCoverDraft()
    @State private var selectedCoverPhotoItem: PhotosPickerItem?
    @State private var showCoverEditor = false
    @State private var showFinishUp = false

    // Finish Up step
    private let guestTiers = [10, 25, 50, 100, 250, 500]
    @State private var guestTierIndex = 0
    @State private var isPublishing = false

    private var guestLimit: Int { guestTiers[guestTierIndex] }
    private var hasCoverPhoto: Bool { coverDraft.image != nil }

    private var suggestedNames: [String] {
        let fn = hostFirstName.isEmpty ? "Your" : hostFirstName
        let poss = fn == "Your" ? "Your" : "\(fn)'s"
        return [
            "\(fn) & Name",
            "\(poss) Party",
            "\(poss) Birthday",
            "\(fn) & Name's Engagement",
            "\(poss) Bachelor Party"
        ]
    }

    var body: some View {
        ZStack {
            Color(hex: "#11120D").ignoresSafeArea()
            Group {
                switch flowStep {
                case .name: nameStep
                case .configure: configureStep
                }
            }
            .opacity(showCoverEditor ? 0.18 : 1)
            .blur(radius: showCoverEditor ? 5 : 0)
            .allowsHitTesting(!showCoverEditor)
            .accessibilityHidden(showCoverEditor)

            if showCoverEditor {
                HomeCoverEditorScreen(draft: $coverDraft, namespace: coverNS) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.9)) {
                        showCoverEditor = false
                    }
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .sheet(isPresented: $showFinishUp) {
            finishUpSheet
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: eventName) { _, new in
            coverDraft.title = new
        }
        .onChange(of: selectedCoverPhotoItem) { _, item in
            loadSelectedCoverPhoto(item)
        }
    }

    // MARK: Step 1 — Name

    private var nameStep: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.satoshi(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Add a Name")
                .font(.satoshi(size: 24, weight: .black))
                .foregroundStyle(.white)
                .padding(.top, 28)

            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.satoshi(size: 18, weight: .medium))
                    .foregroundStyle(Color.black)
                TextField(
                    "",
                    text: $eventName,
                    prompt: Text("What's the occasion?")
                        .foregroundStyle(.white.opacity(0.32))
                )
                    .font(.satoshi(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 28)

            if !hostFirstName.isEmpty && !suggestedNames.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("SUGGESTED")
                        .font(.satoshi(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 12)

                    ForEach(suggestedNames, id: \.self) { name in
                        Button {
                            eventName = name
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.satoshi(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Button {
                coverDraft.title = eventName
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    flowStep = .configure
                }
            } label: {
                HStack {
                    Text("Continue")
                        .font(.satoshi(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.satoshi(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    eventName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.12)
                        : Color.black,
                    in: RoundedRectangle(cornerRadius: 28)
                )
            }
            .buttonStyle(.plain)
            .disabled(eventName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    // MARK: Step 2 — Configure

    private var configureStep: some View {
        GeometryReader { proxy in
            let phoneH = min(max(proxy.size.height * 0.30, 210), 270)
            let phoneW = phoneH * 0.46
            let safeBottom = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                // ── Scrollable content ────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Nav bar
                        HStack(spacing: 12) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.satoshi(size: 20, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.09), in: Circle())
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(eventName.isEmpty ? "New Event" : eventName)
                                .font(.satoshi(size: 20, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Button { } label: {
                                Image(systemName: "pencil")
                                    .font(.satoshi(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button { } label: {
                                Image(systemName: "ellipsis")
                                    .font(.satoshi(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Hero with 3D phone
                        ZStack(alignment: .topLeading) {
                            Group {
                                if let img = coverDraft.image {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .blur(radius: 28).opacity(0.45)
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: "#8C8073"), Color(hex: "#555152")],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: phoneH + 80)
                            .clipped()

                            HStack(alignment: .top) {
                                Button {
                                    coverDraft.title = eventName
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                                        showCoverEditor = true
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text("Cover")
                                            .font(.satoshi(size: 13, weight: .bold))
                                        Image(systemName: "chevron.right")
                                            .font(.satoshi(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(.white.opacity(0.82))
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(Color.black.opacity(0.28), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 16)
                                .padding(.top, 12)

                                Spacer()

                                VStack(spacing: 10) {
                                    Button {
                                        coverDraft.title = eventName
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                                            showCoverEditor = true
                                        }
                                    } label: {
                                        VStack(spacing: 5) {
                                            Image(systemName: "iphone")
                                                .font(.satoshi(size: 22, weight: .medium))
                                            Text("Edit")
                                                .font(.satoshi(size: 12, weight: .bold))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(width: 58, height: 58)
                                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)

                                    PhotosPicker(selection: $selectedCoverPhotoItem, matching: .images) {
                                        VStack(spacing: 5) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(systemName: "photo.fill")
                                                    .font(.satoshi(size: 20, weight: .medium))
                                                if !hasCoverPhoto {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.satoshi(size: 14, weight: .bold))
                                                        .foregroundStyle(Color.black)
                                                        .offset(x: 6, y: -6)
                                                }
                                            }
                                            Text("Photo")
                                                .font(.satoshi(size: 12, weight: .bold))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(width: 58, height: 58)
                                        .background(
                                            hasCoverPhoto ? Color.black.opacity(0.3) : Color.black.opacity(0.82),
                                            in: RoundedRectangle(cornerRadius: 14)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.trailing, 14)
                                .padding(.top, 10)
                            }

                            Phone3DSceneView(
                                eventName: coverDraft.title,
                                coverDraft: coverDraft,
                                angle: 180,
                                warmReflection: false
                            )
                            .frame(width: phoneW, height: phoneH)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        }
                        .frame(height: phoneH + 80)

                        // Settings list — rows only, no inline expansion
                        VStack(spacing: 0) {
                            HomeSettingRow(
                                icon: "calendar", title: "Ending", value: formattedEnd,
                                expanded: expandingRow == .ending || expandedSetting == .ending,
                                appearance: .dark
                            ) { toggle(.ending) }
                            HomeDivider(appearance: .dark)
                            HomeSettingRow(
                                icon: "hourglass", title: "Reveal Photos", value: revealMode,
                                expanded: expandingRow == .reveal || expandedSetting == .reveal,
                                appearance: .dark
                            ) { toggle(.reveal) }
                            HomeDivider(appearance: .dark)
                            HomeSettingRow(
                                icon: "photo", title: "Filter", value: filterStyle,
                                expanded: expandingRow == .filter || expandedSetting == .filter,
                                appearance: .dark
                            ) { toggle(.filter) }
                            HomeDivider(appearance: .dark)
                            HomeSettingRow(
                                icon: "camera", title: "Photos per Person", value: "\(photosPerPerson) photos",
                                expanded: expandingRow == .photos || expandedSetting == .photos,
                                appearance: .dark
                            ) { toggle(.photos) }
                            HomeDivider(appearance: .dark)
                            HStack(spacing: 14) {
                                Image(systemName: "lock.open")
                                    .font(.satoshi(size: 17, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(width: 26)
                                Text("Guests can view gallery")
                                    .font(.satoshi(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.92))
                                Spacer()
                                Toggle("", isOn: $showGallery)
                                    .tint(Color.black)
                                    .labelsHidden()
                                    .scaleEffect(1.05)
                            }
                            .frame(height: 64)
                        }
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.18))
                        .padding(.top, 8)

                        // CTA
                        Group {
                            if hasCoverPhoto {
                                Button {
                                    showFinishUp = true
                                } label: {
                                    Text("Continue")
                                        .font(.satoshi(size: 17, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.black, in: RoundedRectangle(cornerRadius: 28))
                                }
                                .buttonStyle(.plain)
                            } else {
                                PhotosPicker(selection: $selectedCoverPhotoItem, matching: .images) {
                                    Text("Add a Photo to Continue")
                                        .font(.satoshi(size: 17, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 28))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 36)
                    }
                }
                .allowsHitTesting(expandedSetting == nil)

                // ── Dimmer ────────────────────────────────────────────────────
                if expandedSetting != nil {
                    Color.black.opacity(0.48)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                expandedSetting = nil
                            }
                        }
                }

                // ── Floating overlay panel ─────────────────────────────────
                if let setting = expandedSetting {
                    createOverlayPanel(setting: setting)
                        .padding(.horizontal, 14)
                        .padding(.bottom, safeBottom + 10)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82, anchor: .top)
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.94, anchor: .top)
                                .combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: expandedSetting != nil)
        }
    }

    private var formattedEnd: String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM • HH:mm"
        let tz = TimeZone.current.abbreviation() ?? "GMT"
        return "\(df.string(from: endDate)) \(tz)"
    }

    private func toggle(_ setting: ExpandedSetting) {
        guard expandingRow == nil else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            expandingRow = setting
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                expandedSetting = expandedSetting == setting ? nil : setting
                expandingRow = nil
            }
        }
    }

    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    coverDraft.image = image.coverEditorPreparedImage()
                }
                selectedCoverPhotoItem = nil
            }
        }
    }

    @ViewBuilder
    private func createOverlayPanel(setting: ExpandedSetting) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: panelIcon(for: setting))
                    .font(.satoshi(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(panelTitle(for: setting))
                        .font(.satoshi(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(panelValue(for: setting))
                        .font(.satoshi(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                    Text(panelDescription(for: setting))
                        .font(.satoshi(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        expandedSetting = nil
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.satoshi(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            HomeDivider()

            switch setting {
            case .ending:
                EndingCalendarSelector(selectedDate: $endDate, visibleMonth: $endDateVisibleMonth)
            case .reveal:
                panelPills(["Immediately", "At the end"], binding: $revealMode)
            case .filter:
                HStack(spacing: 12) {
                    Button { filterStyle = "None" } label: {
                        CompactFilterCard(title: "None", selected: filterStyle == "None", warm: false)
                    }.buttonStyle(.plain)
                    Button { filterStyle = "Disposable film" } label: {
                        CompactFilterCard(title: "Disposable Film", selected: filterStyle == "Disposable film", warm: true)
                    }.buttonStyle(.plain)
                }
            case .photos:
                panelPills(["5", "10", "15", "20", "25"], binding: Binding(
                    get: { "\(photosPerPerson)" },
                    set: { photosPerPerson = Int($0) ?? photosPerPerson }
                ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "#1D2027"), Color(hex: "#171922")],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.vertical, 8)
    }

    private func panelPills(_ options: [String], binding: Binding<String>) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { opt in
                Button { binding.wrappedValue = opt } label: {
                    SelectablePill(opt, selected: binding.wrappedValue == opt)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func panelIcon(for setting: ExpandedSetting) -> String {
        switch setting {
        case .ending: return "calendar"
        case .reveal: return "hourglass"
        case .filter: return "photo"
        case .photos: return "camera"
        }
    }

    private func panelTitle(for setting: ExpandedSetting) -> String {
        switch setting {
        case .ending: return "Ending"
        case .reveal: return "Reveal Photos"
        case .filter: return "Filter"
        case .photos: return "Photos per Person"
        }
    }

    private func panelValue(for setting: ExpandedSetting) -> String {
        switch setting {
        case .ending: return formattedEnd
        case .reveal: return revealMode
        case .filter: return filterStyle
        case .photos: return "\(photosPerPerson) photos"
        }
    }

    private func panelDescription(for setting: ExpandedSetting) -> String {
        switch setting {
        case .ending: return "Choose when the camera locks for submissions."
        case .reveal: return "Set when photos become visible in the gallery."
        case .filter: return "Set the visual style for Tetamu photos."
        case .photos: return "Set how many photos each guest can capture."
        }
    }

    // MARK: Finish Up sheet

    private var finishUpSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showFinishUp = false } label: {
                    Image(systemName: "chevron.down")
                        .font(.satoshi(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Finish Up")
                    .font(.satoshi(size: 20, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button { } label: {
                    Image(systemName: "questionmark")
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.top, 16)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How many participants?")
                        .font(.satoshi(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Pricing scales for more guests")
                        .font(.satoshi(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("Up to \(guestLimit)")
                    .font(.satoshi(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Tier picker
            HStack(spacing: 6) {
                ForEach(guestTiers.indices, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(idx <= guestTierIndex ? Color.black : Color.white.opacity(0.12))
                        .frame(height: 48)
                        .onTapGesture { guestTierIndex = idx }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

//            HStack {
//                Text("Price")
//                    .font(.satoshi(size: 15, weight: .medium))
//                    .foregroundStyle(.white.opacity(0.6))
//                Spacer()
//                Text(guestTierIndex == 0 ? "FREE" : "$\(guestTierIndex * 5)")
//                    .font(.satoshi(size: 15, weight: .black))
//                    .foregroundStyle(guestTierIndex == 0 ? Color.black : .white)
//            }
//            .padding(.horizontal, 20)
//            .padding(.top, 14)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    showFinishUp = false
                } label: {
                    Text("Preview")
                        .font(.satoshi(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)

                Button {
                    publishEvent()
                } label: {
                    if isPublishing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Publish")
                            .font(.satoshi(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 26))
                .buttonStyle(.plain)
                .disabled(isPublishing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color(hex: "#18191F"))
    }

    // MARK: Publish

    private func publishEvent() {
        guard !isPublishing else { return }
        isPublishing = true

        let name = eventName.trimmingCharacters(in: .whitespaces)
        let hostName = hostFirstName.isEmpty ? "Host" : hostFirstName
        let filterRaw = filterStyle == "Disposable film" ? "vintage" : "none"
        let revealRaw = revealMode == "Immediately" ? "Immediately" : "At the end"
        let startDate = Date()
        let durationHours = max(1, Int(endDate.timeIntervalSince(startDate) / 3600))

        Task {
            do {
                let event = try await SupabaseManager.shared.createEvent(
                    title: name,
                    hostName: hostName,
                    location: "",
                    startsAt: startDate,
                    durationHours: durationHours,
                    shotsPerGuest: photosPerPerson,
                    guestLimit: guestLimit,
                    allowVoiceNotes: true,
                    voiceNoteMaxSeconds: 120,
                    filterStyle: filterRaw,
                    revealMode: revealRaw
                )

                _ = try? await SupabaseManager.shared.addGuest(
                    eventId: event.id,
                    name: hostName,
                    role: "organizer"
                )

                var coverImageUrl: String? = nil
                if let img = coverDraft.image,
                   let jpeg = img.jpegData(compressionQuality: 0.85) {
                    coverImageUrl = try? await SupabaseManager.shared.uploadCoverImage(
                        eventId: event.id,
                        jpegData: jpeg
                    )
                }

                let dict: [String: Any] = [
                    "eventId": event.id,
                    "eventName": event.title,
                    "userName": hostName,
                    "location": event.location,
                    "duration": event.duration_hours,
                    "reveal": event.reveal_mode,
                    "numberOfPhotos": event.shots_per_guest,
                    "guestLimit": event.guest_limit,
                    "allowVoiceNotes": event.allow_voice_notes,
                    "voiceNoteMaxSeconds": event.voice_note_max_seconds,
                    "filterStyle": event.filter_style,
                    "startTime": startDate.timeIntervalSince1970,
                    "endDate": endDate.timeIntervalSince1970,
                    "coverImageUrl": coverImageUrl ?? "",
                    "coverStyle": coverDraft.style.rawValue,
                    "coverTitle": coverDraft.title,
                    "coverSubtitle": coverDraft.subtitle,
                    "coverButtonTitle": coverDraft.buttonTitle
                ]

                await MainActor.run {
                    isPublishing = false
                    showFinishUp = false
                    onPublish(dict, coverDraft)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    print("Publish error: \(error)")
                }
            }
        }
    }
}
