# Changelog

## [1.0.0] - 2025-09-16
### Destaques da release
- **Teleprompter redesenhado** com visual em vidro, gradientes sutis, barra inferior compacta de controles e botões de play/pause, mover e redimensionar dedicados para um fluxo de uso mais limpo.
- **Melhorias de performance no teleprompter**, evitando recomputações de layout e medições desnecessárias ao armazenar estado do `UITextView`, agendar medições somente quando preciso e manter o offset sincronizado durante a rolagem automática.
- **Correções de performance e estabilidade** ao garantir que a câmera/teleprompter reiniciem do topo após edições, ajustes de fonte ou redimensionamento, gerenciando interações manuais sem travar a rolagem e pausando corretamente ao chegar ao fim.
- **Atualizações de projeto e permissões** com novos identificadores de bundle `com.pedro.*`, time de desenvolvimento configurado e limpeza dos entitlements da câmera.

> Esta é a versão publicada como "Release: Melhorias de performance e design do teleprompter".
