//
//  CameraModel.swift
//  Disposable
//
//  Created by Clementine CUREL on 15/01/2025.
//

import AVFoundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var output = AVCapturePhotoOutput()
    @Published var previewImage: UIImage?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    @Published var isFlashOn: Bool = false
    @Published var maxPhotos: Int = 0
    @Published var remainingPhotos: Int = 0
    @Published var filterStyle: String = "none"

    
    // These get set externally by your CameraView
    @Published var eventID: String = "unknownEvent"
    @Published var userName: String = "unknownuser"
    
    private let captureSessionQueue = DispatchQueue(label: "CaptureSessionQueue")
    
    override init() {
        super.init()
//        setupCamera()
        checkPermissions()
    }
    
    // MARK: - Camera Setup
    func setupCamera() {
            captureSessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.session.beginConfiguration()

                let preferredPosition: AVCaptureDevice.Position = .front
                let fallbackPosition: AVCaptureDevice.Position = .back
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: fallbackPosition)

                guard let videoDevice,
                      let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                    print("Failed to access camera.")
                    return
                }

                // Add camera input
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                }

                // Add output for capturing photos
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }

                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.currentCameraPosition = videoDevice.position
                }
                self.startSession()
            }
        }
    
    // MARK: - Permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCamera()
                } else {
                    print("Camera access denied by user.")
                }
            }
        default:
            print("Camera permission denied or restricted.")
        }
    }
    
    // MARK: - Start/Stop Session
    func startSession() {
        captureSessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                print("Camera session started.")
            }
        }
    }
    
    func stopSession() {
        captureSessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                print("Camera session stopped.")
            }
        }
    }
    
    // MARK: - Capture Photo

    func takePhoto() {
            guard remainingPhotos > 0 else {
                print("No remaining photos.")
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = isFlashOn && currentCameraPosition == .back ? .on : .off

            output.capturePhoto(with: settings, delegate: self)
        }

    private func persistShotsTaken() {
        let taken = maxPhotos - remainingPhotos
        UserDefaults.standard.set(taken, forKey: "shots_taken_\(eventID)_\(userName)")
    }


    private func simulateFrontCameraFlash(completion: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let _ = windowScene.windows.first else {
            completion()
            return
        }


            let originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIScreen.main.brightness = originalBrightness
                }
            }
        }
    
    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn && currentCameraPosition == .back ? .on : .off
        output.capturePhoto(with: settings, delegate: self)
    }


    
    // MARK: - Retake Photo
    func retakePhoto() {
        previewImage = nil
    }
    
    // MARK: - Save Photo (Supabase Storage + DB)
    func savePhoto() {
        guard let image = previewImage else { return }
        self.remainingPhotos = max(0, self.remainingPhotos - 1)
        persistShotsTaken()

        let outputImage = applySelectedFilter(to: image)
        guard let data = outputImage.jpegData(compressionQuality: 0.8) else { return }

        previewImage = nil

        Task {
            do {
                _ = try await SupabaseManager.shared.uploadPhoto(
                    eventId: eventID,
                    guestName: userName,
                    jpegData: data,
                    filterStyle: filterStyle,
                    expiresAt: nil
                )
            } catch {
                print("Photo upload failed: \(error)")
            }
        }
    }

    private func applySelectedFilter(to image: UIImage) -> UIImage {
        guard filterStyle == "vintage",
              let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        let filter = CIFilter.photoEffectTransfer()
        filter.inputImage = ciImage

        guard let output = filter.outputImage,
              let outputCG = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: outputCG)
    }
    // MARK: - camera switch
    func switchCamera() {
        captureSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()

            // Remove all existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }

            // Determine new camera position
            let newPosition: AVCaptureDevice.Position = (self.currentCameraPosition == .back) ? .front : .back

            // Select the new camera device
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to switch to \(newPosition == .back ? "back" : "front") camera.")
                return
            }

            // Add the new input
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
            }

            // Ensure the output is added
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }

            // Commit the configuration
            self.session.commitConfiguration()

            // Update the current camera position
            DispatchQueue.main.async {
                self.currentCameraPosition = newPosition
            }
        }
    }
    
    // MARK: - flash
    func toggleFlash() {
        if currentCameraPosition == .front {
            // Enable flash simulation for front camera
            isFlashOn.toggle()
            print("Front camera flash simulation \(isFlashOn ? "enabled" : "disabled").")
        } else {
            // Enable hardware flash for back camera
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
                print("Flash is not supported on this device.")
                return
            }

            do {
                try device.lockForConfiguration()
                device.torchMode = isFlashOn ? .off : .on
                isFlashOn.toggle()
                device.unlockForConfiguration()
            } catch {
                print("Failed to toggle flash: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - remaining photos
    func fetchRemainingPhotos() {
        Task {
            do {
                let event = try await SupabaseManager.shared.fetchEvent(id: eventID)
                let shots = event.shots_per_guest
                // read shots taken from localStorage-equivalent (UserDefaults)
                let taken = UserDefaults.standard.integer(forKey: "shots_taken_\(eventID)_\(userName)")
                await MainActor.run {
                    self.maxPhotos = shots
                    self.filterStyle = event.filter_style
                    self.remainingPhotos = max(0, shots - taken)
                }
            } catch {
                print("fetchRemainingPhotos failed: \(error)")
            }
        }
    }
}


// MARK: - AVCapturePhotoCaptureDelegate
extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Failed to convert photo buffer to UIImage.")
            return
        }
        
        DispatchQueue.main.async {
            self.previewImage = image
            print("Photo captured and stored in previewImage.")
        }
    }
}
