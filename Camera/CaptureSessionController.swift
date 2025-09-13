//
//  CaptureSessionController.swift
//  Camera
//
//  Created by Assistant on 12/09/25.
//

import Foundation
import AVFoundation
import UIKit

final class CaptureSessionController: NSObject {
    enum DesiredFrameRate: Int {
        case fps30 = 30
        case fps60 = 60
    }

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private(set) var movieFileOutput: AVCaptureMovieFileOutput?

    private(set) var currentFrameRate: DesiredFrameRate = .fps30
    var preferredStabilizationMode: AVCaptureVideoStabilizationMode = .cinematic

    var isSessionRunning: Bool { session.isRunning }

    private(set) var isHDREnabled: Bool = false
    private var desiredTorchEnabled: Bool = false

    // Current camera position convenience
    var currentPosition: AVCaptureDevice.Position {
        if let pos = videoDeviceInput?.device.position { return pos }
        if let pos = videoDevice?.position { return pos }
        return .unspecified
    }

    // MARK: - Permissions
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var videoGranted = false
        var audioGranted = false

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            videoGranted = granted
            group.leave()
        }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            audioGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            completion(videoGranted && audioGranted)
        }
    }

    // MARK: - Configure
    func configureSession(desiredFrameRate: DesiredFrameRate = .fps60,
                          position: AVCaptureDevice.Position = .front,
                          completion: ((Error?) -> Void)? = nil) {
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                // Video device: prefer virtual devices/TrueDepth; default to requested position
                let device = try self.findBestCamera(for: position)
                self.videoDevice = device

                // Remove existing inputs
                if let existingVideo = self.videoDeviceInput {
                    self.session.removeInput(existingVideo)
                    self.videoDeviceInput = nil
                }
                if let existingAudio = self.audioDeviceInput {
                    self.session.removeInput(existingAudio)
                    self.audioDeviceInput = nil
                }

                // Add video input
                let videoInput = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.videoDeviceInput = videoInput
                }

                // Add audio input
                if let audioDevice = AVCaptureDevice.default(for: .audio) {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                        self.audioDeviceInput = audioInput
                    }
                }

                // Set frame rate and best format
                try self.setFrameRateLocked(to: desiredFrameRate.rawValue)
                self.currentFrameRate = desiredFrameRate

                // Prepare movie output
                if self.movieFileOutput == nil {
                    let output = AVCaptureMovieFileOutput()
                    // Enable cinematic stabilization if supported
                    if self.session.canAddOutput(output) {
                        self.session.addOutput(output)
                        self.movieFileOutput = output
                    }
                }

                // Stabilization
                self.applyPreferredStabilizationMode()
                // Ensure mirroring behavior matches current camera side (front mirrored)
                self.applyMirroringForCurrentPosition()

                // Default to HEVC when supported
                self.setPreferredCodecHEVC(true)

                // Ensure we start at 1x zoom synchronously
                if let dev = self.videoDeviceInput?.device ?? self.videoDevice {
                    do {
                        try dev.lockForConfiguration()
                        let minZ = dev.minAvailableVideoZoomFactor
                        let maxZ = dev.maxAvailableVideoZoomFactor
                        let target: CGFloat = max(minZ, min(1.0, maxZ))
                        dev.videoZoomFactor = target
                        dev.unlockForConfiguration()
                    } catch {
                        // Fallback to async setter if locking fails
                        self.setZoomTo(1.0, animated: false)
                    }
                }

                self.session.commitConfiguration()
                // Re-assert 1x after commit to avoid format resets setting 0.5x
                self.setZoomTo(1.0, animated: false)
                DispatchQueue.main.async {
                    completion?(nil)
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Focus / Exposure
    func focusAndExpose(at devicePoint: CGPoint) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .continuousAutoFocus
                }

                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }

                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {
                print("Focus/Exposure error: \(error)")
            }
        }
    }

    // MARK: - Zoom
    // Convenience: clamp and (optionally) animate to target zoom
    func setZoomTo(_ factor: CGFloat, animated: Bool = true, rate: Float = 8.0) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device ?? self.videoDevice else { return }
            let minZ = device.minAvailableVideoZoomFactor
            let maxZ = device.maxAvailableVideoZoomFactor
            let target = max(minZ, min(maxZ, factor))
            do {
                try device.lockForConfiguration()
                if animated {
                    if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                    device.ramp(toVideoZoomFactor: target, withRate: rate)
                } else {
                    device.videoZoomFactor = target
                }
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }
    func setZoomFactor(_ factor: CGFloat, animated: Bool = false, rampRate: Float = 4.0) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.maxAvailableVideoZoomFactor, 6.0) // Limit for quality
            let clamped = max(minZoom, min(factor, maxZoom))
            do {
                try device.lockForConfiguration()
                if animated {
                    if device.isRampingVideoZoom {
                        device.cancelVideoZoomRamp()
                    }
                    device.ramp(toVideoZoomFactor: clamped, withRate: rampRate)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    func currentZoomFactor() -> CGFloat {
        var value: CGFloat = 1.0
        sessionQueue.sync {
            if let device = self.videoDevice {
                value = device.videoZoomFactor
            }
        }
        return value
    }


    func cancelZoomRamp() {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.unlockForConfiguration()
            } catch {
                print("Cancel zoom ramp error: \(error)")
            }
        }
    }


    // MARK: - Quick Jumps (0.5x / 1x / 2x)
    func jumpToHalfX() {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device ?? self.videoDevice else { return }
            // If virtual device supports 0.5x, just zoom
            if device.minAvailableVideoZoomFactor <= 0.5 {
                self.setZoomTo(0.5, animated: true)
                return
            }
            // Fallback (back camera only): switch to physical ultra-wide
            if self.currentPosition == .back,
               let ultra = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
                do {
                    try self.useDevice(ultra)
                    // Try to keep current frame rate if possible
                    try self.setFrameRateLocked(to: self.currentFrameRate.rawValue)
                    self.applyPreferredStabilizationMode()
                } catch {
                    print("Failed to switch to ultra-wide: \(error)")
                }
            } else {
                // As a last resort, attempt digital zoom to 0.5 which will clamp to min
                self.setZoomTo(0.5, animated: true)
            }
        }
    }

    func jumpToOneX() {
        sessionQueue.async {
            let current = self.videoDeviceInput?.device ?? self.videoDevice
            let isUltraWide = (current?.deviceType == .builtInUltraWideCamera)
            if isUltraWide {
                // Switch back to wide if currently on physical ultra-wide
                if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    do {
                        try self.useDevice(wide)
                        try self.setFrameRateLocked(to: self.currentFrameRate.rawValue)
                        self.applyPreferredStabilizationMode()
                    } catch {
                        print("Failed to switch to wide: \(error)")
                    }
                }
                // On physical wide, 1.0 is correct magnification
                self.setZoomTo(1.0, animated: true)
            } else {
                // On virtual device (or already wide), just zoom to 1x
                self.setZoomTo(1.0, animated: true)
            }
        }
    }

    func jumpToTwoX() {
        // On virtual devices, 2x will switch to telephoto automatically if present
        setZoomTo(2.0, animated: true)
    }

    // MARK: - Frame Rate / Format
    func setFrameRate(to desired: DesiredFrameRate, completion: ((Bool) -> Void)? = nil) {
        sessionQueue.async {
            do {
                try self.setFrameRateLocked(to: desired.rawValue)
                self.currentFrameRate = desired
                self.applyPreferredStabilizationMode()
                DispatchQueue.main.async { completion?(true) }
            } catch {
                print("Failed to set frame rate: \(error)")
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    private func setFrameRateLocked(to fps: Int) throws {
        guard let device = videoDevice else { throw NSError(domain: "CaptureSessionController", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video device"]) }
        let desiredFPS = Double(fps)

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Pick best format supporting desired FPS with highest resolution
        var bestFormat: AVCaptureDevice.Format?
        var bestDimensions = CMVideoDimensions(width: 0, height: 0)
        var bestRange: AVFrameRateRange?

        for format in device.formats {
            let ranges = format.videoSupportedFrameRateRanges
            guard let range = ranges.first(where: { $0.maxFrameRate >= desiredFPS }) else { continue }
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)

            // Prefer higher resolution
            let isBetter = Int64(dims.width) * Int64(dims.height) > Int64(bestDimensions.width) * Int64(bestDimensions.height)
            if isBetter {
                bestFormat = format
                bestDimensions = dims
                bestRange = range
            }
        }

        if let bestFormat {
            device.activeFormat = bestFormat
            if let bestRange {
                let clampedFPS = min(bestRange.maxFrameRate, desiredFPS)
                let duration = CMTimeMake(value: 1, timescale: Int32(clampedFPS))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
        } else {
            // Fall back to current format with closest supported FPS
            if let range = device.activeFormat.videoSupportedFrameRateRanges.first {
                let clampedFPS = min(range.maxFrameRate, desiredFPS)
                let duration = CMTimeMake(value: 1, timescale: Int32(clampedFPS))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
        }
    }

    // MARK: - Stabilization
    func applyPreferredStabilizationMode() {
        guard let output = movieFileOutput else { return }
        for connection in output.connections {
            for port in connection.inputPorts where port.mediaType == .video {
                if connection.isVideoStabilizationSupported {
                    // Set preferred mode directly; SDK may fall back if unsupported
                    connection.preferredVideoStabilizationMode = preferredStabilizationMode
                }
            }
        }
    }

    // MARK: - Orientation
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        sessionQueue.async {
            guard let output = self.movieFileOutput else { return }
            for connection in output.connections {
                for port in connection.inputPorts where port.mediaType == .video {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = orientation
                    }
                    // Keep mirroring consistent whenever we touch the connection
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = (self.currentPosition == .front)
                    }
                }
            }
        }
    }

    // MARK: - HDR
    func setHDREnabled(_ enabled: Bool) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.activeFormat.isVideoHDRSupported {
                    // Disable automatic HDR adjustment before manually setting HDR
                    if device.automaticallyAdjustsVideoHDREnabled {
                        device.automaticallyAdjustsVideoHDREnabled = false
                    }
                    device.isVideoHDREnabled = enabled
                    self.isHDREnabled = enabled
                } else {
                    self.isHDREnabled = false
                }
                device.unlockForConfiguration()
            } catch {
                print("HDR error: \(error)")
            }
        }
    }

    // MARK: - Codec
    func setPreferredCodecHEVC(_ enabled: Bool) {
        sessionQueue.async {
            guard let output = self.movieFileOutput,
                  let connection = output.connection(with: .video) else { return }
            let available = output.availableVideoCodecTypes
            if enabled, available.contains(.hevc) {
                output.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
            } else if available.contains(.h264) {
                output.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
            } else {
                output.setOutputSettings(nil, for: connection)
            }
        }
    }

    // MARK: - Helpers
    private func findBestCamera(for position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        if position == .back {
            // Prefer virtual devices first for smooth, system-managed lens switching
            let types: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
            if let first = discovery.devices.first { return first }
            for t in types { if let d = AVCaptureDevice.default(t, for: .video, position: .back) { return d } }
        } else if position == .front {
            // Front: prefer TrueDepth, then wide angle
            let types: [AVCaptureDevice.DeviceType] = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .front)
            if let first = discovery.devices.first { return first }
            for t in types { if let d = AVCaptureDevice.default(t, for: .video, position: .front) { return d } }
        }
        throw NSError(domain: "CaptureSessionController", code: -2, userInfo: [NSLocalizedDescriptionKey: "No camera available for position \(position)"])
    }

    // Swap current video input to a specific device, preserving outputs
    private func useDevice(_ device: AVCaptureDevice) throws {
        let newInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        // Remove existing video input
        if let current = self.videoDeviceInput {
            session.removeInput(current)
        }
        guard session.canAddInput(newInput) else {
            session.commitConfiguration()
            throw NSError(domain: "CaptureSessionController", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        session.addInput(newInput)
        self.videoDeviceInput = newInput
        self.videoDevice = device

        // Ensure movie output exists
        if self.movieFileOutput == nil {
            let output = AVCaptureMovieFileOutput()
            if session.canAddOutput(output) { session.addOutput(output); self.movieFileOutput = output }
        } else if let output = self.movieFileOutput, !session.outputs.contains(output) {
            if session.canAddOutput(output) { session.addOutput(output) }
        }
        // Apply stabilization if supported
        self.applyPreferredStabilizationMode()
        // Apply mirroring for the newly selected side
        self.applyMirroringForCurrentPosition()
        session.commitConfiguration()
    }

    // MARK: - Camera switching
    func toggleCameraPosition() {
        sessionQueue.async {
            let next: AVCaptureDevice.Position = (self.currentPosition == .front) ? .back : .front
            do {
                let device = try self.findBestCamera(for: next)
                try self.useDevice(device)
                try self.setFrameRateLocked(to: self.currentFrameRate.rawValue)
                self.applyPreferredStabilizationMode()
                // Reset zoom to 1x when switching sides
                self.setZoomTo(1.0, animated: false)
                // Re-apply desired torch state on the new device side (no-op if unsupported)
                self.applyDesiredTorchState()
                // Keep mirroring consistent with the new side
                self.applyMirroringForCurrentPosition()
            } catch {
                print("Failed to toggle camera: \(error)")
            }
        }
    }

    // MARK: - Torch (Flash)
    func isTorchSupported() -> Bool {
        var supported = false
        sessionQueue.sync {
            if let device = self.videoDevice {
                supported = device.hasTorch && device.isTorchAvailable
            }
        }
        return supported
    }

    func setTorchEnabled(_ enabled: Bool) {
        sessionQueue.async {
            self.desiredTorchEnabled = enabled
            guard let device = self.videoDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if enabled {
                    let level = min(max(0.0, AVCaptureDevice.maxAvailableTorchLevel), 1.0)
                    if device.isTorchModeSupported(.on) {
                        try device.setTorchModeOn(level: level)
                    } else {
                        device.torchMode = .on
                    }
                } else {
                    if device.isTorchActive || device.torchMode != .off {
                        device.torchMode = .off
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch error: \(error)")
            }
        }
    }

    private func applyDesiredTorchState() {
        guard desiredTorchEnabled else {
            // If desired is off, ensure torch is off when supported
            setTorchEnabled(false)
            return
        }
        // Turn on if supported on current device
        if isTorchSupported() {
            setTorchEnabled(true)
        }
    }

    // Ensure output mirroring matches current camera side so recorded video matches preview
    private func applyMirroringForCurrentPosition() {
        guard let output = self.movieFileOutput else { return }
        let shouldMirror = (self.currentPosition == .front)
        for connection in output.connections {
            for port in connection.inputPorts where port.mediaType == .video {
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = shouldMirror
                }
            }
        }
    }
}
