//
//  ContentView.swift
//  Camera
//
//  Created by Pedro Deboni Del Valle on 12/09/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var model = CameraViewModel()

    var body: some View {
        ZStack {
            CameraPreviewRepresentable(model: model)
                .ignoresSafeArea()

            // Grid overlay (rule of thirds) - appears over preview, ignores interactions
            if model.showGrid {
                GridOverlay()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            // Rose tint overlay for preview when filter is on
            if model.isFilterOn {
                Color(red: 1.0, green: 0.6, blue: 0.75)
                    .opacity(0.12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack {
                ZStack {
                    HStack {
                        Button(model.frameRateLabel) { model.toggleFrameRate() }
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                        // Top-right grid toggle
                        Button(action: { model.toggleGrid() }) {
                            Image(systemName: model.showGrid ? "rectangle.split.3x3" : "rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Alternar grade")
                    }

                    Button(action: { model.toggleTorch() }) {
                        Image(systemName: model.isTorchOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(model.isTorchOn ? .yellow : .white)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Alternar flash")
                }
                .padding()

                Spacer()

                // Botões de zoom acima do botão de gravar, ambos centralizados
                VStack(spacing: 16) {
                    // Quick zoom selector - centralizado
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { idx in
                            let label: String = (idx == 0 ? "0.5" : (idx == 1 ? "1" : "2"))
                            Text(label + "x")
                                .fontWeight(model.quickZoomIndex == idx ? .bold : .regular)
                                .foregroundStyle(model.quickZoomIndex == idx ? Color.yellow : Color.white)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                                .onTapGesture { model.selectQuickZoom(index: idx) }
                        }
                    }

                    // Botão de gravar - centralizado
                    Button(action: { model.toggleRecording() }) {
                        Circle()
                            .fill(model.isRecording ? Color.red : Color.white)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                    }
                }
                .padding(.bottom, 24)
            }

            // Bottom-left filter toggle
            VStack {
                Spacer()
                HStack {
                    Button(action: { model.toggleFilter() }) {
                        Image(systemName: model.isFilterOn ? "paintbrush.fill" : "paintbrush")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(model.isFilterOn ? Color.pink : Color.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 28)
                    .accessibilityLabel("Alternar filtro")
                    Spacer()
                }
            }

            // Bottom-right camera toggle button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { model.toggleCameraPosition() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                    .accessibilityLabel("Trocar câmera")
                }
            }
        }
        .onAppear { model.requestPermissionsAndConfigure() }
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
