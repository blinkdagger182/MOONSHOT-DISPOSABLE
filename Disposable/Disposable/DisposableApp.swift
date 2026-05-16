//
//  DisposableApp.swift
//  Disposable
//
//  Created by Clementine CUREL on 09/01/2025.
//

import SwiftUI

private enum AppTab: Hashable {
    case home
    case camera
    case gallery
    case settings
}

@main
struct DisposableApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var isInEvent = UserDefaults.standard.bool(forKey: "isInEvent")
    @State private var eventData: [String: Any]? = {
        if let savedData = UserDefaults.standard.data(forKey: "currentEventData"),
            let decodedData = try? JSONSerialization.jsonObject(with: savedData, options: []) as? [String: Any] {
            return decodedData
        }
        return nil
    }()
    
    @State private var deepLinkedEventId: String? = nil
    @State private var selectedTab: AppTab = .home
    @State private var selectedHomeTab: HomeDashboardTab = .create

    var body: some Scene {
        WindowGroup {
            selectedContent
                .font(.satoshi(.body))
                .transaction { transaction in
                    transaction.animation = nil
                }
                .onChange(of: isInEvent) { _, newValue in
                    if !newValue && (selectedTab == .camera || selectedTab == .gallery) {
                        selectedTab = .home
                }
                if !newValue {
                    selectedHomeTab = .create
                }
            }
            .onOpenURL { url in
                if let eventId = extractEventId(from: url), !isInEvent {
                    print("Extracted eventId from URL: \(eventId)")
                    deepLinkedEventId = eventId
                    selectedHomeTab = .create
                    selectedTab = .home
                } else {
                    print("Ignored QR because already in an event")
                }
                }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            homeContent
        case .camera:
            if isInEvent {
                cameraContent
            } else {
                homeContent
            }
        case .gallery:
            if isInEvent {
                GalleryView(eventID: currentEventID, userName: currentUserName)
            } else {
                homeContent
            }
        case .settings:
            SettingsView(
                isInEvent: $isInEvent,
                eventData: $eventData,
                openHomeTab: {
                    selectedHomeTab = .create
                    selectedTab = .home
                },
                openCameraTab: {
                    selectedHomeTab = .cameras
                    selectedTab = .home
                }
            )
        }
    }

    private var homeContent: some View {
        HomeView(
            isInEvent: $isInEvent,
            eventData: $eventData,
            deepLinkedEventId: $deepLinkedEventId,
            selectedHomeTab: $selectedHomeTab,
            openSettingsTab: {
                selectedTab = .settings
            }
        )
    }

    private var cameraContent: some View {
        CameraView(
            eventID: currentEventID,
            userName: currentUserName,
            openHomeTab: {
                selectedHomeTab = .create
                selectedTab = .home
            },
            openSettingsTab: {
                selectedTab = .settings
            }
        )
    }

    private var currentEventID: String {
        eventData?["eventId"] as? String ?? "noEvent"
    }

    private var currentUserName: String {
        eventData?["userName"] as? String ?? "anonymous"
    }

    private func extractEventId(from url: URL) -> String? {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            return components?.queryItems?.first(where: { $0.name == "eventId" })?.value
        }
}
