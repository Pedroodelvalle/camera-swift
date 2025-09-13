//
//  TeleprompterOverlay.swift
//  Camera
//
//  Created by Assistant on 13/09/25.
//

import SwiftUI

// MARK: - Main Overlay View
struct TeleprompterOverlay: View {
    @Binding var text: String
    @Binding var speed: Double
    @Binding var fontSize: CGFloat
    @Binding var isRecording: Bool
    
    @StateObject private var viewModel = TeleprompterViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            overlayContent(in: geometry)
                .onAppear {
                    viewModel.initializeOverlay(parentSize: geometry.size)
                    viewModel.updateContentHeight(text: text, fontSize: fontSize, width: viewModel.overlaySize.width)
                }
                .onChange(of: isRecording) { newValue in
                    let viewportHeight = max(viewModel.overlaySize.height - TeleprompterConfig.viewportPadding, 80)
                    viewModel.handleRecordingStateChange(isRecording: newValue, speed: speed, viewportHeight: viewportHeight)
                }
                .onChange(of: text) { _ in
                    viewModel.scheduleContentHeightUpdate(text: text, fontSize: fontSize, width: viewModel.overlaySize.width)
                    let vp = max(viewModel.overlaySize.height - TeleprompterConfig.viewportPadding, 80)
                    viewModel.scheduleClampOffset(viewportHeight: vp)
                }
                .onChange(of: fontSize) { _ in
                    viewModel.scheduleContentHeightUpdate(text: text, fontSize: fontSize, width: viewModel.overlaySize.width)
                    let vp = max(viewModel.overlaySize.height - TeleprompterConfig.viewportPadding, 80)
                    viewModel.scheduleClampOffset(viewportHeight: vp)
                }
                .onChange(of: viewModel.overlaySize) { _ in
                    viewModel.scheduleContentHeightUpdate(text: text, fontSize: fontSize, width: viewModel.overlaySize.width)
                    let vp = max(viewModel.overlaySize.height - TeleprompterConfig.viewportPadding, 80)
                    viewModel.scheduleClampOffset(viewportHeight: vp)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private func overlayContent(in geometry: GeometryProxy) -> some View {
        let currentSize = viewModel.overlaySize == .zero ? defaultSize(for: geometry.size) : viewModel.overlaySize
        let isScrolling = (isRecording || viewModel.isPlaying)
        let paddingToUse = isScrolling ? TeleprompterConfig.compactViewportPadding : TeleprompterConfig.viewportPadding
        let viewportHeight = max(currentSize.height - paddingToUse, 80)
        
        VStack(alignment: .leading, spacing: 0) {
            // Content viewport
            ZStack {
                if isRecording || viewModel.isPlaying {
                    ScrollingTextView(
                        text: text,
                        fontSize: fontSize,
                        offset: viewModel.contentOffset,
                        height: viewportHeight,
                        isInteracting: viewModel.isInteracting
                    )
                } else {
                    EditableTextPreview(
                        text: text,
                        fontSize: fontSize,
                        height: viewportHeight,
                        onTap: { if !viewModel.isManualScrolling { viewModel.isEditorPresented = true } },
                        isInteracting: viewModel.isInteracting,
                        offset: viewModel.contentOffset
                    )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        guard !isRecording && !viewModel.isPlaying else { return }
                        if abs(value.translation.height) < 4 { return }
                        viewModel.beginManualScroll(isRecording: isRecording)
                        viewModel.updateManualScroll(translation: value.translation.height, viewportHeight: viewportHeight)
                    }
                    .onEnded { value in
                        guard !isRecording && !viewModel.isPlaying else { return }
                        if abs(value.translation.height) < 4 { return }
                        viewModel.endManualScroll(viewportHeight: viewportHeight)
                    }
            )
        }
        .frame(width: currentSize.width, height: currentSize.height, alignment: .topLeading)
        // Mask content to rounded corners to avoid square overlays bleeding in the corners
        // Avoid extra compositing during interaction: keep mask simple
        // Keep a single clipShape later; avoid double masks to reduce recomposition
        .background(TeleprompterBackground())
        // Top-right play/pause
        .overlay(
            PlayPauseButton(
                isPlaying: viewModel.isPlaying,
                onToggle: {
                    let vpPadding = (isRecording || viewModel.isPlaying) ? TeleprompterConfig.compactViewportPadding : TeleprompterConfig.viewportPadding
                    let vp = max(viewModel.overlaySize.height - vpPadding, 80)
                    viewModel.togglePlay(isRecording: isRecording, speed: speed, viewportHeight: vp)
                }
            )
            .padding(8)
            , alignment: .topTrailing
        )
        // Bottom bar: compact sliders centered only
        .overlay(
            BottomSlidersBar(
                fontSize: $fontSize,
                speed: $speed,
                showSliders: !isScrolling,
                maxContentWidth: currentSize.width
            )
            .frame(height: 48)
            .padding(.bottom, 6)
            , alignment: .bottom
        )
        // Bottom-left move handle
        .overlay(
            MoveHandle(viewModel: viewModel, parentSize: geometry.size)
                .padding(.leading, 6)
                .padding(.bottom, 6)
            , alignment: .bottomLeading
        )
        // Bottom-right resize handle
        .overlay(
            ResizeHandle(viewModel: viewModel, parentSize: geometry.size)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
            , alignment: .bottomTrailing
        )
        // Ensure overlays are clipped to the same rounded shape to avoid square corners
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .offset(viewModel.overlayOffset)
        // Disable implicit animations during interactive changes to prevent flicker
        .animation(viewModel.isInteracting ? .none : .default, value: viewModel.overlayOffset)
        .animation(viewModel.isInteracting ? .none : .default, value: viewModel.overlaySize)
        .sheet(isPresented: $viewModel.isEditorPresented) {
            TeleprompterEditorSheet(text: $text, fontSize: $fontSize)
                .preferredColorScheme(.dark)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.isEditorPresented) { newValue in
            if !newValue {
                viewModel.contentOffset = 0
            }
        }
    }
    
    private func defaultSize(for parentSize: CGSize) -> CGSize {
        let defaultWidth = parentSize.width * TeleprompterConfig.defaultOverlayWidthRatio
        let defaultHeight = parentSize.height * TeleprompterConfig.defaultOverlayHeightRatio
        
        return CGSize(
            width: max(min(defaultWidth, parentSize.width - 16), TeleprompterConfig.minOverlayWidth),
            height: max(defaultHeight, TeleprompterConfig.minOverlayHeight)
        )
    }
    
    // Global drag removed; movement is handled by a bottom-left handle.
}

// MARK: - Scrolling Text View
struct ScrollingTextView: View {
    let text: String
    let fontSize: CGFloat
    let offset: CGFloat
    let height: CGFloat
    let isInteracting: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                // Top buffer so the first line isn't clipped under the gradient when starting
                Color.clear.frame(height: TeleprompterConfig.textVerticalPadding / 2)

