import AppKit

let size: CGFloat = 512
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. Draw rounded rectangle background (macOS icon style)
let rect = CGRect(x: 32, y: 32, width: 448, height: 448)
let path = CGPath(roundedRect: rect, cornerWidth: 100, cornerHeight: 100, transform: nil)

context.addPath(path)
context.clip()

// Background Gradient (deep obsidian navy to dark violet charcoal)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0).cgColor,
    NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
] as CFArray

if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(bgGradient, start: CGPoint(x: 256, y: 480), end: CGPoint(x: 256, y: 32), options: [])
}

// 2. Ambient backlight glow behind keyboard
let glowColors = [
    NSColor(red: 1.0, green: 0.72, blue: 0.25, alpha: 0.45).cgColor,
    NSColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 0.0).cgColor
] as CFArray

if let radialGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    context.drawRadialGradient(
        radialGradient,
        startCenter: CGPoint(x: 256, y: 240),
        startRadius: 10,
        endCenter: CGPoint(x: 256, y: 240),
        endRadius: 190,
        options: []
    )
}

// 3. Draw Keyboard Base
let kbRect = CGRect(x: 96, y: 140, width: 320, height: 180)
let kbPath = CGPath(roundedRect: kbRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
context.addPath(kbPath)
context.setFillColor(NSColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 0.9).cgColor)
context.setStrokeColor(NSColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 0.6).cgColor)
context.setLineWidth(2.5)
context.drawPath(using: .fillStroke)

// 4. Draw Glowing Keys Grid
let rows = 4
let cols = 7
let keyW: CGFloat = 34
let keyH: CGFloat = 24
let gapX: CGFloat = 9
let gapY: CGFloat = 11
let startX: CGFloat = 114
let startY: CGFloat = 270

for r in 0..<rows {
    for c in 0..<cols {
        let kx = startX + CGFloat(c) * (keyW + gapX)
        let ky = startY - CGFloat(r) * (keyH + gapY)
        
        let keyRect = CGRect(x: kx, y: ky, width: keyW, height: keyH)
        let keyPath = CGPath(roundedRect: keyRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        
        context.addPath(keyPath)
        context.setFillColor(NSColor(red: 0.20, green: 0.23, blue: 0.32, alpha: 0.95).cgColor)
        context.fillPath()
        
        // Key rim backlight glow
        context.addPath(keyPath)
        context.setStrokeColor(NSColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 0.85).cgColor)
        context.setLineWidth(1.2)
        context.strokePath()
    }
}

// 5. Spacebar glowing key
let spaceRect = CGRect(x: 185, y: 152, width: 142, height: 20)
let spacePath = CGPath(roundedRect: spaceRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
context.addPath(spacePath)
context.setFillColor(NSColor(red: 0.22, green: 0.26, blue: 0.36, alpha: 0.95).cgColor)
context.fillPath()
context.addPath(spacePath)
context.setStrokeColor(NSColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 0.95).cgColor)
context.setLineWidth(1.5)
context.strokePath()

// 6. Upward Light Beams / Shimmer
for i in -3...3 {
    let beamX = 256.0 + Double(i) * 35.0
    let beamPath = CGMutablePath()
    beamPath.move(to: CGPoint(x: beamX, y: 320))
    beamPath.addLine(to: CGPoint(x: beamX + Double(i) * 15.0, y: 440))
    
    context.addPath(beamPath)
    context.setStrokeColor(NSColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 0.35 - abs(Double(i)) * 0.07).cgColor)
    context.setLineWidth(CGFloat(3.0 - abs(Double(i)) * 0.5))
    context.strokePath()
}

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try pngData.write(to: URL(fileURLWithPath: outPath))
print("Icon written to \(outPath)")
