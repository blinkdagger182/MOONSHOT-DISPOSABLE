//
//  JoinEventView.swift
//  Disposable
//
//  Created by Clementine CUREL on 29/01/2025.
//

import SwiftUI

struct JoinEventView: View {
    @Binding var isInEvent: Bool
    @Binding var eventData: [String: Any]?

    @State private var eventIDInput: String = ""
    @State private var userName: String = ""
    @State private var eventExists: Bool = false
    @State private var showJoinEventAlert: Bool = false
    @State private var joinErrorMessage: String?
    @State private var hasAcceptedTerms: Bool = false
    
    var initialEventId: String? = nil
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Join an Event")
                .font(.satoshi(.title, weight: .bold))
                .fontWeight(.bold)

            if !eventExists && initialEventId == nil {
                TextField("Enter event ID", text: $eventIDInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: {
                    checkEventExists()
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#E8D7FF"))
                        .foregroundColor(Color(hex: "#09745F"))
                        .fontWeight(.bold)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }
                .disabled(eventIDInput.isEmpty)
            } else if eventExists {
                Text("Event found! Enter your name to join.")
                    .foregroundColor(.green)

                TextField("Enter your name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                // Terms and Conditions toggle
                Toggle(isOn: $hasAcceptedTerms) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("I agree to the")
                            .font(.satoshi(.subheadline))
                            .foregroundColor(.gray)
                        HStack {
                            NavigationLink(destination: PrivacyPolicyView()) {
                                Text("Privacy Policy")
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                            Text("and")
                                .font(.satoshi(.subheadline))
                                .foregroundColor(.gray)
                            NavigationLink(destination: TermsAndConditionsView()) {
                                Text("Terms and Conditions")
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
                .toggleStyle(SwitchToggleStyle(tint: .green))

                // Join Button
                Button(action: {
                    joinEvent()
                }) {
                    Text("Join")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userName.isEmpty || !hasAcceptedTerms ? Color.gray : Color(hex: "#E8D7FF"))
                        .foregroundColor(userName.isEmpty || !hasAcceptedTerms ? .white : Color(hex: "#09745F"))
                        .fontWeight(.bold)
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                }
                .disabled(userName.isEmpty || !hasAcceptedTerms)
                .alert(isPresented: $showJoinEventAlert) {
                    Alert(
                        title: Text(joinErrorMessage == nil ? "Success" : "Error"),
                        message: Text(joinErrorMessage ?? "You have successfully joined the event."),
                        dismissButton: .default(Text("OK")){
                            if (joinErrorMessage == nil) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .onAppear{
            if let id = initialEventId{
                eventIDInput = id
                if !eventExists {
                    checkEventExists()
                }
            }
        }
    }

    private func checkEventExists() {
        Task {
            do {
                let event = try await SupabaseManager.shared.fetchEvent(id: eventIDInput)
                await MainActor.run {
                    eventExists = true
                    eventData = [
                        "eventId": event.id,
                        "eventName": event.title,
                        "userName": event.host_name,
                        "location": event.location,
                        "duration": event.duration_hours,
                        "reveal": event.reveal_mode,
                        "numberOfPhotos": event.shots_per_guest,
                        "guestLimit": event.guest_limit,
                        "allowVoiceNotes": event.allow_voice_notes,
                        "voiceNoteMaxSeconds": event.voice_note_max_seconds,
                        "filterStyle": event.filter_style,
                        "startTime": ISO8601DateFormatter().date(from: event.starts_at)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                    ]
                }
            } catch {
                await MainActor.run {
                    joinErrorMessage = "Event not found. Check the ID."
                    showJoinEventAlert = true
                }
            }
        }
    }

    private func joinEvent() {
        guard eventExists, !userName.isEmpty else {
            joinErrorMessage = "Please enter your name to join."
            showJoinEventAlert = true
            return
        }

        Task {
            do {
                _ = try await SupabaseManager.shared.addGuest(
                    eventId: eventIDInput,
                    name: userName,
                    role: "guest"
                )
                await MainActor.run {
                    isInEvent = true
                    eventData?["userName"] = userName
                    saveEventState()
                    joinErrorMessage = nil
                    showJoinEventAlert = true
                }
            } catch {
                await MainActor.run {
                    joinErrorMessage = "Failed to join event: \(error.localizedDescription)"
                    showJoinEventAlert = true
                }
            }
        }
    }

    private func saveEventState() {
        guard let eventData,
              let savedData = try? JSONSerialization.data(withJSONObject: eventData, options: []) else { return }
        UserDefaults.standard.set(savedData, forKey: "currentEventData")
        UserDefaults.standard.set(true, forKey: "isInEvent")
    }

}