                Text(text.isEmpty ? "" : text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Bottom buffer to match height calculation and smooth wrap
                Color.clear.frame(height: TeleprompterConfig.textVerticalPadding / 2)
            }
            .offset(y: -offset)
        }
        .frame(height: height)
        .clipped()
        .overlay(
            Group {
                if !isInteracting {
                    LinearGradient(
                        colors: [Color.black.opacity(0.22), .clear, .clear, Color.black.opacity(0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .allowsHitTesting(false)
        )
    }
}

// MARK: - Editable Text Preview
struct EditableTextPreview: View {
    let text: String
    let fontSize: CGFloat
    let height: CGFloat
    let onTap: () -> Void
    let isInteracting: Bool
    let offset: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                // Top buffer to match ScrollingTextView layout
                Color.clear.frame(height: TeleprompterConfig.textVerticalPadding / 2)

                Text(text.isEmpty ? "Adicione seu roteiro aqui..." : text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(text.isEmpty ? .white.opacity(0.35) : .white.opacity(0.9))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Bottom buffer to match ScrollingTextView layout
                Color.clear.frame(height: TeleprompterConfig.textVerticalPadding / 2)
            }
            .offset(y: -offset)
        }
        .frame(height: height)
        .clipped()
        .overlay(
            Group {
                if !isInteracting {
                    LinearGradient(
                        colors: [Color.black.opacity(0.22), .clear, .clear, Color.black.opacity(0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Controls
struct TeleprompterControls: View {
    @Binding var fontSize: CGFloat
    @Binding var speed: Double
    @Binding var isPlaying: Bool
    var isScrolling: Bool
    var onTogglePlay: () -> Void

    var body: some View {
        HStack(spacing: isScrolling ? 6 : 10) {
            // Play/Pause
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isScrolling ? 10 : 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(isScrolling ? 4 : 6)
            }
            .buttonStyle(GlassCircleButtonStyle())

            if !isScrolling {
                // Font size control
                HStack(spacing: 6) {
                    Image(systemName: "textformat.size")
                    Slider(value: $fontSize, in: TeleprompterConfig.minFontSize...TeleprompterConfig.maxFontSize)
                }
                .tint(.white)

                // Speed control
                HStack(spacing: 6) {
                    Image(systemName: "tortoise.fill")
                    Slider(value: $speed, in: TeleprompterConfig.minSpeed...TeleprompterConfig.maxSpeed)
                }
                .tint(.white)
            }
        }
        .font(.system(size: isScrolling ? 10 : 12, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, isScrolling ? 6 : 10)
        .padding(.vertical, isScrolling ? 4 : 6)
    }
}

// MARK: - Background
struct TeleprompterBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.001), lineWidth: 0.001) // create explicit shape for shadow bounds
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.55), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Resize Handle
struct ResizeHandle: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    let parentSize: CGSize
    
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            )
            .padding(6)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.resizeOverlay(translation: value.translation, parentSize: parentSize)
                    }
                    .onEnded { _ in
                        viewModel.finalizeResize()
                    }
            )
    }
}

// MARK: - Move Handle (Bottom-Left)
struct MoveHandle: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    let parentSize: CGSize
    
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
            )
            .padding(6)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        viewModel.updateOverlayPosition(translation: value.translation)
                    }
                    .onEnded { _ in
                        viewModel.finalizeOverlayPosition(parentSize: parentSize)
                    }
            )
    }
}

