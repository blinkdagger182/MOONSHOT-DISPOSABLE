//
//  ContactFormView.swift
//  Disposable
//
//  Created by Clementine CUREL on 27/01/2025.
//

import SwiftUI

struct ContactFormView: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var selectedSubjects: [String] = []
    @State private var isSubmitting: Bool = false
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    @State private var acceptedTerms: Bool = false

    private let subjects = [
        "Technical support",
        "Feedback",
        "Data access",
        "Data deletion",
        "Other"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Contact Form")
                    .font(.satoshi(.largeTitle, weight: .black))
                    .fontWeight(.bold)

                Group {
                    Text("Name")
                        .font(.satoshi(.headline, weight: .bold))
                    TextField("Your name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Email")
                        .font(.satoshi(.headline, weight: .bold))
                    TextField("Your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)

                    Text("Message")
                        .font(.satoshi(.headline, weight: .bold))
                    TextEditor(text: $message)
                        .frame(height: 100)
                        .border(Color.gray, width: 1)
                        .cornerRadius(8)
                }

                Text("Subjects")
                    .font(.satoshi(.headline, weight: .bold))

                VStack(alignment: .leading) {
                    ForEach(subjects, id: \.self) { subject in
                        HStack {
                            Button(action: {
                                toggleSubject(subject)
                            }) {
                                Image(systemName: selectedSubjects.contains(subject) ? "checkmark.square" : "square")
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text(subject)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button(action: {
                            acceptedTerms.toggle()
                        }) {
                            Image(systemName: acceptedTerms ? "checkmark.square" : "square")
                                .foregroundColor(acceptedTerms ? .green : .gray)
                        }
                        Text("I accept the ")
                        + Text("[Privacy Policy](https://sites.google.com/view/disposable-app/accueil)").foregroundColor(.blue)
                        + Text(" and ")
                        + Text("[Terms & Conditions](https://sites.google.com/view/disposable-app/accueil)").foregroundColor(.blue)
                    }
                    .font(.satoshi(.footnote))
                }
                .padding(.top)

                Button(action: handleSubmit) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit")
                            .font(.satoshi(.headline, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(acceptedTerms ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                }
                .disabled(!acceptedTerms || isSubmitting)
                .padding(.top, 20)
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func toggleSubject(_ subject: String) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.removeAll { $0 == subject }
        } else {
            selectedSubjects.append(subject)
        }
    }

    private func handleSubmit() {
        guard !name.isEmpty, !email.isEmpty, !message.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }

        isSubmitting = true

        Task {
            do {
                try await SupabaseManager.shared.submitContactForm(
                    name: name,
                    email: email,
                    message: message,
                    subjects: selectedSubjects
                )
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = "Your message has been sent successfully."
                    showAlert = true
                    name = ""
                    email = ""
                    message = ""
                    selectedSubjects = []
                    acceptedTerms = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    alertMessage = "Failed to submit: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
