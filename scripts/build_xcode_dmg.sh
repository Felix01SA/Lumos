#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_DIR="$DERIVED_DATA/Build/Products/Release/Lumos.app"
DMG_STAGING="$BUILD_DIR/dmg_staging"
OUTPUT_DMG="$BUILD_DIR/Lumos.dmg"

echo "==> 1. Compilando Lumos com xcodebuild (Release)..."
xcodebuild -project "$PROJECT_DIR/Lumos.xcodeproj" \
           -scheme Lumos \
           -configuration Release \
           -derivedDataPath "$DERIVED_DATA" \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=YES \
           build

if [ ! -d "$APP_DIR" ]; then
    echo "❌ Erro: Aplicativo não encontrado em $APP_DIR"
    exit 1
fi

echo "==> 2. Preparando estrutura do DMG..."
rm -rf "$DMG_STAGING" "$OUTPUT_DMG"
mkdir -p "$DMG_STAGING"

echo "==> Copiando Lumos.app..."
cp -R "$APP_DIR" "$DMG_STAGING/"

echo "==> Criando atalho para /Applications..."
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> 3. Gerando imagem de disco ($OUTPUT_DMG)..."
hdiutil create \
    -volname "Lumos" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

echo "==> 4. Limpando arquivos temporários..."
rm -rf "$DMG_STAGING"

echo ""
echo "🎉 DMG criado com sucesso!"
echo "📍 Localização: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
