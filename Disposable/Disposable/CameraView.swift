//
//  CameraView.swift
//  Disposable
//
//  Created by Clementine CUREL on 11/01/2025.
//

import SwiftUI
import UIKit

struct CameraView: View {
    let eventID: String
    let userName: String
    var eventName: String = "Tetamu Event"
    var endDateText: String = "Ends on 23 May"
    var closeAction: () -> Void = {}

    @StateObject private var camera = CameraModel()
    @State private var displayedShots = 0
    @State private var hasRolledInitialShots = false
    @State private var rollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            cameraVignette

            if let previewImage = camera.previewImage {
                capturedPreview(image: previewImage)
            } else {
                liveChrome
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: configureCamera)
        .onDisappear(perform: tearDownCamera)
        .onChange(of: camera.remainingPhotos) { _, newValue in
            updateDisplayedShots(for: newValue)
        }
        .onChange(of: camera.maxPhotos) { _, _ in
            updateDisplayedShots(for: camera.remainingPhotos)
        }
    }

    private var liveChrome: some View {
        ZStack {
            topChrome
            sideControls
            bottomControls
        }
    }

    private var topChrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 6) {
                    HStack(spacing: 7) {
                        Text(eventName)
                            .font(.satoshi(size: 19, weight: .italic))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }

                    Text(endDateText)
                        .font(.satoshi(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .foregroundStyle(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.5), radius: 7, y: 2)
                .frame(maxWidth: 235)
                .padding(.top, 6)

                Spacer()

                Color.clear
                    .frame(width: 56, height: 56)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)

            Spacer()
        }
    }

    private var sideControls: some View {
        VStack(spacing: 0) {
            sideButton("gearshape")
            sideDivider
            sideButton("square.and.arrow.up")
            sideDivider
            sideButton("iphone")
            sideDivider
            sideButton("photo.badge.plus")
        }
        .frame(width: 58)
        .background(Color.black.opacity(0.28), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.34), radius: 12, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 20)
        .padding(.top, 120)
    }

    private var bottomControls: some View {
        VStack {
            Spacer()

            HStack(alignment: .center) {
                Button(action: camera.toggleFlash) {
                    Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
                .offset(y: -80)

                Spacer()

                Button(action: camera.takePhoto) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(hex: "#D7D9DC")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 86, height: 86)
                        .overlay(Circle().stroke(Color(hex: "#8A84FF"), lineWidth: 4))
                        .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1).padding(8))
                        .shadow(color: .black.opacity(0.32), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(camera.remainingPhotos <= 0)
                .opacity(camera.remainingPhotos <= 0 ? 0.42 : 1)

                Spacer()

                Button(action: camera.switchCamera) {
                    thumbnailStack
                        .frame(width: 78, height: 78)
                }
                .buttonStyle(.plain)
                .offset(y: -80)
            }
            .overlay(alignment: .bottomLeading) {
                shotsCounter
                    .padding(.leading, 24)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.97)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 278)
                .offset(y: 46),
                alignment: .bottom
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var shotsCounter: some View {
        HStack(alignment: .bottom, spacing: 7) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(displayedShots)")
                    .font(.satoshi(size: 38, weight: .black))
                    .italic()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText(countsDown: true))

                if camera.maxPhotos > 0 && displayedShots < camera.maxPhotos {
                    Text("\(camera.maxPhotos)")
                        .font(.satoshi(size: 31, weight: .black))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white.opacity(0.16))
                        .contentTransition(.identity)
                }
            }
            .frame(width: 54, alignment: .leading)
            .animation(.spring(response: 0.22, dampingFraction: 0.88), value: displayedShots)

            Text("SHOTS\nREMAINING")
                .font(.satoshi(size: 12, weight: .black))
                .italic()
                .lineSpacing(-2)
                .foregroundStyle(.white)
                .padding(.bottom, 18)
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
    }

    private var thumbnailStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .fill(Color.white.opacity(0.12))
                .frame(width: 44, height: 60)
                .rotationEffect(.degrees(-8))
                .offset(x: -13, y: 5)

            RoundedRectangle(cornerRadius: 17)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color(hex: "#8D843E"), Color.black.opacity(0.92)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 54, height: 72)
                .rotationEffect(.degrees(10))
                .offset(x: 9, y: -2)
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .rotationEffect(.degrees(10))
                        .offset(x: 9, y: -2)
                )
        }
    }

    private var cameraVignette: some View {
        VStack {
            LinearGradient(colors: [.black.opacity(0.58), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 190)
            Spacer()
        }
        .ignoresSafeArea()
    }

    private func sideButton(_ systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 58, height: 56)
        }
        .buttonStyle(.plain)
    }

    private var sideDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(height: 1)
            .padding(.horizontal, 7)
    }

    private func capturedPreview(image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 18)

                HStack(spacing: 12) {
                    Button(action: camera.retakePhoto) {
                        Text("Re-take")
                            .font(.satoshi(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: camera.savePhoto) {
                        Text("Save")
                            .font(.satoshi(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color(hex: "#5750E6"), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Shot Roll

private extension CameraView {
    func configureCamera() {
        camera.eventID = eventID
        camera.userName = userName
        camera.fetchRemainingPhotos()
        camera.checkPermissions()
    }

    func tearDownCamera() {
        rollTask?.cancel()
        camera.stopSession()
    }

    func updateDisplayedShots(for remaining: Int) {
        guard remaining >= 0 else { return }

        if !hasRolledInitialShots, camera.maxPhotos > 0 {
            hasRolledInitialShots = true
            startInitialShotRoll(from: camera.maxPhotos, to: remaining)
            return
        }

        guard hasRolledInitialShots else {
            displayedShots = remaining
            return
        }

        displayedShots = remaining
    }

    func startInitialShotRoll(from total: Int, to remaining: Int) {
        rollTask?.cancel()
        displayedShots = total

        guard total != remaining else { return }

        rollTask = Task { @MainActor in
            let direction = total > remaining ? -1 : 1
            var value = total

            while value != remaining && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)
                value += direction
                withAnimation(.spring(response: 0.18, dampingFraction: 0.85)) {
                    displayedShots = value
                }
            }
        }
    }
}
