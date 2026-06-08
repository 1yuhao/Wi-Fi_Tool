#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.dropFirst().first.map(URL.init(fileURLWithPath:))
guard let outputDirectory else {
    FileHandle.standardError.write(Data("Usage: generate_app_icon.swift <iconset-directory>\n".utf8))
    exit(64)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconFiles: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    let image = drawIcon(size: iconFile.size)
    guard let data = pngData(from: image) else {
        FileHandle.standardError.write(Data("Unable to encode \(iconFile.name)\n".utf8))
        exit(1)
    }

    try data.write(to: outputDirectory.appendingPathComponent(iconFile.name))
}

private func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer {
        image.unlockFocus()
    }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let cornerRadius = size * 0.2
    let backgroundRect = bounds.insetBy(dx: size * 0.055, dy: size * 0.055)
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)

    NSGraphicsContext.current?.saveGraphicsState()
    backgroundPath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(red: 0.04, green: 0.34, blue: 0.92, alpha: 1),
        NSColor(red: 0.08, green: 0.64, blue: 0.92, alpha: 1),
        NSColor(red: 0.10, green: 0.82, blue: 0.62, alpha: 1)
    ])
    gradient?.draw(in: backgroundRect, angle: -35)

    NSColor.white.withAlphaComponent(0.16).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.1, y: size * 0.56, width: size * 0.58, height: size * 0.36)).fill()

    NSColor.black.withAlphaComponent(0.12).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.44, y: size * -0.08, width: size * 0.52, height: size * 0.34)).fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor.black.withAlphaComponent(0.14).setStroke()
    backgroundPath.lineWidth = max(size * 0.012, 1)
    backgroundPath.stroke()

    let wifiColor = NSColor.white.withAlphaComponent(0.94)
    let center = NSPoint(x: size * 0.5, y: size * 0.38)
    for (index, radius) in [0.14, 0.25, 0.36].enumerated() {
        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: size * radius,
            startAngle: 38,
            endAngle: 142,
            clockwise: false
        )
        path.lineWidth = max(size * (0.035 - CGFloat(index) * 0.003), 1.2)
        path.lineCapStyle = .round
        wifiColor.setStroke()
        path.stroke()
    }

    let dotRect = NSRect(x: size * 0.455, y: size * 0.265, width: size * 0.09, height: size * 0.09)
    wifiColor.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    drawNode(at: NSPoint(x: size * 0.31, y: size * 0.22), size: size)
    drawNode(at: NSPoint(x: size * 0.50, y: size * 0.16), size: size)
    drawNode(at: NSPoint(x: size * 0.69, y: size * 0.22), size: size)
    drawConnection(from: NSPoint(x: size * 0.31, y: size * 0.22), to: NSPoint(x: size * 0.50, y: size * 0.16), size: size)
    drawConnection(from: NSPoint(x: size * 0.50, y: size * 0.16), to: NSPoint(x: size * 0.69, y: size * 0.22), size: size)

    return image
}

private func drawConnection(from start: NSPoint, to end: NSPoint, size: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = max(size * 0.015, 0.8)
    path.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.52).setStroke()
    path.stroke()
}

private func drawNode(at center: NSPoint, size: CGFloat) {
    let radius = size * 0.035
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    NSColor.white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: rect).fill()
}

private func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }

    return bitmap.representation(using: .png, properties: [:])
}
