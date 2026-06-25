//
//  TermsAndConditionsView.swift
//  Disposable
//
//  Updated from https://www.tetamu.app/terms
//

import SwiftUI

struct TermsAndConditionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: May 2026")
                    .font(.satoshi(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)

                LegalSectionHeader(title: "Agreement to Terms")
                LegalParagraph(text: "By accessing or using Tetamu, you agree to be bound by these terms. If you do not agree, do not use the service.")

                LegalSectionHeader(title: "Use License")
                LegalParagraph(text: "You may temporarily access the service for personal, non-commercial use. You may not copy the materials for commercial use, publicly display them, reverse engineer the software, or remove proprietary notices.")

                LegalSectionHeader(title: "Photo Ownership")
                LegalParagraph(text: "You retain ownership of the photos you upload. By uploading them to Tetamu, you grant Tetamu permission to store and display them for the duration of the event.")

                LegalSectionHeader(title: "Disclaimer")
                LegalParagraph(text: "Tetamu is provided on an \"as is\" basis without warranties of merchantability, fitness for a particular purpose, or non-infringement.")

                LegalSectionHeader(title: "Latest Version")
                Link("View the current terms on tetamu.app", destination: URL(string: "https://www.tetamu.app/terms")!)
                    .font(.satoshi(.body, weight: .medium))

                LegalSectionHeader(title: "Contact")
                LegalParagraph(text: "For legal questions, contact support@tetamu.app.")
            }
            .padding()
        }
        .navigationTitle("Terms and Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.satoshi(.title3, weight: .bold))
            .padding(.top, 8)
    }
}

struct LegalParagraph: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.satoshi(.body))
            .foregroundStyle(.primary)
            .lineSpacing(5)
    }
}
