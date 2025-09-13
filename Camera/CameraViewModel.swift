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
    @Published var segments: [RecordedSegment] = []

    let controller = CaptureSessionController()
    private var recorder: SegmentedRecorder?
    private var cancellables = Set<AnyCancellable>()
    private var orientationObserver: Any?
    private var savedScreenBrightness: CGFloat?

#if canImport(SCSDKCameraKit)
    // Optional Snap Camera Kit integration
    private var snapAR: SnapARCamera?
    @Published var useSnapAR: Bool = false // Preview switches to Snap when true
    // Configure these with your credentials (see README for setup)
    var snapApiToken: String = "eyJhbGciOiJIUzI1NiIsImtpZCI6IkNhbnZhc1MyU0hNQUNQcm9kIiwidHlwIjoiSldUIn0.eyJhdWQiOiJjYW52YXMtY2FudmFzYXBpIiwiaXNzIjoiY2FudmFzLXMyc3Rva2VuIiwibmJmIjoxNzU3Nzc0MzM2LCJzdWIiOiI5MTllMjQ3NC0xNDNmLTRkOWMtYmIyMi0yYjE2NTQyZWJjZmZ-UFJPRFVDVElPTn41N2MxMGZlZi1iM2QxLTQ3YWItODYyZi05NDU0MmRkYTg2ZjUifQ.TN_Ivk8UGbCW1hpxeDswuWm-mxOI7vKs_cNOgLlka0U" // e.g., "<YOUR_CAMERA_KIT_API_TOKEN>"
    var snapLensID: String = ""   // e.g., "<BEAUTY_LENS_ID>"
    var snapLensGroupID: String? = nil // e.g., "<GROUP_ID>" or nil
#endif

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

#if canImport(SCSDKCameraKit)
                // Attempt to start Snap only if credentials are set
                self.tryStartSnapIfConfigured()
