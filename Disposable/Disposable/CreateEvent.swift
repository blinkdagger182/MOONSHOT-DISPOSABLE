import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct CreateEventView: View {
    @Binding var isInEvent: Bool
    @Binding var eventData: [String: Any]?

    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable {
        case details
        case settings
        case share
    }

    @State private var step: Step = .details

    @State private var hostName: String = ""
    @State private var eventName: String = "Aisyah & Hakim's Wedding"
    @State private var locationName: String = "Kuala Lumpur, Malaysia"
    @State private var eventDate: Date = Date()
    @State private var durationHours: Int = 24

    @State private var filterStyle: String = "none"
    @State private var showFilterModal: Bool = false

    @State private var guestLimit: Int = 120
    @State private var allowVoiceNotes: Bool = true
    @State private var voiceNoteMaxSeconds: Int = 120
    @State private var revealMode: String = "At the end"
    @State private var shotsPerGuest: Int = 25

    @State private var hasAcceptedTerms: Bool = false

    @State private var createdEventId: String?
    @State private var createdEventLink: String?
    @State private var selectedCardIndex: Int = 0

    @State private var isSaving = false

    private let cardThemes: [QRTheme] = [
        QRTheme(name: "Classic", top: UIColor(red: 0.11, green: 0.13, blue: 0.2, alpha: 1), bottom: UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1), accent: UIColor(red: 0.92, green: 0.84, blue: 0.69, alpha: 1)),
        QRTheme(name: "Rose Night", top: UIColor(red: 0.24, green: 0.1, blue: 0.18, alpha: 1), bottom: UIColor(red: 0.06, green: 0.02, blue: 0.08, alpha: 1), accent: UIColor(red: 0.98, green: 0.75, blue: 0.82, alpha: 1)),
        QRTheme(name: "Emerald", top: UIColor(red: 0.07, green: 0.22, blue: 0.2, alpha: 1), bottom: UIColor(red: 0.02, green: 0.08, blue: 0.09, alpha: 1), accent: UIColor(red: 0.76, green: 0.94, blue: 0.9, alpha: 1))
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0E1022"), Color(hex: "#0A0B14")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                progressDots

                Group {
                    switch step {
                    case .details:
                        detailsStep
                    case .settings:
                        settingsStep
                    case .share:
                        shareStep
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if showFilterModal {
                filterModal
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button(action: {
                if step == .details {
                    dismiss()
                } else if step == .settings {
                    step = .details
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .opacity(step == .share ? 0 : 1)

            Spacer()

            Text(titleForStep(step))
                .font(.satoshi(.headline, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color(hex: "#E8D7FF") : Color.white.opacity(0.22))
                    .frame(width: item == step ? 28 : 10, height: 8)
            }
        }
        .padding(.bottom, 4)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Details")
                            .font(.satoshi(.title3, weight: .bold))
                            .foregroundColor(.white)

                        textField(title: "Host Name", text: $hostName, placeholder: "e.g. Riz")
                        textField(title: "Event Name", text: $eventName, placeholder: "e.g. Aisyah & Hakim's Wedding")
                        textField(title: "Location", text: $locationName, placeholder: "e.g. Kuala Lumpur, Malaysia")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date")
                                .foregroundColor(.white.opacity(0.8))
                            DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .tint(.white)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("How Long")
                                .foregroundColor(.white.opacity(0.8))
                            Picker("Duration", selection: $durationHours) {
                                Text("12h").tag(12)
                                Text("24h").tag(24)
                                Text("48h").tag(48)
                                Text("72h").tag(72)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Filter Style")
                            .font(.satoshi(.headline, weight: .bold))
                            .foregroundColor(.white)

                        Button(action: { showFilterModal = true }) {
                            HStack {
                                Text(filterStyle == "vintage" ? "Vintage" : "None")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Text("Vintage applies a warm film effect to photos taken in the event.")
                            .font(.satoshi(.footnote))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                primaryButton(title: "Continue to Event Settings", disabled: hostName.trimmingCharacters(in: .whitespaces).isEmpty || eventName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    step = .settings
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var settingsStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Settings")
                            .font(.satoshi(.title3, weight: .bold))
                            .foregroundColor(.white)

                        stepperRow(title: "How many people", value: $guestLimit, range: 10...500)
                        stepperRow(title: "Shots per guest", value: $shotsPerGuest, range: 5...50)

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $allowVoiceNotes) {
                                Text("Allow voice notes")
                                    .foregroundColor(.white)
                            }
                            .tint(Color(hex: "#E8D7FF"))

                            if allowVoiceNotes {
                                stepperRow(title: "Max length (seconds)", value: $voiceNoteMaxSeconds, range: 30...180)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reveal setting")
                                .foregroundColor(.white.opacity(0.85))
                            Picker("", selection: $revealMode) {
                                Text("Immediately").tag("Immediately")
                                Text("At the end").tag("At the end")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                Toggle(isOn: $hasAcceptedTerms) {
                    Text("I accept Terms and Privacy")
                        .foregroundColor(.white.opacity(0.85))
                }
                .tint(Color(hex: "#E8D7FF"))
                .padding(.horizontal, 4)

                primaryButton(title: isSaving ? "Creating..." : "Create Event", disabled: !hasAcceptedTerms || isSaving) {
                    Task { await createEvent() }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var shareStep: some View {
        VStack(spacing: 14) {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share your event")
                        .font(.satoshi(.title3, weight: .bold))
                        .foregroundColor(.white)
                    Text("Guests can scan to join. No app required.")
                        .foregroundColor(.white.opacity(0.75))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(cardThemes.indices, id: \.self) { index in
                                qrCard(theme: cardThemes[index])
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(index == selectedCardIndex ? Color.white : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture { selectedCardIndex = index }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Swipe to browse styles")
                        .font(.satoshi(.footnote))
                        .foregroundColor(.white.opacity(0.65))
                }
            }

            HStack(spacing: 10) {
                shareButton(title: "WhatsApp") { shareSelectedQR() }
                shareButton(title: "Instagram") { shareSelectedQR() }
                shareButton(title: "Messages") { shareSelectedQR() }
                shareButton(title: "More") { shareSelectedQR() }
            }

            primaryButton(title: "Finish and Open Dashboard", disabled: createdEventId == nil) {
                dismiss()
            }
        }
    }

    private var filterModal: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { showFilterModal = false }

            VStack(alignment: .leading, spacing: 10) {
                Text("Select filter style")
                    .font(.satoshi(.headline, weight: .bold))
                    .foregroundColor(.white)

                filterOption(title: "None", value: "none")
                filterOption(title: "Vintage", value: "vintage")
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(Color(hex: "#1A1E31"), in: RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
        .zIndex(99)
    }

    private func filterOption(title: String, value: String) -> some View {
        Button(action: {
            filterStyle = value
            showFilterModal = false
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                if filterStyle == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#E8D7FF"))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func createEvent() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let event = try await SupabaseManager.shared.createEvent(
                title: eventName.trimmingCharacters(in: .whitespacesAndNewlines),
                hostName: hostName.trimmingCharacters(in: .whitespacesAndNewlines),
                location: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                startsAt: eventDate,
                durationHours: durationHours,
                shotsPerGuest: shotsPerGuest,
                guestLimit: guestLimit,
                allowVoiceNotes: allowVoiceNotes,
                voiceNoteMaxSeconds: voiceNoteMaxSeconds,
                filterStyle: filterStyle,
                revealMode: revealMode
            )
            _ = try await SupabaseManager.shared.addGuest(
                eventId: event.id,
                name: hostName.trimmingCharacters(in: .whitespacesAndNewlines),
                role: "organizer"
            )
            await MainActor.run {
                isInEvent = true
                eventData = eventToDict(event)
                createdEventId = event.id
                createdEventLink = "https://tetamu.app/clip?eventId=\(event.id)"
                saveEventState()
                step = .share
            }
        } catch {
            print("Create event failed: \(error.localizedDescription)")
        }
    }

    private func eventToDict(_ e: SupabaseEvent) -> [String: Any] {
        [
            "eventId": e.id,
            "eventName": e.title,
            "userName": e.host_name,
            "location": e.location,
            "duration": e.duration_hours,
            "reveal": e.reveal_mode,
            "numberOfPhotos": e.shots_per_guest,
            "guestLimit": e.guest_limit,
            "allowVoiceNotes": e.allow_voice_notes,
            "voiceNoteMaxSeconds": e.voice_note_max_seconds,
            "filterStyle": e.filter_style,
            "startTime": ISO8601DateFormatter().date(from: e.starts_at)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        ]
    }

    private func saveEventState() {
        if let eventData = eventData {
            if let savedData = try? JSONSerialization.data(withJSONObject: eventData, options: []) {
                UserDefaults.standard.set(savedData, forKey: "currentEventData")
                UserDefaults.standard.set(true, forKey: "isInEvent")
            }
        }
    }

    private func generateQRImage(for string: String, size: CGFloat = 300) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "Q"

        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func renderQRCard(theme: QRTheme) -> UIImage? {
        guard let link = createdEventLink,
              let qrImage = generateQRImage(for: link, size: 220) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 290, height: 430))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: 290, height: 430)

            let cgColors = [theme.top.cgColor, theme.bottom.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 430), options: [])

            let title = NSString(string: eventName)
            title.draw(in: CGRect(x: 18, y: 24, width: 254, height: 52), withAttributes: [
                .font: UIFont.satoshi(size: 26, weight: .bold),
                .foregroundColor: theme.accent
            ])

            let subtitle = NSString(string: "Scan to join")
            subtitle.draw(in: CGRect(x: 18, y: 66, width: 200, height: 24), withAttributes: [
                .font: UIFont.satoshi(size: 15, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ])

            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(x: 35, y: 110, width: 220, height: 220), cornerRadius: 18).fill()
            qrImage.draw(in: CGRect(x: 50, y: 125, width: 190, height: 190))

            let footer = NSString(string: "tetamu.app")
            footer.draw(in: CGRect(x: 18, y: 350, width: 254, height: 30), withAttributes: [
                .font: UIFont.satoshi(size: 16, weight: .medium),
                .foregroundColor: UIColor.white
            ])
        }
    }

    private func shareSelectedQR() {
        guard selectedCardIndex < cardThemes.count,
              let cardImage = renderQRCard(theme: cardThemes[selectedCardIndex]),
              let link = createdEventLink else { return }

        let message = "Join my event on Tetamu: \(link)"
        let activityVC = UIActivityViewController(activityItems: [message, cardImage], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func titleForStep(_ step: Step) -> String {
        switch step {
        case .details: return "Create Event"
        case .settings: return "Event Settings"
        case .share: return "Share your event"
        }
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            .frame(width: 120)
            .tint(Color(hex: "#E8D7FF"))
        }
    }

    private func textField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundColor(.white.opacity(0.8))
            TextField(placeholder, text: text)
                .padding(12)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(16)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func primaryButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(disabled ? .white.opacity(0.65) : Color(hex: "#09121E"))
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(disabled ? Color.white.opacity(0.15) : Color(hex: "#E8D7FF"), in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(disabled)
    }

    private func shareButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.satoshi(.footnote, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func qrCard(theme: QRTheme) -> some View {
        ZStack {
            LinearGradient(colors: [Color(theme.top), Color(theme.bottom)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 8) {
                Text(theme.name)
                    .font(.satoshi(.footnote, weight: .bold))
                    .foregroundColor(Color(theme.accent))
                if let image = renderQRCard(theme: theme) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170, height: 250)
                }
            }
            .padding(10)
        }
        .frame(width: 190, height: 280)
    }
}

private struct QRTheme {
    let name: String
    let top: UIColor
    let bottom: UIColor
    let accent: UIColor
}
