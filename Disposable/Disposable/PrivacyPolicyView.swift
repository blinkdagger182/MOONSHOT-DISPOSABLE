//
//  PrivacyPolicyView.swift
//  Disposable
//
//  Updated from https://www.tetamu.app/privacy
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: May 2026")
                    .font(.satoshi(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)

                LegalSectionHeader(title: "Introduction")
                LegalParagraph(text: "Tetamu operates the Tetamu application. This policy explains how personal data is collected, used, and disclosed when you use the service.")

                LegalSectionHeader(title: "Information Collection and Use")
                LegalParagraph(text: "Tetamu collects information you provide directly when you create an account, take part in an event, or contact support. This may include your name, email, photos, and profile information.")

                LegalSectionHeader(title: "Photo Data")
                LegalParagraph(text: "Uploaded photos are stored temporarily and are automatically deleted after the event ends or after the applicable retention period expires. Tetamu does not store event photos permanently.")

                LegalSectionHeader(title: "Latest Version")
                Link("View the current privacy policy on tetamu.app", destination: URL(string: "https://www.tetamu.app/privacy")!)
                    .font(.satoshi(.body, weight: .medium))

                LegalSectionHeader(title: "Contact")
                LegalParagraph(text: "For privacy questions, contact support@tetamu.app.")
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
