//
//  SettingsView.swift
//  Disposable
//
//  Created by Clementine CUREL on 11/01/2025.
//

import SwiftUI

private enum SettingsRoute: Hashable {
    case profile
    case faq
    case contact
    case privacy
    case language
    case appIcon
    case interests
    case supportCodes
    case accountDeletion
    case faqAnswer(FAQItem)
}

private enum SettingsSheet: Identifiable {
    case purpose

    var id: String {
        switch self {
        case .purpose: return "purpose"
        }
    }
}

struct SettingsView: View {
    @Binding var isInEvent: Bool
    @Binding var eventData: [String: Any]?
    let openHomeTab: () -> Void
    let openCameraTab: () -> Void

    @AppStorage("profileName") private var profileName = "Rizhan Ruslan"
    @AppStorage("profileUsername") private var profileUsername = "rizhan"
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: SettingsSheet?
    @State private var alert: SettingsAlert?

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                SettingsScreen(
                    profileName: profileName,
                    profileUsername: profileUsername,
                    openProfile: openProfile,
                    openRoute: openRoute,
                    openSheet: openSheet,
                    clearCache: clearCache,
                    openExternalURL: openExternalURL
                )
                .navigationDestination(for: SettingsRoute.self, destination: destination)
                .sheet(item: $activeSheet, content: sheetContent)
                .alert(item: $alert, content: alertContent)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
            }

            AppBottomTabBar(
                selectedTab: .settings,
                homeAction: openHomeTab,
                cameraAction: openCameraTab,
                settingsAction: {}
            )
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func destination(_ route: SettingsRoute) -> some View {
        switch route {
        case .profile:
            ProfileSettingsView(
                profileName: $profileName,
                profileUsername: profileUsername,
                openRoute: openRoute,
                openSheet: openSheet,
                logOut: confirmLogOut
            )
        case .faq:
            FAQSettingsView(openAnswer: { navigationPath.append(SettingsRoute.faqAnswer($0)) })
        case .contact:
            ContactOptionsView(openExternalURL: openExternalURL) {
                navigationPath.append(SettingsRoute.profile)
            }
        case .privacy:
            PrivacySettingsView()
        case .language:
            LanguageSettingsView()
        case .appIcon:
            AppIconSettingsView()
        case .interests:
            InterestSettingsView(openPurposeSheet: { activeSheet = .purpose })
        case .supportCodes:
            SupportCodesView()
        case .accountDeletion:
            AccountDeletionView(openExternalURL: openExternalURL)
        case .faqAnswer(let item):
            FAQAnswerView(item: item)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: SettingsSheet) -> some View {
        switch sheet {
        case .purpose:
            PurposeSheetView()
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    private func openProfile() {
        navigationPath.append(SettingsRoute.profile)
    }

    private func openRoute(_ route: SettingsRoute) {
        navigationPath.append(route)
    }

    private func openSheet(_ sheet: SettingsSheet) {
        activeSheet = sheet
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.removeObject(forKey: "currentEventData")
        alert = SettingsAlert(title: "Cache Cleared", message: "Temporary cached data has been removed.")
    }

    private func confirmLogOut() {
        alert = SettingsAlert(
            title: "Log Out?",
            message: "This will leave the current local session on this device.",
            primaryButton: .destructive(Text("Log Out"), action: logOut),
            secondaryButton: .cancel()
        )
    }

    private func logOut() {
        isInEvent = false
        eventData = nil
        UserDefaults.standard.removeObject(forKey: "isInEvent")
        UserDefaults.standard.removeObject(forKey: "currentEventData")
        navigationPath.removeLast(navigationPath.count)
    }

    private func openExternalURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        UIApplication.shared.open(url)
    }

    private func alertContent(_ alert: SettingsAlert) -> Alert {
        if let primaryButton = alert.primaryButton {
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: primaryButton,
                secondaryButton: alert.secondaryButton ?? .cancel()
            )
        }

        return Alert(
            title: Text(alert.title),
            message: Text(alert.message),
            dismissButton: .default(Text("OK"))
        )
    }
}

private struct SettingsScreen: View {
    let profileName: String
    let profileUsername: String
    let openProfile: () -> Void
    let openRoute: (SettingsRoute) -> Void
    let openSheet: (SettingsSheet) -> Void
    let clearCache: () -> Void
    let openExternalURL: (String) -> Void

