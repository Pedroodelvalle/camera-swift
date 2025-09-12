//
//  SegmentedRecorder.swift
//  Camera
//
//  Created by Assistant on 12/09/25.
//

import Foundation
import AVFoundation
import Photos
import UIKit

protocol SegmentedRecorderDelegate: AnyObject {
    func recorder(_ recorder: SegmentedRecorder, didFinishSegment url: URL)
    func recorder(_ recorder: SegmentedRecorder, didFailWith error: Error)
}

final class SegmentedRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let controller: CaptureSessionController
    private let output: AVCaptureMovieFileOutput
    weak var delegate: SegmentedRecorderDelegate?

    private var activeTempURL: URL?
    private var orientation: AVCaptureVideoOrientation = .portrait
    var saveToPhotoLibrary: Bool = true

    init?(controller: CaptureSessionController) {
        guard let fileOutput = controller.movieFileOutput else { return nil }
        self.controller = controller
        self.output = fileOutput
        super.init()
    }

    var isRecording: Bool { output.isRecording }

    func startNewSegment() {
        let tempURL = Self.createTempMovieURL()
        activeTempURL = tempURL
        let connection = output.connection(with: .video)
        if let connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
        output.startRecording(to: tempURL, recordingDelegate: self)
    }

    func stopCurrentSegment() {
        guard output.isRecording else { return }
        output.stopRecording()
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error { delegate?.recorder(self, didFailWith: error); return }
        if saveToPhotoLibrary {
            Self.saveVideoToPhotos(outputFileURL) { result in
                switch result {
                case .success:
                    break
                case .failure(let err):
                    self.delegate?.recorder(self, didFailWith: err)
                }
            }
        }
        delegate?.recorder(self, didFinishSegment: outputFileURL)
    }

    // MARK: - Helpers
    private static func createTempMovieURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "segment_" + UUID().uuidString + ".mov"
        return dir.appendingPathComponent(filename)
    }

    private static func saveVideoToPhotos(_ fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized else {
                    completion(.failure(NSError(domain: "SegmentedRecorder", code: -10, userInfo: [NSLocalizedDescriptionKey: "Photos add-only access not authorized"])));
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if let error { completion(.failure(error)) }
                    else if success { completion(.success(())) }
                    else { completion(.failure(NSError(domain: "SegmentedRecorder", code: -11, userInfo: [NSLocalizedDescriptionKey: "Unknown save failure"]))) }
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    completion(.failure(NSError(domain: "SegmentedRecorder", code: -10, userInfo: [NSLocalizedDescriptionKey: "Photos access not authorized"])));
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .video, fileURL: fileURL, options: nil)
                }) { success, error in
                    if let error { completion(.failure(error)) }
                    else if success { completion(.success(())) }
                    else { completion(.failure(NSError(domain: "SegmentedRecorder", code: -11, userInfo: [NSLocalizedDescriptionKey: "Unknown save failure"]))) }
                }
            }
        }
    }

    // MARK: - Orientation
    func updateOrientation(from deviceOrientation: UIDeviceOrientation) {
        if let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
            orientation = videoOrientation
        }
    }
}


