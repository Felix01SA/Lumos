# 💡 Lumos — Controle de Backlight do Teclado para MacBook

O **Lumos** é um aplicativo nativo para macOS projetado para controlar a iluminação do teclado dos MacBooks com precisão cirúrgica, suporte a presets rápidos, temporizador inteligente de inatividade e interface moderna integrada à barra de menus (Menu Bar).

![Lumos App](Lumos/Assets.xcassets/AppIcon.appiconset/app_icon_512.png)

---

## ✨ Recursos

- **Ícone Dinâmico na Barra de Menus:**
  - Vive silenciosamente na barra de menus sem ocupar espaço no Dock (`LSUIElement`).
  - Ícone reflete o status em tempo real da iluminação (desligado, baixa, média, alta).
  - Opção para exibir a porcentagem exata diretamente no menu bar.

- **Painel de Controle Rápido (Popover):**
  - **Slider de Precisão:** Ajuste contínuo de 0% a 100% com resposta suave e iluminação visual imediata.
  - **Botão Power:** Liga e desliga a iluminação com 1 clique, memorizando o último nível ativo.
  - **Presets Rápidos:** Acesso com um clique a `0%` (Desligado), `25%`, `50%`, `75%` e `100%` (Máximo).

- **Economia de Bateria & Inatividade (Auto-Dim):**
  - Sensor de inatividade integrado usando `CGEventSource`.
  - Apaga ou diminui automaticamente o teclado se você parar de digitar (escolha entre 15s, 30s, 1m, 2m, 5m).
  - Restaura o brilho imediatamente assim que qualquer tecla ou trackpad for tocado.

- **Modo Respiração (Ambient Pulse):**
  - Efeito suave de pulsação sinusoidal contínua do backlight para apresentações ou ambiente escuro.

- **Compatibilidade:**
  - Comunicação de baixo nível via **IOKit (`IOHIDEventSystemClient`)** diretamente no driver `AppleHIDKeyboardEventDriver` com limites de hardware reais (`0..512`).
  - Integração com **`CoreBrightness`** para detecção de IDs e estado de brilho automático.
  - Compatível com MacBooks Intel (incluindo modelos com Touch Bar e chip T2) e Apple Silicon (M1/M2/M3/M4).

---

## 🚀 Como Executar

### 1. Pelo Finder
O aplicativo compilado e assinado está localizado em:
```bash
Lumos/build/Lumos.app
```
Basta dar dois cliques no `Lumos.app` no Finder para abrir na barra de menus!
(Opcional: arraste para a pasta `/Applications` para instalar no sistema).

### 2. Pelo Terminal
```bash
/Users/felix/Developer/Lumos/build/Lumos.app/Contents/MacOS/Lumos &
```

---

## 🛠️ Como Compilar

O projeto inclui um script que compila todos os fontes Swift, gera os metadados do pacote e assina o app:
```bash
./scripts/build_app.sh
```

Ou se preferir abrir no **Xcode**:
Basta abrir `Lumos.xcodeproj` no Xcode e pressionar **Cmd + R**.