    var body: some View {
        SettingsContainer(title: "Settings", showsBackButton: false) {
            VStack(spacing: 28) {
                Button(action: openProfile) {
                    ProfileSummaryCard(name: profileName, username: profileUsername)
                }
                .buttonStyle(.plain)

                SettingsSection(title: "Support") {
                    SettingsRow(icon: "questionmark", title: "FAQ") {
                        openRoute(.faq)
                    }
                    SettingsRow(icon: "message", title: "Contact Us") {
                        openRoute(.contact)
                    }
                }

                SettingsSection(title: "Data") {
                    SettingsRow(icon: "externaldrive.badge.xmark", title: "Clear Cache", action: clearCache)
                    SettingsRow(icon: "lock", title: "Privacy") {
                        openRoute(.privacy)
                    }
                }

                SettingsSection(title: "Get in Touch") {
                    SettingsRow(icon: "network", title: "Business Inquiries") {
                        openExternalURL("mailto:hello@pov.camera?subject=Business%20Inquiry")
                    }
                    SettingsRow(icon: "sparkles", title: "Jobs at POV") {
                        openExternalURL("https://pov.camera")
                    }
                }

                SettingsSection(title: "Language") {
                    SettingsRow(icon: "globe", title: "Language") {
                        openRoute(.language)
                    }
                }

                SettingsSection(title: "Customize") {
                    SettingsRow(icon: "app.badge", title: "App Icon") {
                        openRoute(.appIcon)
                    }
                }

                SocialLinksView(openExternalURL: openExternalURL)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
    }
}

private struct ProfileSettingsView: View {
    @Binding var profileName: String

    let profileUsername: String
    let openRoute: (SettingsRoute) -> Void
    let openSheet: (SettingsSheet) -> Void
    let logOut: () -> Void

    var body: some View {
        SettingsContainer(title: "Profile") {
            VStack(spacing: 28) {
                ProfileAvatar(size: 132)
                    .overlay(alignment: .bottomLeading) {
                        Button(action: {}) {
                            Image(systemName: "pencil")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(width: 62, height: 62)
                                .background(Color(hex: "#5954D8"), in: Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 5))
                        }
                        .buttonStyle(.plain)
                        .offset(x: -22, y: 8)
                    }

                SettingsCard {
                    HStack(spacing: 18) {
                        Image(systemName: "person")
                            .settingsIconStyle()
                        TextField("Name", text: $profileName)
                            .font(.satoshi(size: 21, weight: .medium))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.words)
                    }
                    .frame(height: 62)
                    .padding(.horizontal, 18)

                    SettingsDivider()

                    HStack(spacing: 18) {
                        Image(systemName: "at")
                            .settingsIconStyle(size: 32)
                        Text(profileUsername)
                            .font(.satoshi(size: 21, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.42))
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.white.opacity(0.34))
                    }
                    .frame(height: 62)
                    .padding(.horizontal, 18)
                }

                SettingsSection(title: "Account") {
                    SettingsRow(icon: "star", title: "Interests") {
                        openSheet(.purpose)
                    }
                    SettingsRow(icon: "rectangle.and.pencil.and.ellipsis", title: "Support Codes") {
                        openRoute(.supportCodes)
                    }
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out", action: logOut)
                }

                SettingsSection(title: "Delete") {
                    SettingsRow(icon: "trash", title: "Request Account Deletion") {
                        openRoute(.accountDeletion)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
    }
}

private struct ContactOptionsView: View {
    let openExternalURL: (String) -> Void
    let openProfile: () -> Void

    var body: some View {
        SettingsContainer(title: "Contact Us") {
            SettingsSection {
                SettingsRow(icon: "bubble.left", title: "Text", subtitle: "Recommended") {
                    openExternalURL("sms:+15551234567")
                }
                SettingsRow(icon: "envelope", title: "Email", subtitle: "Replies may take longer") {
                    openExternalURL("mailto:support@pov.camera?subject=POV%20Support")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct FAQSettingsView: View {
    let openAnswer: (FAQItem) -> Void

    var body: some View {
        SettingsContainer(title: "FAQ") {
            VStack(spacing: 30) {
                SettingsSection(title: "About POV") {
                    ForEach(FAQItem.about) { item in
                        SettingsRow(title: item.question) {
                            openAnswer(item)
                        }
                    }
                }

                SettingsSection(title: "My Events") {
                    ForEach(FAQItem.myEvents) { item in
                        SettingsRow(title: item.question) {
                            openAnswer(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
    }
}

private struct FAQAnswerView: View {
    let item: FAQItem

    var body: some View {
        SettingsContainer(title: "FAQ") {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.question)
                    .font(.satoshi(size: 23, weight: .bold))
                    .foregroundStyle(.white)

                Text(item.answer)
                    .font(.satoshi(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineSpacing(5)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
        }
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        SettingsContainer(title: "Privacy") {
            VStack(spacing: 24) {
                SettingsSection(title: "Legal") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsRowContent(icon: "lock", title: "Privacy Policy")
                    }
                    NavigationLink {
                        TermsAndConditionsView()
                    } label: {
                        SettingsRowContent(icon: "doc.text", title: "Terms and Conditions")
                    }
                }

                Text("POV stores event photos temporarily for each event and uses contact details only when you submit support requests.")
                    .font(.satoshi(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct LanguageSettingsView: View {
    @AppStorage("preferredLanguage") private var preferredLanguage = "English"

    private let languages = ["English", "Bahasa Malaysia", "Français", "Español"]

    var body: some View {
        SettingsContainer(title: "Language") {
            SettingsSection {
                ForEach(languages, id: \.self) { language in
                    Button {
                        preferredLanguage = language
                    } label: {
                        HStack {
                            SettingsRowContent(icon: "globe", title: language, showsChevron: false)
                            if preferredLanguage == language {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "#8D86FF"))
                                    .padding(.trailing, 18)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct AppIconSettingsView: View {
    @AppStorage("selectedAppIcon") private var selectedAppIcon = "Default"

    private let icons = ["Default", "Midnight", "Party"]

    var body: some View {
        SettingsContainer(title: "App Icon") {
            SettingsSection {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedAppIcon = icon
                    } label: {
                        HStack {
                            SettingsRowContent(icon: icon == "Default" ? "app.badge" : "circle.hexagongrid", title: icon, showsChevron: false)
                            if selectedAppIcon == icon {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "#8D86FF"))
                                    .padding(.trailing, 18)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct InterestSettingsView: View {
    let openPurposeSheet: () -> Void

    var body: some View {
        SettingsContainer(title: "Interests") {
            SettingsSection {
                SettingsRow(icon: "sparkles", title: "What do you use POV for?", action: openPurposeSheet)
                SettingsRow(icon: "camera", title: "Event Photography", action: {})
                SettingsRow(icon: "person.2", title: "Guest Sharing", action: {})
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct SupportCodesView: View {
    var body: some View {
        SettingsContainer(title: "Support Codes") {
            VStack(alignment: .leading, spacing: 12) {
                Text("No support codes yet.")
                    .font(.satoshi(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                Text("Codes attached to your account will appear here.")
                    .font(.satoshi(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
        }
    }
}

private struct AccountDeletionView: View {
    let openExternalURL: (String) -> Void

    var body: some View {
        SettingsContainer(title: "Delete Account") {
            VStack(alignment: .leading, spacing: 18) {
                Text("Request account deletion")
                    .font(.satoshi(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("Send a deletion request from the email address attached to your account. Support will confirm once the request has been processed.")
                    .font(.satoshi(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineSpacing(5)
                Button {
                    openExternalURL("mailto:support@pov.camera?subject=Account%20Deletion%20Request")
                } label: {
                    Text("Email Deletion Request")
                        .font(.satoshi(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "#5954D8"), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(22)
            .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
        }
    }
}

private struct PurposeSheetView: View {
    @AppStorage("povPurpose") private var povPurpose = "Personal Events"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Text("What do you want to use POV for?")
                .font(.satoshi(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                PurposeOption(
                    title: "Personal Events",
                    systemImage: "person.crop.square",
                    isSelected: povPurpose == "Personal Events"
                ) {
                    povPurpose = "Personal Events"
                    dismiss()
                }
                PurposeOption(
                    title: "Business Events",
                    systemImage: "camera.fill",
                    isSelected: povPurpose == "Business Events"
                ) {
                    povPurpose = "Business Events"
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#1D2226"))
    }
}

private struct PurposeOption: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(isSelected ? Color(hex: "#8D86FF") : .white)
                    .frame(height: 70)
                Text(title)
                    .font(.satoshi(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(hex: "#26282D"), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "#8D86FF") : Color.white.opacity(0.12), lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let showsBackButton: Bool
    @ViewBuilder let content: Content

    init(title: String, showsBackButton: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0E0C")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: title, showsBackButton: showsBackButton, dismiss: dismiss)

                ScrollView(showsIndicators: false) {
                    content
                        .padding(.top, 22)
                        .padding(.bottom, 116)
                }
            }
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let showsBackButton: Bool
    let dismiss: DismissAction

    var body: some View {
        ZStack {
            Text(title)
                .font(.satoshi(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            if showsBackButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 58, height: 58)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
        }
        .frame(height: 78)
        .padding(.top, 22)
    }
}

private struct ProfileSummaryCard: View {
    let name: String
    let username: String

    var body: some View {
        HStack(spacing: 18) {
            ProfileAvatar(size: 66)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.satoshi(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("@\(username)")
                    .font(.satoshi(size: 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.22))
        }
        .padding(.horizontal, 18)
        .frame(height: 82)
        .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct ProfileAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#11B5F5"), Color(hex: "#78E7FF"), Color(hex: "#F95BA5")],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(Color.white.opacity(0.78))
                .frame(width: size * 0.7, height: size * 0.28)
                .overlay {
                    Text("Rizhan")
                        .font(.satoshi(size: size * 0.16, weight: .italic))
                        .foregroundStyle(.black)
                }
                .rotationEffect(.degrees(-2))
        }
        .frame(width: size, height: size)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.satoshi(size: 14, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.36))
                    .padding(.leading, 24)
            }

            SettingsCard {
                content
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct SettingsRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let action: () -> Void

    init(icon: String? = nil, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)

        SettingsDivider()
    }
}

private struct SettingsRowContent: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let showsChevron: Bool

    init(icon: String? = nil, title: String, subtitle: String? = nil, showsChevron: Bool = true) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: 18) {
            if let icon {
                Image(systemName: icon)
                    .settingsIconStyle()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.satoshi(size: 20, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(.satoshi(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
            }

            Spacer(minLength: 14)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.24))
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: subtitle == nil ? 62 : 72)
        .contentShape(Rectangle())
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 78)
    }
}

private struct SocialLinksView: View {
    let openExternalURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SOCIALS")
                .font(.satoshi(size: 14, weight: .black))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.36))
                .padding(.leading, 24)

            HStack(spacing: 12) {
                SocialButton(title: "Instagram", icon: "camera.aperture") {
                    openExternalURL("https://www.instagram.com/pov.camera")
                }
                SocialButton(title: "X", icon: "xmark") {
                    openExternalURL("https://x.com/povcamera")
                }
                SocialButton(title: "TikTok", icon: "music.note") {
                    openExternalURL("https://www.tiktok.com/@pov.camera")
                }
            }
        }
    }
}

private struct SocialButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color(hex: "#191919"), in: RoundedRectangle(cornerRadius: 22))

                Text(title)
                    .font(.satoshi(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

enum AppBottomTabSelection {
    case home
    case camera
    case settings
}

struct AppBottomTabBar: View {
    let selectedTab: AppBottomTabSelection
    let homeAction: () -> Void
    let cameraAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            bottomButton("plus.square", isSelected: selectedTab == .home, action: homeAction)
            bottomButton("camera", isSelected: selectedTab == .camera, action: cameraAction)
            bottomButton("gearshape", isSelected: selectedTab == .settings, action: settingsAction)
        }
        .frame(height: 68)
        .padding(.horizontal, 34)
        .padding(.bottom, 12)
        .background(Color(hex: "#0D0E0C"))
    }

    private func bottomButton(_ systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.satoshi(size: 28, weight: .medium))
                .foregroundStyle(isSelected ? Color(hex: "#8A84FF") : Color.white.opacity(0.42))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(hex: "#302E59"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color(hex: "#5C55E8").opacity(0.35), lineWidth: 1)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }
}

private struct FAQItem: Hashable, Identifiable {
    let id: String
    let question: String
    let answer: String

    static let about = [
        FAQItem(
            id: "other-phones",
            question: "Does POV work for other phones too?",
            answer: "Yes. Guests can join from a supported mobile browser through the event link or QR code."
        ),
        FAQItem(
            id: "no-download",
            question: "How is it possible that guests don't have to download the app?",
            answer: "Guests open a lightweight camera experience from the event link, so they can capture photos without installing the full app."
        ),
        FAQItem(
            id: "without-internet",
            question: "Does POV work without internet?",
            answer: "An internet connection is needed to join events, sync photos, and publish galleries."
        ),
        FAQItem(
            id: "qr-code",
            question: "How do I get a QR code?",
            answer: "Create or open an event, then use the share tools from the event dashboard to show or send the QR code."
        ),
        FAQItem(
            id: "review-before-live",
            question: "Can I review photos before the gallery goes live?",
            answer: "Hosts can review event progress before reveal. Full moderation controls depend on the event setup."
        ),
        FAQItem(
            id: "advance-purchase",
            question: "Can I purchase in advance of my event?",
            answer: "Yes. You can prepare an event ahead of time and share the QR code when guests arrive."
        )
    ]

    static let myEvents = [
        FAQItem(
            id: "where-qr",
            question: "Where should I put my QR Codes?",
            answer: "Place QR codes where guests naturally pause: entry tables, bars, table cards, welcome signs, or event programs."
        ),
        FAQItem(
            id: "app-clip-card-photo",
            question: "Why is my event photo not showing in the App Clip Card?",
            answer: "The card image can take time to refresh. Confirm the event has a cover photo, then reopen the link after a short delay."
        )
    ]
}

private struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var primaryButton: Alert.Button?
    var secondaryButton: Alert.Button?
}

private extension Image {
    func settingsIconStyle(size: CGFloat = 27) -> some View {
        font(.system(size: size, weight: .regular))
            .foregroundStyle(Color.white.opacity(0.38))
            .frame(width: 34)
    }
}
