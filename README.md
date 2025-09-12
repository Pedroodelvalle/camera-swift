### Camera (SwiftUI + AVFoundation)

App de câmera em SwiftUI com gravação segmentada, zoom rápido, grade (rule of thirds), flash/torch, e filtro suave aplicado no preview e no vídeo exportado.

## Requisitos
- Xcode 16.4+
- iOS 18.5+ (Base Deployment Target configurado no projeto)
- Dispositivo físico recomendado para testar torch (flash) e câmera

## Permissões
O projeto já inclui as chaves no Info (gerado pelo Xcode) para:
- Câmera: NSCameraUsageDescription
- Microfone: NSMicrophoneUsageDescription
- Salvar na Fototeca: NSPhotoLibraryAddUsageDescription
- Acesso à Fototeca (leitura/seleção): NSPhotoLibraryUsageDescription

As gravações são salvas usando autorização “add-only” quando disponível (iOS 14+).

## Como executar
1) Abra `Camera.xcodeproj` no Xcode
2) Selecione um dispositivo (de preferência físico)
3) Run (Cmd+R)

## Controles e UI
- Topo Esquerda: botão de FPS (60/30 fps)
- Topo Centro: botão de flash/torch
  - Traseira: usa torch do dispositivo
  - Frontal: “screen torch” (aumenta o brilho da tela)
- Topo Direita: botão para alternar a grade (rule of thirds)
- Gestos no preview:
  - Toque simples: foco/exposição no ponto
  - Pinça: zoom contínuo (com ramp)
  - Toque duplo: alterna entre câmeras
- Área central inferior:
  - Seletores de zoom rápido: 0.5x / 1x / 2x
  - Botão de gravar: inicia/para a gravação segmentada
- Canto inferior esquerdo: botão de filtro
  - Ativado: overlay rosado no preview e export com filtro suave aplicado
- Canto inferior direito: alternar câmera (frontal/traseira)

## Filtro (preview + export)
- Preview: overlay de tom rosado leve para visualização
- Export: pós-processamento com Core Image (CIColorMonochrome em tom rosado) via AVVideoComposition; resultado salvo na Fototeca

## Técnica / Implementação
- SwiftUI para UI; `CameraPreviewView` (UIView) com `AVCaptureVideoPreviewLayer`
- `CaptureSessionController` gerencia:
  - Sessão AV (vídeo/áudio), formato e FPS
  - Zoom (ramp), foco/exposição, estabilização (cinematic), codec (HEVC quando disponível)
  - Torch (reaplicado ao trocar de câmera)
- `SegmentedRecorder` grava segmentos com `AVCaptureMovieFileOutput`
- `CameraViewModel` integra sessão, preview e UI:
  - Permissões, orientação, zoom rápido, torch, grid
  - Filtro: controla overlay e export com Core Image

## Observações
- Torch frontal é simulado com brilho máximo da tela; restaurado ao desativar/fechar
- Ao alternar a câmera, o torch desejado é reaplicado automaticamente quando suportado
- A grade não interfere na interação (ignora toques)

## Problemas comuns
- “Privacy-sensitive data without a usage description”: confirme que as chaves de uso estão presentes (ver seção Permissões)
- Torch não acende no simulador: use um dispositivo físico