// MARK: - Top-Right Play/Pause Button
struct PlayPauseButton: View {
    let isPlaying: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
        }
        .buttonStyle(GlassCircleButtonStyle())
        .accessibilityLabel(isPlaying ? "Pausar" : "Reproduzir")
    }
}

// MARK: - Compact Sliders Group
struct CompactSliders: View {
    @Binding var fontSize: CGFloat
    @Binding var speed: Double
    var maxWidth: CGFloat?
    
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "textformat.size")
                Slider(value: $fontSize, in: TeleprompterConfig.minFontSize...TeleprompterConfig.maxFontSize)
                    .frame(width: sliderWidth)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "tortoise.fill")
                Slider(value: $speed, in: TeleprompterConfig.minSpeed...TeleprompterConfig.maxSpeed)
                    .frame(width: sliderWidth)
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.white)
        .tint(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var sliderWidth: CGFloat {
        guard let maxWidth else { return 110 }
        // Reserve ~80 for icons and paddings within the pill, split remaining width
        let available = max(0, maxWidth - 80)
        return max(70, min(140, available / 2))
    }
}

// MARK: - Bottom Sliders Bar (center only)
struct BottomSlidersBar: View {
    @Binding var fontSize: CGFloat
    @Binding var speed: Double
    let showSliders: Bool
    let maxContentWidth: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let total = min(geo.size.width, maxContentWidth)
            HStack {
                Spacer(minLength: 0)
                if showSliders, total > 220 {
                    CompactSliders(
                        fontSize: $fontSize,
                        speed: $speed,
                        maxWidth: total - 40
                    )
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Editor Sheet
struct TeleprompterEditorSheet: View {
    @Binding var text: String
    @Binding var fontSize: CGFloat
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    textEditor
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Concluir") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                fontSizeControl
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Adicione seu roteiro aqui...")
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .tint(.white)
                .padding(.horizontal, 12)
                .padding(.top, 12)
        }
    }
    
    @ViewBuilder
    private var fontSizeControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat.size")
                .foregroundColor(.white.opacity(0.9))
            
            Slider(value: $fontSize, in: TeleprompterConfig.minFontSize...TeleprompterConfig.maxFontSize)
                .tint(.white)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        TeleprompterOverlay(
            text: .constant("Adicione seu roteiro aqui...\n\nDica: toque para editar."),
            speed: .constant(28),
            fontSize: .constant(28),
            isRecording: .constant(false)
        )
        .padding()
    }
}