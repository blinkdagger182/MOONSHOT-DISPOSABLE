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
    case accountDeletion
    case faqAnswer(FAQItem)
}

struct SettingsView: View {
    @Binding var isInEvent: Bool
    @Binding var eventData: [String: Any]?
    let openHomeTab: () -> Void
    let openCameraTab: () -> Void

    @AppStorage("profileName") private var profileName = "Rizhan Ruslan"
    @AppStorage("profileUsername") private var profileUsername = "rizhan"
    @AppStorage("profileEmail") private var profileEmail = ""
    @State private var navigationPath = NavigationPath()
    @State private var alert: SettingsAlert?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    SettingsScreen(
                        profileName: profileName,
                        profileUsername: profileUsername,
                        openProfile: openProfile,
                        openRoute: openRoute,
                        clearCache: clearCache
                    )
                    .navigationDestination(for: SettingsRoute.self, destination: destination)
                    .alert(item: $alert, content: alertContent)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
                }

                AppBottomTabBar(
                    selectedTab: .settings,
                    safeBottom: proxy.safeAreaInsets.bottom,
                    homeAction: openHomeTab,
                    cameraAction: openCameraTab,
                    settingsAction: {}
                )
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func destination(_ route: SettingsRoute) -> some View {
        switch route {
        case .profile:
            ProfileSettingsView(
                profileName: $profileName,
                profileEmail: $profileEmail,
                profileUsername: profileUsername,
                openRoute: openRoute,
                logOut: confirmLogOut
            )
        case .faq:
            FAQSettingsView(openAnswer: { navigationPath.append(SettingsRoute.faqAnswer($0)) })
        case .contact:
            ContactOptionsView(openExternalURL: openExternalURL)
        case .privacy:
            PrivacySettingsView()
        case .accountDeletion:
            AccountDeletionView(
                profileName: profileName,
                profileUsername: profileUsername,
                profileEmail: profileEmail
            )
        case .faqAnswer(let item):
            FAQAnswerView(item: item)
        }
    }

    private func openProfile() {
        navigationPath.append(SettingsRoute.profile)
    }

    private func openRoute(_ route: SettingsRoute) {
        navigationPath.append(route)
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
    let clearCache: () -> Void

    var body: some View {
        SettingsContainer(title: "Settings", showsBackButton: false) {
            VStack(spacing: 20) {
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

                SettingsSection(title: "Legal") {
                    SettingsRow(icon: "lock", title: "Privacy Policy") {
                        openRoute(.privacy)
                    }
                }

                SettingsSection(title: "App") {
                    SettingsRow(icon: "externaldrive.badge.xmark", title: "Clear Cache", action: clearCache)
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

private struct ProfileSettingsView: View {
    @Binding var profileName: String
    @Binding var profileEmail: String

    let profileUsername: String
    let openRoute: (SettingsRoute) -> Void
    let logOut: () -> Void

    var body: some View {
        SettingsContainer(title: "Profile") {
            VStack(spacing: 20) {
                ProfileAvatar(size: 100)

                SettingsCard {
                    HStack(spacing: 14) {
                        Image(systemName: "person")
                            .settingsIconStyle()
                        TextField("Name", text: $profileName)
                            .font(.satoshi(size: 17, weight: .medium))
                            .foregroundStyle(.black)
                            .textInputAutocapitalization(.words)
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 16)

                    SettingsDivider()

                    HStack(spacing: 14) {
                        Image(systemName: "at")
                            .settingsIconStyle(size: 24)
                        Text(profileUsername)
                            .font(.satoshi(size: 17, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.5))
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.black.opacity(0.3))
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 16)

                    SettingsDivider()

                    HStack(spacing: 14) {
                        Image(systemName: "envelope")
                            .settingsIconStyle(size: 22)
                        TextField("Email", text: $profileEmail)
                            .font(.satoshi(size: 17, weight: .medium))
                            .foregroundStyle(.black)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                }

                SettingsSection(title: "Account") {
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out", action: logOut)
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

    var body: some View {
        SettingsContainer(title: "Contact Us") {
            SettingsSection {
                SettingsRow(icon: "bubble.left", title: "Text", subtitle: "Recommended") {
                    openExternalURL("sms:+60189089070")
                }
                SettingsRow(icon: "envelope", title: "Email", subtitle: "Replies may take longer") {
                    openExternalURL("mailto:support@tetamu.app")
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
            VStack(spacing: 24) {
                SettingsSection(title: "About Tetamu") {
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
            VStack(alignment: .leading, spacing: 14) {
                Text(item.question)
                    .font(.satoshi(size: 19, weight: .bold))
                    .foregroundStyle(.black)

                Text(item.answer)
                    .font(.satoshi(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .lineSpacing(5)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        SettingsContainer(title: "Privacy") {
            VStack(spacing: 20) {
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

                Text("Tetamu stores event photos temporarily for each event and uses contact details only when you submit support requests.")
                    .font(.satoshi(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct AccountDeletionView: View {
    let profileName: String
    let profileUsername: String
    let profileEmail: String

    @AppStorage("accountDeletionRequestSubmitted") private var hasSubmittedRequest = false
    @State private var isSubmitting = false
    @State private var toast: SettingsToastData?
    @State private var showsConfirmation = false

    var body: some View {
        SettingsContainer(title: "Delete Account") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Request account deletion")
                    .font(.satoshi(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                Text("Send a deletion request from the email address attached to your account. We will review it and follow up at that email address.")
                    .font(.satoshi(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .lineSpacing(4)

                if profileEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add your email in Profile before sending a deletion request.")
                        .font(.satoshi(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                }

                Button {
                    showsConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(buttonTitle)
                    }
                        .font(.satoshi(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(buttonEnabled ? 1 : 0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(buttonEnabled ? Color.black : Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(!buttonEnabled)
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .top) {
            if let toast {
                SettingsToastView(data: toast)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if showsConfirmation {
                ZStack {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                showsConfirmation = false
                            }
                        }

                    SettingsConfirmationCard(
                        title: "Send deletion request?",
                        message: "We’ll send your request now and follow up at \(sanitizedEmail). You won’t be able to send it twice from this device.",
                        isSubmitting: isSubmitting,
                        confirmTitle: "Send request",
                        cancelAction: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                showsConfirmation = false
                            }
                        },
                        confirmAction: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                showsConfirmation = false
                            }
                            submitDeletionRequest()
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
    }

    private var sanitizedEmail: String {
        profileEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var buttonEnabled: Bool {
        !isSubmitting && !hasSubmittedRequest && !sanitizedEmail.isEmpty
    }

    private var buttonTitle: String {
        if hasSubmittedRequest { return "Request sent" }
        if isSubmitting { return "Sending request..." }
        return "Send deletion request"
    }

    private func submitDeletionRequest() {
        guard buttonEnabled else { return }

        isSubmitting = true

        Task {
            do {
                try await SupabaseManager.shared.submitAccountDeletionRequest(
                    name: profileName,
                    username: profileUsername,
                    email: sanitizedEmail
                )

                await MainActor.run {
                    isSubmitting = false
                    hasSubmittedRequest = true
                    showToast(
                        title: "Request sent",
                        message: "Your deletion request has been sent. We’ll review it and follow up at \(sanitizedEmail)."
                    )
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showToast(
                        title: "Couldn’t send request",
                        message: "Please try again in a moment."
                    )
                }
            }
        }
    }

    private func showToast(title: String, message: String) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            toast = SettingsToastData(title: title, message: message)
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    toast = nil
                }
            }
        }
    }
}

private struct SettingsToastData: Equatable {
    let title: String
    let message: String
}

private struct SettingsConfirmationCard: View {
    let title: String
    let message: String
    let isSubmitting: Bool
    let confirmTitle: String
    let cancelAction: () -> Void
    let confirmAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.satoshi(size: 18, weight: .bold))
                .foregroundStyle(.black)

            Text(message)
                .font(.satoshi(size: 14, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.62))
                .lineSpacing(4)

            HStack(spacing: 10) {
                Button(action: cancelAction) {
                    Text("Cancel")
                        .font(.satoshi(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Button(action: confirmAction) {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(isSubmitting ? "Sending..." : confirmTitle)
                    }
                    .font(.satoshi(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

private struct SettingsToastView: View {
    let data: SettingsToastData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.title)
                .font(.satoshi(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(data.message)
                .font(.satoshi(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
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
            Color(hex: "#F2F2F2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: title, showsBackButton: showsBackButton, dismiss: dismiss)

                ScrollView(showsIndicators: false) {
                    content
                        .padding(.top, 16)
                        .padding(.bottom, 116)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SettingsHeader: View {
    let title: String
    let showsBackButton: Bool
    let dismiss: DismissAction

    var body: some View {
        ZStack {
            Text(title)
                .font(.satoshi(size: 20, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)

            if showsBackButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.black)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
        }
        .frame(height: 56)
        .padding(.top, 10)
    }
}

private struct ProfileSummaryCard: View {
    let name: String
    let username: String

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatar(size: 52)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.satoshi(size: 17, weight: .black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text("@\(username)")
                    .font(.satoshi(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .frame(height: 68)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
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
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.satoshi(size: 13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.black.opacity(0.4))
                    .padding(.leading, 6)
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .settingsIconStyle()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.satoshi(size: 17, weight: .medium))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                if let subtitle {
                    Text(subtitle)
                        .font(.satoshi(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }

            Spacer(minLength: 10)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.25))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle == nil ? 44 : 56)
        .contentShape(Rectangle())
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

private struct SocialLinksView: View {
    let openExternalURL: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOCIALS")
                .font(.satoshi(size: 13, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color.black.opacity(0.4))
                .padding(.leading, 6)

            HStack(spacing: 10) {
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))

                Text(title)
                    .font(.satoshi(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
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
    let safeBottom: CGFloat
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
        .padding(.bottom, max(safeBottom, 12))
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func bottomButton(_ systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.satoshi(size: 28, weight: .medium))
                .foregroundStyle(isSelected ? Color.black : Color.black.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.black.opacity(0.07))
                        }
                    }
                )
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
            question: "Does Tetamu work for other phones too?",
            answer: "Yes. Guests can join from a supported mobile browser through the event link or QR code."
        ),
        FAQItem(
            id: "no-download",
            question: "How is it possible that guests don't have to download the app?",
            answer: "Guests open a lightweight camera experience from the event link, so they can capture photos without installing the full app."
        ),
        FAQItem(
            id: "without-internet",
            question: "Does Tetamu work without internet?",
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
    func settingsIconStyle(size: CGFloat = 20) -> some View {
        font(.system(size: size, weight: .regular))
            .foregroundStyle(Color.black.opacity(0.5))
            .frame(width: 28)
    }
}
