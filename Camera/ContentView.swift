//
//  ContentView.swift
//  Camera
//
//  Created by Pedro Deboni Del Valle on 12/09/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CameraViewModel()
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?
    @State private var showDeleteConfirm: Bool = false
    @State private var segmentToDelete: CameraViewModel.RecordedSegment? = nil
    @State private var previewSegment: CameraViewModel.RecordedSegment?
    @State private var showFilterPicker: Bool = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Centered, inset camera preview that does not occupy the entire screen
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let horizontalInset: CGFloat = 0
                let containerWidth = totalWidth - horizontalInset * 2
                let desiredHeight = containerWidth * 16.0 / 9.0

                VStack {
                    Spacer(minLength: 0)

                    ZStack {
                        CameraPreviewRepresentable(model: model)

                        // Grid overlay (rule of thirds) - clipped to preview
                        if model.showGrid {
                            GridOverlay()
                                .allowsHitTesting(false)
                        }

                        // Lightweight overlay hint to approximate selected filter visually
                        if let overlay = previewOverlayColor(for: model.selectedFilter) {
                            overlay
                                .opacity(0.12)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(
                        width: containerWidth,
                        height: min(desiredHeight, geo.size.height * 0.92)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .offset(y: -30)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, horizontalInset)
            }

            VStack {
                // Top controls - hidden during recording, shows countdown instead
                if !model.isRecording {
                    HStack {
                        // Close button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(14)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Fechar câmera")

                        Spacer()

                        // Frame rate button
                        Button(action: { model.toggleFrameRate() }) {
                            Text(model.frameRateLabel.contains("60") ? "4K" : "HD")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Alternar entre HD e 4K")

                        // Grid toggle
                        Button(action: { model.toggleGrid() }) {
                            Image(systemName: model.showGrid ? "rectangle.split.3x3" : "rectangle.grid.2x2")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Alternar grade")

                        // Torch toggle
                        Button(action: { model.toggleTorch() }) {
                            Image(systemName: model.isTorchOn ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(model.isTorchOn ? .yellow : .white)
                                .padding(10)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Alternar flash")

                        // Teleprompter toggle
                        Button(action: { model.toggleTeleprompter() }) {
                            Image(systemName: model.isTeleprompterOn ? "text.viewfinder" : "text.bubble")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Alternar teleprompter")
                    }
                    .padding(.horizontal)
                    .padding(.top, 30)
                } else {
                    // Recording countdown - top center with smooth animation
                    HStack {
                        Spacer()
                        Text(timeString(from: countdown))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .center)))
                            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: countdown)
                        Spacer()
                    }
                    .padding(.top, 30)
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8, anchor: .center)))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.4), value: model.isRecording)
                }

                // Teleprompter overlay - positioned below top controls
                if model.isTeleprompterOn {
                    TeleprompterOverlay(
                        text: $model.teleprompterText,
                        speed: $model.teleprompterSpeed,
                        fontSize: $model.teleprompterFontSize,
                        isRecording: $model.isRecording
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .allowsHitTesting(true)
                }

                Spacer()

                // Botões de zoom acima do botão de gravar, ambos centralizados
                VStack(spacing: 16) {
                    // Quick zoom selector - centralizado
                    HStack(spacing: 16) {
                        Spacer(minLength: 0)
                    }
                    .overlay(
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { idx in
                                let label: String = (idx == 0 ? "0.5" : (idx == 1 ? "1" : "2"))
                                Text(label + "x")
                                    .font(.system(size: 12, weight: model.quickZoomIndex == idx ? .semibold : .medium))
                                    .foregroundStyle(model.quickZoomIndex == idx ? Color.yellow : Color.white.opacity(0.9))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        ZStack {
                                            if model.quickZoomIndex == idx {
                                                Circle()
                                                    .fill(Color.white.opacity(0.15))
                                                    .overlay(Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                                            } else {
                                                Circle()
                                                    .fill(Color.white.opacity(0.08))
                                            }
                                        }
                                    )
                                    .onTapGesture { model.selectQuickZoom(index: idx) }
                            }
                        }
                        .offset(y: -30) // Move zoom buttons up
                    )

                    // Botão de gravar - centralizado (sempre visível para parar/iniciar)
                    Button(action: { model.toggleRecording() }) {
                        ZStack {
                            // Borda branca sempre presente
                            Circle()
                                .fill(Color.white.opacity(0.1)) // Fundo semi-transparente
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(Color.white, lineWidth: 8))

                            // Círculo vermelho que diminui e fica mais quadrado arredondado quando grava
                            RoundedRectangle(cornerRadius: model.isRecording ? 12 : 38)
                                .fill(Color(red: 1.0, green: 94/255, blue: 87/255))
                                .frame(width: model.isRecording ? 42 : 76, height: model.isRecording ? 42 : 76)
                                .animation(.easeInOut(duration: 0.3), value: model.isRecording)
                        }
                    }
                }
                .padding(.bottom, 85)
            } 

            // Bottom-most strip of tiny take thumbnails
            if !model.segments.isEmpty {
                VStack {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(model.segments) { seg in
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        previewSegment = seg
                                    } label: {
                                        Image(uiImage: seg.thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 58)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        segmentToDelete = seg
                                        showDeleteConfirm = true
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 12, height: 12)
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Circle())
                                    }
                                    .padding(2)
                                }
                                .frame(width: 44, height: 58)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 52)
                    .padding(.bottom, 6)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Tap outside to dismiss the filter menu
            if showFilterPicker {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showFilterPicker = false } }
            }

            // Bottom-left: Filter button + vertical menu opening upward
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        if showFilterPicker {
                            FilterMenu(selected: model.selectedFilter) { chosen in
                                model.setFilter(chosen)
                                withAnimation(.easeOut(duration: 0.2)) { showFilterPicker = false }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .bottomLeading)),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }

                        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showFilterPicker.toggle() } }) {
                            Image(systemName: model.selectedFilter == .none ? "wand.and.stars" : "wand.and.stars.inverse")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(.white)
                                .padding(15)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        .accessibilityLabel("Escolher filtro")
                    }
                    Spacer()
                }
                .padding(.leading, 30)
                .padding(.bottom, 95)
            }

            // Bottom-right buttons: camera toggle remains in original spot
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { model.toggleCameraPosition() }) {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.white)
                            .padding(15)
                    }
                    .buttonStyle(GlassCircleButtonStyle())
                    .padding(.trailing, 30)
                    .padding(.bottom, 95)
                    .accessibilityLabel("Trocar câmera")
                }
            }

            // Bottom-right Next button below the camera toggle, in the footer corner
            if !model.segments.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { model.nextAction() }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(11)
                        }
                        .buttonStyle(GlassCircleButtonStyle(isProminent: true, accentColor: Color(red: 0x29/255.0, green: 0x84/255.0, blue: 0xf6/255.0)))
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                        .accessibilityLabel("Avançar")
                    }
                }
            }
        }
        .onAppear { model.requestPermissionsAndConfigure() }
        .onChange(of: model.isRecording) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.2)) { showFilterPicker = false }
                startCountdown()
            } else {
                stopCountdown()
            }
        }
        .onChange(of: model.isTeleprompterOn) { _ in
            withAnimation(.easeOut(duration: 0.2)) { showFilterPicker = false }
        }
        .sheet(item: $previewSegment) { segment in
            SegmentPlaybackView(
                segment: segment,
                onDelete: {
                    model.deleteSegment(segment)
                    previewSegment = nil
                },
                onClose: {
                    previewSegment = nil
                }
            )
        }
        .alert("Deseja apagar esse take?", isPresented: $showDeleteConfirm) {
            Button("Apagar", role: .destructive) {
                if let seg = segmentToDelete {
                    model.deleteSegment(seg)
                }
                segmentToDelete = nil
            }
            Button("Cancelar", role: .cancel) {
                segmentToDelete = nil
            }
        }
    }

    private func startCountdown() {
        countdown = 0
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            countdown += 1
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = 0
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

#Preview { ContentView() }

// MARK: - Preview Representable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let model: CameraViewModel

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        model.attachPreview(view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // Nothing dynamic for now
    }
}

