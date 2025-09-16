//
//  TeleprompterTextView.swift
//  Camera
//
//  Created by Assistant on 13/09/25.
//

import SwiftUI
import UIKit

struct TeleprompterTextView: UIViewRepresentable {
    class Coordinator: NSObject, UITextViewDelegate {
        var isProgrammaticScroll = false
        var contentOffset: Binding<CGFloat>
        var onHeightChange: (CGFloat) -> Void
        var lastTextSignature: Int = 0
        var lastFontSize: CGFloat = 0
        var lastLineSpacing: CGFloat = 0
        var lastInsets: UIEdgeInsets = .zero
        var lastContentWidth: CGFloat = 0

        init(contentOffset: Binding<CGFloat>, onHeightChange: @escaping (CGFloat) -> Void) {
            self.contentOffset = contentOffset
            self.onHeightChange = onHeightChange
        }

        func recordState(text: String, fontSize: CGFloat, lineSpacing: CGFloat, insets: UIEdgeInsets, contentWidth: CGFloat) {
            lastTextSignature = text.hashValue
            lastFontSize = fontSize
            lastLineSpacing = lineSpacing
            lastInsets = insets
            lastContentWidth = contentWidth
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll else { return }
            let y = max(0, scrollView.contentOffset.y)
            if abs(contentOffset.wrappedValue - y) > 0.5 {
                contentOffset.wrappedValue = y
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Keep height updated if the system reflows
            textView.layoutIfNeeded()
            let h = textView.contentSize.height
            DispatchQueue.main.async { self.onHeightChange(h) }
        }
    }

    var text: String
    var fontSize: CGFloat
    @Binding var contentOffset: CGFloat
    var isScrollEnabled: Bool
    var userInteractionEnabled: Bool
    var topInset: CGFloat
    var bottomInset: CGFloat
    var horizontalPadding: CGFloat = 16
    var lineSpacing: CGFloat = 4
    var onContentHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(contentOffset: $contentOffset, onHeightChange: onContentHeightChange) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isSelectable = false
        // Keep scroll enabled so programmatic contentOffset updates work during playback
        tv.isScrollEnabled = true
        tv.isUserInteractionEnabled = userInteractionEnabled
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.textContainerInset = UIEdgeInsets(top: topInset, left: horizontalPadding, bottom: bottomInset, right: horizontalPadding)
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyText(to: tv)

        let inset = UIEdgeInsets(top: topInset, left: horizontalPadding, bottom: bottomInset, right: horizontalPadding)
        context.coordinator.recordState(
            text: text,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            insets: inset,
            contentWidth: max(0, tv.bounds.width - inset.left - inset.right)
        )

        // Initial height propagation
        DispatchQueue.main.async {
            self.updateContentSize(from: tv)
        }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Update scroll enable state
        // Always keep scrolling enabled for programmatic updates; toggle user interaction only
        if tv.isUserInteractionEnabled != userInteractionEnabled {
            tv.isUserInteractionEnabled = userInteractionEnabled
        }

        // Update insets if needed
        let desiredInset = UIEdgeInsets(top: topInset, left: horizontalPadding, bottom: bottomInset, right: horizontalPadding)
        let insetsChanged = tv.textContainerInset != desiredInset
        if insetsChanged {
            tv.textContainerInset = desiredInset
        }

        let currentContentWidth = max(0, tv.bounds.width - desiredInset.left - desiredInset.right)
        let textSignature = text.hashValue
        let textChanged = context.coordinator.lastTextSignature != textSignature
        let fontChanged = abs(context.coordinator.lastFontSize - fontSize) > .ulpOfOne
        let spacingChanged = abs(context.coordinator.lastLineSpacing - lineSpacing) > .ulpOfOne
        let widthChanged = abs(context.coordinator.lastContentWidth - currentContentWidth) > 0.5

        if textChanged || fontChanged || spacingChanged {
            applyText(to: tv)
        }

        if textChanged || fontChanged || spacingChanged || insetsChanged || widthChanged {
            updateContentSize(from: tv)
            context.coordinator.recordState(
                text: text,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                insets: desiredInset,
                contentWidth: currentContentWidth
            )
        }

        // Apply programmatic contentOffset from binding when needed
        let currentY = tv.contentOffset.y
        if abs(currentY - contentOffset) > 0.5 {
            context.coordinator.isProgrammaticScroll = true
            tv.setContentOffset(CGPoint(x: 0, y: max(0, contentOffset)), animated: false)
            context.coordinator.isProgrammaticScroll = false
        }
    }

    private func applyText(to tv: UITextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .paragraphStyle: paragraph
        ]
        tv.attributedText = NSAttributedString(string: text, attributes: attrs)
    }

    fileprivate func updateContentSize(from tv: UITextView) {
        // Force layout before querying contentSize
        tv.layoutIfNeeded()
        let height = tv.contentSize.height
        if height > 0 {
            DispatchQueue.main.async {
                onContentHeightChange(height)
            }
        }
    }
}
