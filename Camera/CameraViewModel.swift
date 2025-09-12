//
//  CameraViewModel.swift
//  Camera
//
//  Created by Assistant on 12/09/25.
//

import Foundation
import AVFoundation
import Combine
import UIKit
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins

final class CameraViewModel: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var frameRateLabel: String = "60 fps"
    @Published var quickZoomIndex: Int = 1 // 0 -> 0.5x, 1 -> 1x, 2 -> 2x
    @Published var isTorchOn: Bool = false
    @Published var isFilterOn: Bool = false
    @Published var showGrid: Bool = false

    let controller = CaptureSessionController()
    private var recorder: SegmentedRecorder?
    private var cancellables = Set<AnyCancellable>()
    private var orientationObserver: Any?
    private var savedScreenBrightness: CGFloat?

    override init() {
        super.init()
    }

    deinit {
        // Ensure brightness is restored if we used screen torch
        setScreenTorchEnabled(false)
    }

    // MARK: - Grid
    func toggleGrid() { showGrid.toggle() }

    func requestPermissionsAndConfigure() {
        controller.requestPermissions { [weak self] granted in
            guard let self else { return }
            self.isAuthorized = granted
            guard granted else { return }
            self.controller.configureSession(desiredFrameRate: .fps60) { error in
                if let error { print("Session config error: \(error)") }
                self.recorder = SegmentedRecorder(controller: self.controller)
                self.recorder?.delegate = self
                // We'll handle saving ourselves to allow filtered exports
                self.recorder?.saveToPhotoLibrary = false
                self.setupOrientationMonitoring()
                self.start()
            }
        }
    }

    func start() {
        controller.startSession()
        isSessionRunning = true
    }

    // MARK: - Filter
    func toggleFilter() { isFilterOn.toggle() }

    func stop() {
        controller.stopSession()
        isSessionRunning = false
        setScreenTorchEnabled(false)
    }

    func attachPreview(_ view: CameraPreviewView) {
        view.attach(session: controller.session)
        view.onTapToFocus = { [weak self] devicePoint in
            self?.controller.focusAndExpose(at: devicePoint)
        }
        var baseZoom: CGFloat = 1.0
        view.onPinch = { [weak self] scale, state in
            guard let self else { return }
            switch state {
            case .began:
                baseZoom = controller.currentZoomFactor()
            case .changed:
                self.controller.setZoomFactor(baseZoom * scale, animated: true, rampRate: 8.0)
            case .ended, .cancelled, .failed:
                self.controller.cancelZoomRamp()
                baseZoom = 1.0
            default:
                break
            }
        }
        view.onDoubleTap = { [weak self] in
            self?.toggleCameraPosition()
        }
    }

    // MARK: - Torch
    func toggleTorch() {
        isTorchOn.toggle()
        if controller.currentPosition == .front {
            setScreenTorchEnabled(isTorchOn)
        } else {
            controller.setTorchEnabled(isTorchOn)
        }
    }

    private func setScreenTorchEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            if enabled {
                if self.savedScreenBrightness == nil {
                    self.savedScreenBrightness = UIScreen.main.brightness
                }
                UIScreen.main.brightness = 1.0
            } else {
                if let original = self.savedScreenBrightness {
                    UIScreen.main.brightness = original
                    self.savedScreenBrightness = nil
                }
            }
        }
    }

    func toggleFrameRate() {
        let next: CaptureSessionController.DesiredFrameRate = (controller.currentFrameRate == .fps60) ? .fps30 : .fps60
        controller.setFrameRate(to: next) { [weak self] ok in
            guard let self else { return }
            if ok {
                self.frameRateLabel = "\(next.rawValue) fps"
            }
        }
    }

    func toggleRecording() {
        guard let recorder else { return }
        if recorder.isRecording {
            recorder.stopCurrentSegment()
            isRecording = false
        } else {
            recorder.startNewSegment()
            isRecording = true
        }
    }

    func selectQuickZoom(index: Int) {
        quickZoomIndex = index
        switch index {
        case 0:
            controller.jumpToHalfX()
        case 1:
            controller.jumpToOneX()
        case 2:
            controller.jumpToTwoX()
        default:
            controller.jumpToOneX()
        }
    }

    func toggleCameraPosition() {
        // Turn off screen torch when switching away from front; controller will reapply hardware torch
        setScreenTorchEnabled(false)
        controller.toggleCameraPosition()
        // Reset quick zoom selection to 1x for consistency
        DispatchQueue.main.async {
            self.quickZoomIndex = 1
        }
        // After switching, re-apply desired torch state depending on side
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.controller.currentPosition == .front {
                self.setScreenTorchEnabled(self.isTorchOn)
            } else {
                self.controller.setTorchEnabled(self.isTorchOn)
            }
        }
    }

    private func setupOrientationMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let deviceOrientation = UIDevice.current.orientation
            if let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
                self.controller.setVideoOrientation(videoOrientation)
                self.recorder?.updateOrientation(from: deviceOrientation)
            }
        }
        // Initialize once
        if let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation) {
            controller.setVideoOrientation(videoOrientation)
            recorder?.updateOrientation(from: UIDevice.current.orientation)
        }
    }
}

extension CameraViewModel: SegmentedRecorderDelegate {
    func recorder(_ recorder: SegmentedRecorder, didFinishSegment url: URL) {
        if isFilterOn {
            applyRoseFilter(to: url) { result in
                switch result {
                case .success(let filteredURL):
                    self.saveVideoToPhotos(filteredURL)
                case .failure(let error):
                    print("Filter export error: \(error)")
                    // Fallback: save original
                    self.saveVideoToPhotos(url)
                }
            }
        } else {
            saveVideoToPhotos(url)
        }
    }

    func recorder(_ recorder: SegmentedRecorder, didFailWith error: Error) {
        print("Recorder error: \(error)")
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight // device left means camera right
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}

// MARK: - Video Filtering & Saving
extension CameraViewModel {
    private func applyRoseFilter(to inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputURL)
        let composition = AVVideoComposition(asset: asset) { request in
            let sourceImage = request.sourceImage.clampedToExtent()
            // Rose tint using CIColorMonochrome with pink hue
            let filter = CIFilter.colorMonochrome()
            filter.inputImage = sourceImage
            filter.intensity = 0.6
            filter.color = CIColor(red: 1.0, green: 0.6, blue: 0.75)
            if let output = filter.outputImage?.cropped(to: request.sourceImage.extent) {
                request.finish(with: output, context: nil)
            } else {
                request.finish(with: NSError(domain: "Filter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Filter failed"]))
            }
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "Filter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create exporter"])));
            return
        }
        exporter.videoComposition = composition
        exporter.outputFileType = .mov
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("filtered_\(UUID().uuidString).mov")
        exporter.outputURL = outURL
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outURL))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? NSError(domain: "Filter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])) )
            default:
                break
            }
        }
    }

    private func saveVideoToPhotos(_ fileURL: URL) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized else {
                    print("Photos add-only access not authorized")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if let error { print("Save error: \(error)") }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if let error { print("Save error: \(error)") }
                }
            }
        }
    }
}
