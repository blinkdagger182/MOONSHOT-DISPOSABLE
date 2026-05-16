//
//  DisposableClipApp.swift
//  DisposableClip
//
//  Created by Clementine CUREL on 09/01/2025.
//

import SwiftUI

@main
struct DisposableClipApp: App {
    @State private var eventId: String? = nil

    var body: some Scene {
        WindowGroup {
            BrowserClipExperience(eventId: eventId)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if let eventId = extractEventId(from: url) {
            print("Extracted Event ID: \(eventId)")
            self.eventId = eventId
        } else {
            print("No event ID found in URL")
        }
    }

    private func extractEventId(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        return components?.queryItems?.first(where: { $0.name == "eventId" })?.value
    }
}
