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

        init(contentOffset: Binding<CGFloat>, onHeightChange: @escaping (CGFloat) -> Void) {
            self.contentOffset = contentOffset
            self.onHeightChange = onHeightChange
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
        if tv.textContainerInset != desiredInset { tv.textContainerInset = desiredInset }

        // Update text attributes when text or font changes
        if tv.attributedText.string != text || tv.font?.pointSize != fontSize {
            applyText(to: tv)
            // After reflow, recompute size and reset offset if needed will be handled externally
            updateContentSize(from: tv)
        } else {
            // Still ensure the height stays fresh
            updateContentSize(from: tv)
        }

        // Apply programmatic contentOffset from binding
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
