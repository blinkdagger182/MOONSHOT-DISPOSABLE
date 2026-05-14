import SwiftUI
import AVFoundation

final class ClipCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?

    @Published var torchEnabled = false
    @Published var usingFrontCamera = false

    var onPhotoCapture: ((UIImage) -> Void)?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: back),
           session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() {
        guard let currentInput = currentInput else { return }
        let target: AVCaptureDevice.Position = usingFrontCamera ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: target),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.currentInput = newInput
            usingFrontCamera.toggle()
            torchEnabled = false
        } else {
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }

    var canToggleTorch: Bool {
        guard let device = currentInput?.device else { return false }
        return device.position == .back && device.hasTorch
    }

    func toggleTorch() {
        guard let device = currentInput?.device,
              device.position == .back,
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if torchEnabled {
                device.torchMode = .off
                torchEnabled = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                torchEnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            // no-op
        }
    }
}

extension ClipCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        DispatchQueue.main.async {
            self.onPhotoCapture?(image)
        }
    }
}

struct ClipCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

struct ClipCameraView: View {
    @ObservedObject var controller: ClipCameraController
    let eventName: String
    let shotsLeft: Int
    let onCapture: (UIImage) -> Void
    let onClose: () -> Void

    @State private var showFlashOverlay = false

    var body: some View {
        ZStack {
            ClipCameraPreview(session: controller.session)
                .ignoresSafeArea()

            if showFlashOverlay {
                Color.white.opacity(0.82)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                topOverlay

                Spacer()

                sideOverlay

                Spacer()

                shutterRow
            }
        }
        .onAppear {
            controller.onPhotoCapture = onCapture
            controller.startSession()
        }
        .onDisappear {
            controller.stopSession()
        }
    }

    private var topOverlay: some View {
        HStack {
            iconButton(systemName: "chevron.left", action: onClose)
            Spacer()
            VStack(spacing: 3) {
                Text(eventName)
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Tap to invite friends!")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.86))
            }
            Spacer()
            iconButton(systemName: "gearshape", action: {})
                .opacity(0.72)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var sideOverlay: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                iconButton(systemName: "camera.rotate", action: controller.switchCamera)
                iconButton(systemName: controller.torchEnabled ? "bolt.fill" : "bolt.slash", action: controller.toggleTorch)
                    .disabled(!controller.canToggleTorch)
                    .opacity(controller.canToggleTorch ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 14)
    }

    private var shutterRow: some View {
        VStack(spacing: 12) {
            HStack {
                iconTile(label: "1x")
                Spacer()
                Button(action: takePhotoWithVisualEffect) {
                    Circle()
                        .fill(.white)
                        .frame(width: 86, height: 86)
                        .overlay(Circle().stroke(Color.blue.opacity(0.7), lineWidth: 6))
                }
                .opacity(shotsLeft > 0 ? 1 : 0.4)
                .disabled(shotsLeft <= 0)
                Spacer()
                iconTile(systemName: "camera")
                    .opacity(0.9)
            }
            .padding(.horizontal, 14)

            bottomDock
        }
        .padding(.bottom, 18)
    }

    private var bottomDock: some View {
        HStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(shotsLeft)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .italic()
                Text("SHOTS\nREMAINING")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
            }
            .foregroundStyle(.white)

            Spacer()

            Image(systemName: "qrcode")
                .foregroundStyle(.white.opacity(0.82))
                .font(.title2)

            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.white.opacity(0.82))
                .font(.title2)

            Text("\(shotsLeft) left")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 8)
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func iconTile(label: String? = nil, systemName: String? = nil) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
            if let label {
                Text(label)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            } else if let systemName {
                Image(systemName: systemName)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private func takePhotoWithVisualEffect() {
        guard shotsLeft > 0 else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            showFlashOverlay = true
        }

        controller.capturePhoto()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.28)) {
                showFlashOverlay = false
            }
        }
    }
}