#endif
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
        guard let recorder else {
            print("Recorder not available")
            return
        }

        if recorder.isRecording {
            print("Stopping recording...")
            recorder.stopCurrentSegment()
            isRecording = false
        } else {
            print("Starting recording...")
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
        print("Segment finished recording: \(url.lastPathComponent)")
        // Generate thumbnail and store segment in memory for the strip UI
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnail = self.generateThumbnail(for: url) ?? UIImage()
            let segment = RecordedSegment(url: url, thumbnail: thumbnail)
            DispatchQueue.main.async {
                self.segments.append(segment)
            }
        }
    }

    func recorder(_ recorder: SegmentedRecorder, didFailWith error: Error) {
        print("Recorder error: \(error)")
        print("Error details: \(error.localizedDescription)")

        // Reset recording state on error
        DispatchQueue.main.async {
            self.isRecording = false
        }
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
    struct RecordedSegment: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let thumbnail: UIImage
        let createdAt = Date()
    }

    // MARK: - Segment management
    func deleteSegment(_ segment: RecordedSegment) {
        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
            let url = segments[idx].url
            segments.remove(at: idx)
            try? FileManager.default.removeItem(at: url)
        }
    }

    func nextAction() {
        print("Next pressed with \(segments.count) takes")

        guard !segments.isEmpty else { return }

        // Concatenate all segments into a single video and save to gallery
        concatenateAndSaveSegments()
    }

    private func concatenateAndSaveSegments() {
        let segmentURLs = segments.map { $0.url }

        // Create composition
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Failed to create video track")
            return
        }

        // Add audio track if available
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        var currentTime = CMTime.zero

        for segmentURL in segmentURLs {
            let asset = AVAsset(url: segmentURL)

            // Get video track from asset
            if let assetVideoTrack = asset.tracks(withMediaType: .video).first {
                do {
                    try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration),
                                                 of: assetVideoTrack,
                                                 at: currentTime)

                    // Apply the original preferred transform to preserve exact orientation as recorded
                    videoTrack.preferredTransform = assetVideoTrack.preferredTransform
                } catch {
                    print("Failed to insert video track: \(error)")
                    continue
                }
            }

            // Get audio track from asset if available
            if let assetAudioTrack = asset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = audioTrack {
                do {
                    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration),
                                                            of: assetAudioTrack,
                                                            at: currentTime)
                } catch {
                    print("Failed to insert audio track: \(error)")
                    // Continue without audio for this segment
                }
            }

            currentTime = CMTimeAdd(currentTime, asset.duration)
        }

        // Export the composition
        exportComposition(composition)
    }

    private func exportComposition(_ composition: AVMutableComposition) {
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Failed to create export session")
            return
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("final_video_\(UUID().uuidString).mov")
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov

        // Apply filter if enabled
        if isFilterOn {
            print("Applying filter to concatenated video")
            applyRoseFilter(to: composition) { result in
                switch result {
                case .success(let filteredURL):
                    print("Filter applied successfully, saving filtered video")
                    self.saveVideoToPhotos(filteredURL)
                    // Clean up temp files after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        try? FileManager.default.removeItem(at: filteredURL)
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                case .failure(let error):
                    print("Filter application failed: \(error)")
                    print("Saving unfiltered video instead")
                    self.saveVideoToPhotos(outputURL)
                    // Clean up temp file after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                }
            }
        } else {
            exporter.exportAsynchronously { [weak self] in
                guard let self = self else { return }

                print("Export status: \(exporter.status.rawValue)")
                switch exporter.status {
                case .completed:
                    print("Video concatenation completed successfully")
                    print("Output URL: \(outputURL)")
                    self.saveVideoToPhotos(outputURL)
                    // Clean up temp file after a delay to ensure save completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                case .failed, .cancelled:
                    print("Video concatenation failed: \(exporter.error?.localizedDescription ?? "Unknown error")")
                    if let error = exporter.error {
                        print("Export error details: \(error)")
                    }
                default:
                    print("Export in progress or unknown status")
                    break
                }
            }
        }

        // Clean up individual segment files
        for segment in segments {
            try? FileManager.default.removeItem(at: segment.url)
        }

        // Clear segments after processing
        DispatchQueue.main.async {
            self.segments.removeAll()
        }
    }

    private func applyRoseFilter(to composition: AVMutableComposition, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = composition
        let compositionWithFilter = AVVideoComposition(asset: asset) { request in
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
            completion(.failure(NSError(domain: "Filter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create exporter"])))
            return
        }
        exporter.videoComposition = compositionWithFilter
        exporter.outputFileType = .mov
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("filtered_final_\(UUID().uuidString).mov")
        exporter.outputURL = outURL
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outURL))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? NSError(domain: "Filter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
            default:
                break
            }
        }
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.05, preferredTimescale: 600)
        do {
            let cg = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cg)
        } catch {
            print("Thumbnail generation failed: \(error)")
            return nil
        }
    }

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
            print("Filter export status: \(exporter.status.rawValue)")
            switch exporter.status {
            case .completed:
                print("Filter export completed successfully")
                completion(.success(outURL))
            case .failed, .cancelled:
                let error = exporter.error ?? NSError(domain: "Filter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                print("Filter export failed: \(error)")
                completion(.failure(error))
            default:
                print("Filter export in progress")
                break
            }
        }
    }

    private func saveVideoToPhotos(_ fileURL: URL) {
        // Check if file exists before attempting to save
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist at path: \(fileURL.path)")
            return
        }

        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                print("File size: \(fileSize.intValue) bytes")
            }
        } catch {
            print("Failed to get file attributes: \(error)")
        }

        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                print("Photos authorization status: \(status.rawValue)")
                guard status == .authorized else {
                    print("Photos add-only access not authorized")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if success {
                        print("Video saved to Photos successfully")
                    } else if let error {
                        print("Save error: \(error)")
                    } else {
                        print("Save failed with unknown error")
                    }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                print("Photos authorization status: \(status.rawValue)")
                guard status == .authorized else {
                    print("Photos access not authorized")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if success {
                        print("Video saved to Photos successfully")
                    } else if let error {
                        print("Save error: \(error)")
                    } else {
                        print("Save failed with unknown error")
                    }
                }
            }
        }
    }
}

#if canImport(SCSDKCameraKit)
// MARK: - Snap Camera Kit (optional)
extension CameraViewModel {
    func tryStartSnapIfConfigured(useAR: Bool = true) {
        guard !snapApiToken.isEmpty, !snapLensID.isEmpty else { return }
        if snapAR == nil { snapAR = SnapARCamera() }
        snapAR?.onLensReady = { [weak self] ok in
            guard let self else { return }
            self.useSnapAR = ok
            // Disable our Core Image filter when Snap AR is active
            if ok { self.isFilterOn = false }
        }
        snapAR?.start(with: controller.session, apiToken: snapApiToken, useAR: useAR)
        snapAR?.applyLens(id: snapLensID, groupId: snapLensGroupID)
    }

    // Returns a Camera Kit PreviewView when Snap AR is active
    func snapPreviewIfActive() -> PreviewView? {
        guard useSnapAR else { return nil }
        return snapAR?.previewView()
    }
}
#endif
