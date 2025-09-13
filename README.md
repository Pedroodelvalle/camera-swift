### Camera (SwiftUI + AVFoundation)

App de câmera em SwiftUI com:
- Gravação segmentada com miniaturas e concatenação (botão Avançar)
- Zoom rápido (0.5x / 1x / 2x) e pinça com ramp
- Grade (rule of thirds) opcional
- Flash/torch (traseira) e “screen torch” na frontal
- Teleprompter flutuante com edição, play/pause, velocidade e tamanho da fonte ajustáveis, arrastar/redimensionar
- Exportação em HEVC (quando disponível), estabilização cinematográfica e orientação preservada
- Filtros opcionais no export (Rose, Mono, Noir, Chrome) com pré-visualização indicativa (overlay leve)

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
3) Execute (Cmd+R)

## Controles e UI
- Topo: botões para fechar, alternar HD/4K (60/30 fps), grade, flash/torch e teleprompter
  - Traseira: usa torch do dispositivo
  - Frontal: “screen torch” (aumenta o brilho da tela)
- Gestos no preview:
  - Toque simples: foco/exposição no ponto
  - Pinça: zoom contínuo (com ramp)
  - Toque duplo: alterna entre câmeras
- Inferior (centro):
  - Seletores de zoom rápido: 0.5x / 1x / 2x
  - Botão de gravar: inicia/para a gravação segmentada (com timer no topo durante a gravação)
- Inferior (esquerda):
  - Botão de Filtros abre um seletor compacto (Nenhum, Rose, Mono, Noir, Chrome)
- Inferior (direita):
  - Alternar câmera (frontal/traseira)
  - Botão “Avançar” aparece quando há segmentos (concatena e salva)

## Filtros (preview + export)
- Preview: overlay leve para indicar o filtro escolhido (efeito ilustrativo)
- Export: pós-processamento com Core Image via AVVideoComposition (Mono/Noir/Chrome e Rose com CIColorMonochrome); resultado salvo na Fototeca
Nota: os filtros são opcionais (Nenhum por padrão). O preview não processa os frames ao vivo; o efeito final é aplicado no export.

## Teleprompter
- Ativação: botão no topo abre o overlay flutuante
- Edição: toque no texto para abrir o editor (folha) e ajustar o conteúdo
- Play/Pause: botão no canto superior direito do overlay
- Controles: sliders compactos para tamanho da fonte e velocidade (mostrados quando não está rolando)
- Interação: arraste pelo “handle” inferior esquerdo para mover; redimensione pelo “handle” inferior direito
- Rolagem automática: durante a gravação (ou em play), rola no ritmo definido; pausa opcional no final do texto

## Técnica / Implementação
- SwiftUI para UI; `CameraPreviewView` (UIView) com `AVCaptureVideoPreviewLayer`
- `CaptureSessionController`: sessão AV (vídeo/áudio), formato/FPS, zoom (ramp), foco/exposição, estabilização, codec (HEVC), torch e espelhamento na câmera frontal
- `SegmentedRecorder`: grava segmentos (`AVCaptureMovieFileOutput`) e entrega URLs temporários + miniaturas
- `CameraViewModel`: integra sessão, preview e UI (permissões, orientação, zoom rápido, torch, grid, teleprompter, concatenação/export)
- `TeleprompterOverlay` e `TeleprompterViewModel`: overlay flutuante com edição, rolagem automática, arrastar/redimensionar e controle de velocidade/tamanho da fonte
- `GlassCompat`: estilos “glass” leves para botões e cápsulas

## Observações
- Torch frontal é simulado com brilho máximo da tela; restaurado ao desativar/fechar
- Ao alternar a câmera, o torch desejado é reaplicado automaticamente quando suportado
- A grade não interfere na interação (ignora toques)
 - Codec preferencial HEVC (fallback para H.264 quando necessário)
 - Vídeos gravados mantêm orientação via `preferredTransform`

## Problemas comuns
- “Privacy-sensitive data without a usage description”: confirme que as chaves de uso estão presentes (ver seção Permissões)
- Torch não acende no simulador: use um dispositivo físico

## Opcional: Snap Camera Kit
O código possui integrações condicionais com `SCSDKCameraKit` (desativadas por padrão). Caso deseje usar efeitos AR do Snap:
- Adicione o SDK ao projeto (SPM/CocoaPods) e configure `snapApiToken`/`snapLensID` em `CameraViewModel`.
- Quando Snap AR estiver ativo, o filtro Core Image é desabilitado automaticamente no preview/export.

## Git
Um `.gitignore` padrão para Xcode/Swift foi adicionado. Para remover arquivos já versionados como `.DS_Store`:

```
git rm -r --cached .DS_Store
git commit -m "remove DS_Store"
```
