#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Lumos.app"
DMG_STAGING="$BUILD_DIR/dmg_staging"
OUTPUT_DMG="$BUILD_DIR/Lumos.dmg"

# 1. Certificar que o Lumos.app foi compilado
if [ ! -d "$APP_DIR" ]; then
    echo "==> Lumos.app não encontrado. Compilando o aplicativo primeiro..."
    bash "$SCRIPT_DIR/build_app.sh"
fi

echo "==> Preparando a estrutura do DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# 2. Copiar o Lumos.app para o diretório de staging
echo "==> Copiando Lumos.app..."
cp -R "$APP_DIR" "$DMG_STAGING/"

# 3. Criar o atalho simbólico para a pasta /Applications (arraste e solte)
echo "==> Criando atalho para /Applications..."
ln -s /Applications "$DMG_STAGING/Applications"

# 4. Remover DMG anterior se existir
rm -f "$OUTPUT_DMG"

# 5. Gerar a imagem de disco compactada (UDZO) via hdiutil nativo do macOS
echo "==> Gerando $OUTPUT_DMG via hdiutil..."
hdiutil create \
    -volname "Lumos" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

# 6. Limpar diretório temporário de staging
rm -rf "$DMG_STAGING"

echo ""
echo "🎉 DMG criado com sucesso em:"
echo "   $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
