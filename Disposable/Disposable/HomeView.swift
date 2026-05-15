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
    @State private var isHomeModalPresented = false
    @State private var currentHomeModal: HomeDashboardModal = .details
    @State private var homeModalMeasuredHeight: CGFloat = 640

    @State private var eventEndTime: Date = Date()
    @State private var revealSetting: String = "Immediately"
    @State private var homeEventName = "Rizhan's House Party"
    @State private var phoneShowingBack = false
    @State private var hasInitializedDashboardControls = false
    @State private var selectedGuestLimit = 10
    @State private var selectedPhotosPerPerson = 10
    @State private var selectedRevealOption = "12 hours after"
    @State private var selectedFilterOption = "Disposable film"
    @State private var selectedShareTemplate: QRShareTemplateStyle = .plain
    @State private var selectedShareBackground: QRShareBackground = .warm
    @State private var selectedShareQRColor: QRShareColor = .black

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
            subtitle: subtitle(for: data),
            statusText: dashboardStatusText(for: data),
            phoneShowingBack: $phoneShowingBack,
            scheduleAction: { presentHomeModal(.details) },
            instantAction: { presentHomeModal(.details) },
            galleryAction: { presentHomeModal(.details) },
            cameraAction: { presentHomeModal(.details) },
            editAction: { presentHomeModal(.details) },
            qrAction: { presentHomeModal(.share) },
            shareAction: { presentHomeModal(.share) }
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { showEndEventAlert = true }) {
                Image(systemName: "xmark")
                    .font(.satoshi(.headline, weight: .bold))
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
            eventName: homeEventName,
            subtitle: "Share with friends!",
            statusText: "Up to 10 Guests • Ends 23 May at 23:59",
            phoneShowingBack: $phoneShowingBack,
            scheduleAction: { presentHomeModal(.details) },
            instantAction: { presentHomeModal(.details) },
            galleryAction: { presentHomeModal(.details) },
            cameraAction: { presentHomeModal(.details) },
            editAction: { presentHomeModal(.details) },
            qrAction: { presentHomeModal(.share) },
            shareAction: { presentHomeModal(.share) }
        )
    }

    @ViewBuilder
    private func homeModalView(for modal: HomeDashboardModal) -> some View {
        ZStack(alignment: .bottom) {
            HomeEventDetailsSheet(
                summary: dashboardSummary(),
                eventName: $homeEventName,
                saveEventNameAction: saveEventName
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
            return 780
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
              let startTime = data["startTime"] as? Timestamp else {
            return "Sat 23 May • 23:59 GMT+8"
        }

        let endDate = startTime.dateValue().addingTimeInterval(TimeInterval(duration * 3600))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • HH:mm"
        return "\(formatter.string(from: endDate)) GMT+8"
    }

    private func dashboardStatusText(for data: [String: Any]) -> String {
        let guestLimit = data["guestLimit"] as? Int ?? selectedGuestLimit
        guard let duration = data["duration"] as? Int,
              let startTime = data["startTime"] as? Timestamp else {
            return "Up to \(guestLimit) Guests • Ends 23 May at 23:59"
        }

        let endDate = startTime.dateValue().addingTimeInterval(TimeInterval(duration * 3600))
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
            syncHomeEventName()
        }
    }

    private func syncHomeEventName() {
        if let storedName = eventData?["eventName"] as? String,
           !storedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            homeEventName = storedName
        } else if homeEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            homeEventName = "Rizhan's House Party"
        }
    }

    private func saveEventName(_ newValue: String) {
        let trimmedName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Rizhan's House Party" : trimmedName

        homeEventName = resolvedName
        eventData?["eventName"] = resolvedName
        persistCurrentEventDataLocally()

        guard let eventId = eventData?["eventId"] as? String else { return }
        Firestore.firestore().collection("events").document(eventId).updateData([
            "eventName": resolvedName
        ])
    }

    private func persistCurrentEventDataLocally() {
        guard let eventData else { return }

        var serializable = eventData
        if let timestamp = serializable["startTime"] as? Timestamp {
            serializable["startTime"] = timestamp.dateValue().timeIntervalSince1970
        }

        guard let encodedData = try? JSONSerialization.data(withJSONObject: serializable, options: []) else { return }
        UserDefaults.standard.set(encodedData, forKey: "currentEventData")
        UserDefaults.standard.set(isInEvent, forKey: "isInEvent")
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
    let saveEventNameAction: (String) -> Void
    let selectAction: (HomeDashboardModal) -> Void
    let dismissAction: () -> Void

    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @FocusState private var titleFieldFocused: Bool
    @State private var guestsCanViewGallery = true
    @State private var expandingSelection: HomeDashboardModal?
    @State private var inlineExpandedSelection: HomeDashboardModal?

    var body: some View {
        ZStack(alignment: .bottom) {
            HomeSheetContainer {
                VStack(spacing: 10) {
                HStack {
                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.satoshi(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.09), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 12) {
                        if isEditingTitle {
                            TextField("Event name", text: $titleDraft)
                                .font(.satoshi(size: 22, weight: .black))
                                .foregroundStyle(.white)
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
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        if isEditingTitle {
                            Button(action: commitTitleEdit) {
                                Image(systemName: "checkmark")
                                    .font(.satoshi(.headline, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 34)
                                    .background(Color(hex: "#574BE7"), in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)

                            Button(action: cancelTitleEdit) {
                                Image(systemName: "xmark")
                                    .font(.satoshi(.headline, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 38, height: 34)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: beginTitleEdit) {
                                Image(systemName: "pencil")
                                    .font(.satoshi(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .frame(width: 46, height: 30)
                                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.satoshi(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                }

                HomeDetailsCoverSection(
                    summary: summary,
                    editAction: beginTitleEdit,
                    photoAction: {}
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
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(width: 34)

                    Text("Guests can view gallery")
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer()

                    Toggle("", isOn: $guestsCanViewGallery)
                        .labelsHidden()
                        .tint(Color(hex: "#5C55E8"))
                        .scaleEffect(1.05)
                }
                .frame(height: 64)
                .padding(.top, 2)
                }
                .padding(.bottom, 10)
            }
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if inlineExpandedSelection == nil {
                    VStack(spacing: 0) {
                        Button(action: dismissAction) {
                            Text("Dismiss")
                                .font(.satoshi(size: 18, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 26))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1.2)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#15161E"), Color(hex: "#101119")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
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
        }
        .onAppear {
            titleDraft = eventName
        }
        .onChange(of: eventName) { _, newValue in
            if !isEditingTitle {
                titleDraft = newValue
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
            expanded: expandingSelection == selection || inlineExpandedSelection == selection
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

            HomeDivider()
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
            return "Set the visual style for POV Camera photos."
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

    private var priceText: String {
        selectedLimit == 10 ? "FREE" : "$\(max(selectedIndex, 1) * 5)"
    }

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

                Spacer()

                Text(priceText)
                    .font(.satoshi(size: 18, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.62))
            }

            if selectedLimit > 10 {
                Text("Each increase unlocks a larger guest tier and requires payment before publishing.")
                    .font(.satoshi(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        ZStack {
            LinearGradient(
                colors: selectedBackground.colors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                .padding(.top, 10)

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
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 430)

                Spacer(minLength: 14)

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
                    .background(Color(hex: "#574BE7"), in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
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
                RoundedRectangle(cornerRadius: isExport ? 7 : 3)
                    .fill(template == .midnight ? Color.white : Color.black)
                    .frame(width: isExport ? 34 : 13, height: isExport ? 34 : 13)
                Text("pov")
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
            Image(uiImage: qrCodeImage.withRenderingMode(.alwaysTemplate))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .foregroundStyle(qrColor.color)
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

private struct HomeDetailsCoverSection: View {
    let summary: HomeEventSummary
    let editAction: () -> Void
    let photoAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: "#887B6E"), Color(hex: "#5A5858")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
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

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .zIndex(1)

                ZStack {
                    Phone3DSceneView(
                        eventName: summary.eventName,
                        angle: 180,
                        warmReflection: false
                    )
                    .frame(width: 218, height: 258)
                    .offset(x: 6)

                    HStack {
                        Spacer()

                        VStack(spacing: 18) {
                            detailCoverTool(icon: "pencil", title: "Edit", action: editAction)
                            detailCoverTool(icon: "photo", title: "Photo", action: photoAction)
                        }
                        .padding(.trailing, 12)
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 252)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func detailCoverTool(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct HomeSheetContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, max(proxy.safeAreaInsets.top - 8, 6))
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#1B1D26"), Color(hex: "#15161E")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 28)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
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
                        .fill(index < filledSegments ? Color(hex: "#574BE7") : Color.white.opacity(0.12))
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
    let icon: String
    let title: String
    let value: String
    let expanded: Bool
    let action: () -> Void

    init(icon: String, title: String, value: String, expanded: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.expanded = expanded
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.satoshi(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.satoshi(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(value)
                        .font(.satoshi(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.satoshi(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.horizontal, expanded ? 12 : 0)
            .frame(height: expanded ? 76 : 58)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(expanded ? Color.white.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(expanded ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(expanded ? 1.015 : 1, anchor: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: expanded)
    }
}

private struct HomeDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.055))
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
                    Text("pov")
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

private struct POVDashboardLayout: View {
    let eventName: String
    let subtitle: String
    let statusText: String
    @Binding var phoneShowingBack: Bool
    let scheduleAction: () -> Void
    let instantAction: () -> Void
    let galleryAction: () -> Void
    let cameraAction: () -> Void
    let editAction: () -> Void
    let qrAction: () -> Void
    let shareAction: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var phoneRestingAngle: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = max(CGFloat(574), proxy.size.height - 256)
            let phoneHeight = min(CGFloat(368), max(CGFloat(302), heroHeight * 0.55))
            let topInset = max(proxy.safeAreaInsets.top, 18)

            VStack(spacing: 12) {
                homeHeroCard(phoneHeight: phoneHeight)
                    .frame(height: heroHeight)

                VStack(spacing: 12) {
                    Button(action: scheduleAction) {
                        actionRow(
                            icon: "calendar.badge.plus",
                            title: "Schedule a POV Camera",
                            subtitle: "For weddings, parties, & planned events",
                            background: Color(hex: "#5C55E8"),
                            foreground: .white
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: instantAction) {
                        actionRow(
                            icon: "bolt.fill",
                            title: "Instant POV Camera",
                            subtitle: "For right now! Start your POV immediately",
                            background: Color(hex: "#41454D"),
                            foreground: .white
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                bottomBar
                    .padding(.horizontal, 12)
            }
            .padding(.top, topInset + 40)
            .padding(.bottom, 4)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(Color(hex: "#11120D"))
        }
        .background(Color(hex: "#11120D"))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            phoneRestingAngle = 180
            phoneShowingBack = true
            dragOffset = 0
        }
    }

    @ViewBuilder
    private func homeHeroCard(phoneHeight: CGFloat) -> some View {
        let heroGradient = LinearGradient(
            colors: [Color(hex: "#8C8073"), Color(hex: "#69635F"), Color(hex: "#555152")],
            startPoint: .top,
            endPoint: .bottom
        )

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
            .padding(.top, 10)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 22)

            Text(subtitle)
                .font(.satoshi(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)

            SwipeablePhoneMockup(
                eventName: eventName,
                showingBack: $phoneShowingBack,
                dragOffset: $dragOffset,
                restingAngle: $phoneRestingAngle
            )
            .frame(height: phoneHeight)
            .padding(.top, 18)

            Text(statusText)
                .font(.satoshi(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                dashboardToolButton(systemName: "camera", action: cameraAction)
                dashboardToolButton(systemName: "square.and.arrow.up", action: shareAction)
                dashboardToolButton(systemName: "qrcode", action: qrAction)
            }
            .padding(.top, 18)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 34))
        .overlay(
            RoundedRectangle(cornerRadius: 34)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
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

    private func actionRow(icon: String, title: String, subtitle: String, background: Color, foreground: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.satoshi(size: 26, weight: .bold))
                .frame(width: 30)
                .foregroundStyle(foreground.opacity(0.72))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.satoshi(size: 20, weight: .bold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                Text(subtitle)
                    .font(.satoshi(size: 16, weight: .medium))
                    .foregroundStyle(foreground.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.satoshi(size: 19, weight: .bold))
                .foregroundStyle(foreground.opacity(0.74))
        }
        .padding(.horizontal, 20)
        .frame(height: 66)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            bottomTabIcon("plus.square", selected: true)
            bottomTabIcon("camera", selected: false)
            bottomTabIcon("gearshape", selected: false)
        }
        .frame(height: 68)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background(Color(hex: "#11120D"))
    }

    private func bottomTabIcon(_ systemName: String, selected: Bool) -> some View {
        Image(systemName: systemName)
            .font(.satoshi(size: 28, weight: .medium))
            .foregroundStyle(selected ? Color(hex: "#8A84FF") : Color.white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(hex: "#302E59"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color(hex: "#5C55E8").opacity(0.35), lineWidth: 1)
                            )
                    }
                }
            )
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
            let modelHalfDepth = normalizeModel(wrapper)
            attachCameraScreenTexture(to: wrapper)
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

        private func attachCameraScreenTexture(to root: SCNNode) {
            let screenImage = cameraScreenImage()
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
                        material.isDoubleSided = false
                        material.writesToDepthBuffer = false
                        material.readsFromDepthBuffer = false
                        material.lightingModel = .constant
                        displayPlane.materials = [material]

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
            material.diffuse.contents = cameraScreenImage()
            material.emission.contents = UIColor.black
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

        private func cameraScreenImage() -> UIImage {
            if let url = Bundle.main.url(forResource: "CameraScreenMockup", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }

            return UIImage(named: "CameraScreenMockup") ?? cameraScreenTexture()
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