// MARK: - Grid Overlay
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let vStep = h / 3
            let hStep = w / 3
            Path { p in
                // Horizontal lines
                p.move(to: CGPoint(x: 0, y: vStep))
                p.addLine(to: CGPoint(x: w, y: vStep))
                p.move(to: CGPoint(x: 0, y: 2 * vStep))
                p.addLine(to: CGPoint(x: w, y: 2 * vStep))
                // Vertical lines
                p.move(to: CGPoint(x: hStep, y: 0))
                p.addLine(to: CGPoint(x: hStep, y: h))
                p.move(to: CGPoint(x: 2 * hStep, y: 0))
                p.addLine(to: CGPoint(x: 2 * hStep, y: h))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
    }
}

// MARK: - Filter helpers
extension ContentView {
    func previewOverlayColor(for filter: CameraViewModel.VideoFilter) -> Color? {
        switch filter {
        case .none: return nil
        case .mono: return Color.black
        }
    }
}

struct SegmentPlaybackView: View {
    let segment: CameraViewModel.RecordedSegment
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var player = AVPlayer()
    @State private var showDeleteDialog = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VideoPlayer(player: player)
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)

                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        Label("Apagar take", systemImage: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Pré-visualização")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar", action: onClose)
                }
            }
            .confirmationDialog(
                "Apagar este take?",
                isPresented: $showDeleteDialog,
                titleVisibility: .visible
            ) {
                Button("Apagar", role: .destructive) {
                    player.pause()
                    onDelete()
                }
                Button("Cancelar", role: .cancel) { }
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            player.replaceCurrentItem(with: AVPlayerItem(url: segment.url))
            player.play()
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}

struct FilterMenu: View {
    let selected: CameraViewModel.VideoFilter
    let onSelect: (CameraViewModel.VideoFilter) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(CameraViewModel.VideoFilter.allCases, id: \.id) { f in
                    FilterRow(filter: f, selected: f == selected) { onSelect(f) }
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 12)
        .frame(maxWidth: 180)
        .frame(maxHeight: 120)
        .clipped()
    }
}

struct FilterRow: View {
    let filter: CameraViewModel.VideoFilter
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                FilterSwatch(filter: filter)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: selected ? 1.2 : 0.8))

                Text(filter.displayName)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(.white)

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.18 : 0.10))
            )
        }
        .buttonStyle(.plain)
    }
}

struct FilterSwatch: View {
    let filter: CameraViewModel.VideoFilter
    var body: some View {
        switch filter {
        case .none:
            LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .mono:
            LinearGradient(colors: [.white, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
