//
//  TeleprompterViewModel.swift
//  Camera
//
//  Created by Assistant on 13/09/25.
//

import SwiftUI
import Combine

// MARK: - Configuration
struct TeleprompterConfig {
    static let minFontSize: CGFloat = 18
    static let maxFontSize: CGFloat = 36
    static let minSpeed: Double = 8
    static let maxSpeed: Double = 60
    static let defaultOverlayWidthRatio: CGFloat = 0.98
    static let defaultOverlayHeightRatio: CGFloat = 0.42
    static let minOverlayWidth: CGFloat = 260
    static let minOverlayHeight: CGFloat = 170
    static let scrollFrameRate: Double = 60.0
    static let viewportPadding: CGFloat = 56
    static let compactViewportPadding: CGFloat = 36
    static let contentPadding: CGFloat = 32
    static let textVerticalPadding: CGFloat = 80
    static let pauseAtEndDefault: Bool = true
}

// MARK: - View Model
@MainActor
final class TeleprompterViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var contentOffset: CGFloat = 0
    @Published var isEditorPresented: Bool = false
    @Published var overlaySize: CGSize = .zero
    @Published var overlayOffset: CGSize = .zero
    @Published var isPlaying: Bool = false
    @Published var isInteracting: Bool = false
    @Published var pauseAtEnd: Bool = TeleprompterConfig.pauseAtEndDefault
    
    // Cached values for performance
    private var cachedContentHeight: CGFloat = 0
    private var lastContentSignature: String = ""
    private var scrollTimer: Timer?
    private var lastTickTime: Date = Date()
    private var scheduledUpdate: DispatchWorkItem?
    private var scheduledClamp: DispatchWorkItem?
    private var initialManualOffset: CGFloat = 0
    private(set) var isManualScrolling: Bool = false
    
    // Initial drag/resize positions
    var initialDragOffset: CGSize = .zero
    var initialResizeSize: CGSize = .zero
    
    // MARK: - Scrolling Management
    func startScrolling(speed: Double, viewportHeight: CGFloat) {
        guard speed > 0 else { return }
        
        stopScrolling(resetOffset: false)
        lastTickTime = Date()
        
        // If there is nothing to scroll, ensure offset is zero and do not start the timer
        let initialMax = max(0, cachedContentHeight - viewportHeight)
        guard initialMax > 0 else {
            contentOffset = 0
            return
        }

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/TeleprompterConfig.scrollFrameRate, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let now = Date()
            let deltaTime = now.timeIntervalSince(self.lastTickTime)
            self.lastTickTime = now
            
            let maxOffset = max(0, self.cachedContentHeight - viewportHeight)
            if maxOffset <= 0 { self.contentOffset = 0; return }
            
            self.contentOffset += speed * deltaTime
            if self.contentOffset >= maxOffset {
                if self.pauseAtEnd {
                    self.contentOffset = maxOffset
                    self.scrollTimer?.invalidate()
                    self.scrollTimer = nil
                    self.isPlaying = false
                } else {
                    self.contentOffset = 0
                }
            }
        }
    }
    
    func stopScrolling(resetOffset: Bool = true) {
        scrollTimer?.invalidate()
        scrollTimer = nil
        if resetOffset { contentOffset = 0 }
    }
    
    // MARK: - Content Height Management
    func updateContentHeight(text: String, fontSize: CGFloat, width: CGFloat) {
        let signature = "\(text.hashValue)|\(fontSize)|\(Int(width))"
        guard signature != lastContentSignature else { return }
        
        let oldHeight = cachedContentHeight
        cachedContentHeight = calculateContentHeight(text: text, fontSize: fontSize, width: width)
        lastContentSignature = signature
        
        // Preserve relative offset to avoid visible flicker during resize/move
        if oldHeight > 0, cachedContentHeight > 0 {
            let ratio = contentOffset / max(1, max(0, oldHeight))
            let maxNew = max(0, cachedContentHeight)
            contentOffset = max(0, min(maxNew, ratio * maxNew))
        }
    }

    // Debounced update while interacting
    func scheduleContentHeightUpdate(text: String, fontSize: CGFloat, width: CGFloat) {
        if isInteracting {
            scheduledUpdate?.cancel()
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.updateContentHeight(text: text, fontSize: fontSize, width: width)
                }
            }
            scheduledUpdate = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        } else {
            updateContentHeight(text: text, fontSize: fontSize, width: width)
        }
    }

    func clampOffset(viewportHeight: CGFloat) {
        let maxOffset = max(0, cachedContentHeight - viewportHeight)
        contentOffset = max(0, min(contentOffset, maxOffset))
    }
    
    func scheduleClampOffset(viewportHeight: CGFloat) {
        if isInteracting {
            scheduledClamp?.cancel()
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.clampOffset(viewportHeight: viewportHeight)
                }
            }
            scheduledClamp = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        } else {
            clampOffset(viewportHeight: viewportHeight)
        }
    }

    func beginInteraction() { isInteracting = true }
    func endInteraction() {
        isInteracting = false
        if let pending = scheduledUpdate { pending.perform() }
        if let pendingClamp = scheduledClamp { pendingClamp.perform() }
        scheduledUpdate = nil
        scheduledClamp = nil
    }

    // MARK: - Manual Scroll (user drag)
    func beginManualScroll(isRecording: Bool) {
        guard !isRecording else { return }
        if isManualScrolling { return }
        if isPlaying { stopScrolling(resetOffset: false); isPlaying = false }
        beginInteraction()
        initialManualOffset = contentOffset
        isManualScrolling = true
    }

    func updateManualScroll(translation heightDelta: CGFloat, viewportHeight: CGFloat) {
        let maxOffset = max(0, cachedContentHeight - viewportHeight)
        // Drag up (negative) -> increase offset; Drag down (positive) -> decrease offset
        let proposed = initialManualOffset - heightDelta
        contentOffset = max(0, min(maxOffset, proposed))
    }

    func endManualScroll(viewportHeight: CGFloat) {
        clampOffset(viewportHeight: viewportHeight)
        endInteraction()
        isManualScrolling = false
    }
    
    private func calculateContentHeight(text: String, fontSize: CGFloat, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return TeleprompterConfig.textVerticalPadding }

        // Mirror typography from ScrollingTextView
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .paragraphStyle: paragraphStyle
        ]
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width - TeleprompterConfig.contentPadding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        // Include internal vertical padding used in ScrollingTextView
        return boundingRect.height + TeleprompterConfig.textVerticalPadding
    }
    
    // MARK: - Position Management
    func initializeOverlay(parentSize: CGSize) {
        guard overlaySize == .zero else { return }
        
        let defaultWidth = parentSize.width * TeleprompterConfig.defaultOverlayWidthRatio
        let defaultHeight = parentSize.height * TeleprompterConfig.defaultOverlayHeightRatio
        
        overlaySize = CGSize(
            width: max(defaultWidth, TeleprompterConfig.minOverlayWidth),
            height: max(defaultHeight, TeleprompterConfig.minOverlayHeight)
        )
        initialResizeSize = overlaySize
    }
    
    func updateOverlayPosition(translation: CGSize) {
        if !isInteracting { beginInteraction() }
        overlayOffset = CGSize(
            width: initialDragOffset.width + translation.width,
            height: initialDragOffset.height + translation.height
        )
    }
    
    func finalizeOverlayPosition(parentSize: CGSize) {
        let margin: CGFloat = 24
        let minX = -(parentSize.width - margin)
        let maxX = parentSize.width - margin
        let minY = -(parentSize.height - margin)
        let maxY = parentSize.height - margin
        
        overlayOffset.width = max(minX, min(maxX, overlayOffset.width))
        overlayOffset.height = max(minY, min(maxY, overlayOffset.height))
        initialDragOffset = overlayOffset
        endInteraction()
    }
    
    func resizeOverlay(translation: CGSize, parentSize: CGSize) {
        if !isInteracting { beginInteraction() }
        var newWidth = initialResizeSize.width + translation.width
        var newHeight = initialResizeSize.height + translation.height
        
        newWidth = max(TeleprompterConfig.minOverlayWidth, min(parentSize.width, newWidth))
        newHeight = max(TeleprompterConfig.minOverlayHeight, min(parentSize.height, newHeight))
        
        overlaySize = CGSize(width: newWidth, height: newHeight)
    }
    
    func finalizeResize() {
        initialResizeSize = overlaySize
        endInteraction()
    }
    
    // MARK: - Recording State
    func handleRecordingStateChange(isRecording: Bool, speed: Double, viewportHeight: CGFloat) {
        updateScrollState(isRecording: isRecording, speed: speed, viewportHeight: viewportHeight)
    }

    func togglePlay(isRecording: Bool, speed: Double, viewportHeight: CGFloat) {
        isPlaying.toggle()
        updateScrollState(isRecording: isRecording, speed: speed, viewportHeight: viewportHeight)
    }

    func updateScrollState(isRecording: Bool, speed: Double, viewportHeight: CGFloat) {
        if isRecording || isPlaying {
            isEditorPresented = false
            startScrolling(speed: speed, viewportHeight: viewportHeight)
        } else {
            stopScrolling(resetOffset: false)
        }
    }
    
    deinit {
        scrollTimer?.invalidate()
    }
}
