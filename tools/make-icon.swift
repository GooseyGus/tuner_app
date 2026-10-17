// Draws the app icon (light, dark and tinted) into the asset catalog.
// Run from the project folder: swift tools/make-icon.swift tuner/Assets.xcassets/AppIcon.appiconset

import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// Draws `text` centred in `rect`, sized so its capital height fills `capHeight`.
func glyph(_ text: String, in rect: CGRect, capHeight: CGFloat, color c: NSColor) {
    let probe = NSFont.systemFont(ofSize: 100, weight: .black)
    let font = NSFont.systemFont(ofSize: 100 * capHeight / probe.capHeight, weight: .black)
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: c])
    let line = CTLineCreateWithAttributedString(string)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.textPosition = CGPoint(x: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
    CTLineDraw(line, ctx)
}

func render(_ name: String, background: UInt32, tileA: UInt32, glyphA: UInt32, tile4: UInt32, glyph4: UInt32) {
    let size = 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    color(background).setFill()
    CGRect(x: 0, y: 0, width: size, height: size).fill()

    // Same tile height and baseline as the metronome's 4/4 (y is from the bottom here).
    let a = CGRect(x: 70, y: 168, width: 560, height: 688)
    let four = CGRect(x: 664, y: 168, width: 290, height: 380)
    color(tileA).setFill()
    NSBezierPath(roundedRect: a, xRadius: 90, yRadius: 90).fill()
    color(tile4).setFill()
    NSBezierPath(roundedRect: four, xRadius: 80, yRadius: 80).fill()
    glyph("A", in: a, capHeight: 400, color: color(glyphA))
    glyph("4", in: four, capHeight: 190, color: color(glyph4))

    NSGraphicsContext.restoreGraphicsState()
    // Icons must be opaque.
    let cg = rep.cgImage!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
    let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/" + name))
}

render("AppIcon.png", background: 0x0A2947, tileA: 0x8B5E3C, glyphA: 0xF3E4C9, tile4: 0xD3D4C0, glyph4: 0x0A2947)
render("AppIcon-Dark.png", background: 0x061A2E, tileA: 0x8B5E3C, glyphA: 0xF3E4C9, tile4: 0xD3D4C0, glyph4: 0x061A2E)
render("AppIcon-Tinted.png", background: 0x000000, tileA: 0x5C5C5C, glyphA: 0xFFFFFF, tile4: 0xD0D0D0, glyph4: 0x000000)
