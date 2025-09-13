//
//  ContentView.swift
//  Camera
//
//  Created by Pedro Deboni Del Valle on 12/09/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CameraViewModel()
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?
    @State private var showDeleteConfirm: Bool = false
    @State private var segmentToDelete: CameraViewModel.RecordedSegment? = nil

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

                        // Rose tint overlay for preview when filter is on
                        if model.isFilterOn {
                            Color(red: 1.0, green: 0.6, blue: 0.75)
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
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Fechar câmera")

                        Spacer()

                        // Frame rate button
                        Button(action: { model.toggleFrameRate() }) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Alternar taxa de quadros")

                        // Grid toggle
                        Button(action: { model.toggleGrid() }) {
                            Image(systemName: model.showGrid ? "rectangle.split.3x3" : "rectangle.grid.1x2")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Alternar grade")

                        // Torch toggle
                        Button(action: { model.toggleTorch() }) {
                            Image(systemName: model.isTorchOn ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(model.isTorchOn ? .yellow : .white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Alternar flash")
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

                Spacer()

                // Botões de zoom acima do botão de gravar, ambos centralizados
                VStack(spacing: 16) {
                    // Quick zoom selector - centralizado
                    HStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { idx in
                            let label: String = (idx == 0 ? "0.5" : (idx == 1 ? "1" : "2"))
                            Text(label + "x")
                                .font(.system(size: 14, weight: model.quickZoomIndex == idx ? .semibold : .medium))
                                .foregroundStyle(model.quickZoomIndex == idx ? Color.yellow : Color.white.opacity(0.9))
                                .frame(width: 44, height: 44)
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

                    // Botão de gravar - centralizado (sempre visível para parar/iniciar)
                    Button(action: { model.toggleRecording() }) {
                        ZStack {
                            // Borda branca sempre presente
                            Circle()
                                .fill(Color.white.opacity(0.1)) // Fundo semi-transparente
                                .frame(width: 80, height: 80)
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))

                            // Círculo vermelho que diminui e fica mais quadrado arredondado quando grava
                            RoundedRectangle(cornerRadius: model.isRecording ? 12 : 38)
                                .fill(Color.red)
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
                                    Image(uiImage: seg.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 34, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                                        )

                                    Button(action: {
                                        segmentToDelete = seg
                                        showDeleteConfirm = true
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 14, height: 14)
                                            .background(Color.black.opacity(0.75))
                                            .clipShape(Circle())
                                    }
                                    .padding(2)
                                }
                                .frame(width: 34, height: 44)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 52)
                    .padding(.bottom, 6)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                            .background(.ultraThinMaterial, in: Circle())
                    }
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
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color(red: 0x29/255.0, green: 0x84/255.0, blue: 0xf6/255.0), in: Circle())
                        }
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
                startCountdown()
            } else {
                stopCountdown()
            }
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
