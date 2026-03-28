//
//  CameraManager.swift
//  Scanner
//
//  Encapsulates AVCaptureSession with two modes:
//  - .documentScan: enables real-time rectangle detection
//  - .photo: plain photo capture (bank cards, business licenses, etc.)
//
//  Thread model:
//  - Session configuration and start/stop happen on a dedicated serial queue.
//  - Delegate callbacks (video frames, captured photo) are dispatched on main thread.
//

import UIKit
import AVFoundation

// MARK: - Types

enum CameraMode {
    case documentScan
    case photo
}

protocol CameraManagerDelegate: AnyObject {
    /// Called on every video frame. `sampleBuffer` is valid only during the call.
    func cameraManager(_ manager: CameraManager, didOutputVideoFrame sampleBuffer: CMSampleBuffer)
    /// Called after `capturePhoto()` completes.
    func cameraManager(_ manager: CameraManager, didCapturePhoto image: UIImage)
    /// Called when an unrecoverable error occurs.
    func cameraManager(_ manager: CameraManager, didEncounterError error: CameraManagerError)
}

/// Optional delegate methods get default empty implementations.
extension CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutputVideoFrame sampleBuffer: CMSampleBuffer) {}
}

enum CameraManagerError: LocalizedError {
    case cameraUnavailable
    case inputConfigurationFailed
    case outputConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:        return "无法访问相机"
        case .inputConfigurationFailed:  return "相机输入配置失败"
        case .outputConfigurationFailed: return "相机输出配置失败"
        }
    }
}

// MARK: - CameraManager

final class CameraManager: NSObject {

    // MARK: - Public Properties

    weak var delegate: CameraManagerDelegate?

    let session = AVCaptureSession()
    private(set) var cameraMode: CameraMode

    /// The preview layer; callers should add this to their view hierarchy.
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    var isRunning: Bool { session.isRunning }

    // MARK: - Private Properties

    private let sessionQueue = DispatchQueue(label: "com.scanner.camera.session")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "com.scanner.camera.videoOutput")

    private var isConfigured = false

    // MARK: - Init

    init(mode: CameraMode = .documentScan) {
        self.cameraMode = mode
        super.init()
    }

    // MARK: - Public API

    /// Configure and start the capture session.
    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    /// Stop the capture session.
    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Capture a high-resolution still photo.
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = self.photoOutput.isHighResolutionCaptureEnabled
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Switch camera mode at runtime. Reconfigures video output as needed.
    func switchMode(_ newMode: CameraMode) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.cameraMode = newMode
            // In documentScan mode, video frames are processed for rectangle detection.
            // In photo mode, we can skip video output to reduce CPU usage.
            // However, keeping video output alive in both modes simplifies the design
            // and allows future extension (e.g. bank-card edge hints).
        }
    }

    /// Toggle torch (flashlight).
    func setTorch(on: Bool) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device,
                  device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                Logger.shared.log("Torch error: \(error.localizedDescription)", level: .error)
            }
        }
    }

    /// Focus at a specific point in the preview (normalized 0...1).
    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                Logger.shared.log("Focus error: \(error.localizedDescription)", level: .error)
            }
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // --- Input ---
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            reportError(.cameraUnavailable)
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                reportError(.inputConfigurationFailed)
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            self.videoDeviceInput = input
        } catch {
            reportError(.inputConfigurationFailed)
            session.commitConfiguration()
            return
        }

        // --- Photo Output ---
        guard session.canAddOutput(photoOutput) else {
            reportError(.outputConfigurationFailed)
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        // --- Video Output (for real-time frame analysis) ---
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        guard session.canAddOutput(videoOutput) else {
            reportError(.outputConfigurationFailed)
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)

        // Stabilize connection orientation to portrait
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }

        session.commitConfiguration()
        isConfigured = true

        // Auto-focus / auto-exposure
        configureCameraDevice(camera)
    }

    private func configureCameraDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            Logger.shared.log("Camera device config error: \(error.localizedDescription)", level: .warning)
        }
    }

    private func reportError(_ error: CameraManagerError) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.cameraManager(self, didEncounterError: error)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Forward frames to delegate (used by RectangleDetector in documentScan mode)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.cameraManager(self, didOutputVideoFrame: sampleBuffer)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            Logger.shared.log("Photo capture error: \(error.localizedDescription)", level: .error)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Logger.shared.log("Failed to create image from photo data", level: .error)
            return
        }

        let fixedImage = image.fixOrientation()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.cameraManager(self, didCapturePhoto: fixedImage)
        }
    }
}
