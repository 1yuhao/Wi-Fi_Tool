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
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let iconRect = bounds.insetBy(dx: size * 0.075, dy: size * 0.075)
    let cornerRadius = size * 0.22
    let background = NSBezierPath(
        roundedRect: iconRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    NSGraphicsContext.current?.saveGraphicsState()
    background.addClip()

    let gradient = NSGradient(colors: [
        NSColor(red: 0.10, green: 0.44, blue: 0.92, alpha: 1),
        NSColor(red: 0.10, green: 0.68, blue: 0.92, alpha: 1)
    ])
    gradient?.draw(in: iconRect, angle: -30)

    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(ovalIn: NSRect(
        x: size * 0.13,
        y: size * 0.57,
        width: size * 0.5,
        height: size * 0.28
    )).fill()

    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor.black.withAlphaComponent(0.10).setStroke()
    background.lineWidth = max(size * 0.012, 1)
    background.stroke()

    let center = NSPoint(x: size * 0.5, y: size * 0.35)
    let strokeColor = NSColor.white.withAlphaComponent(0.94)
    for (index, radius) in [0.16, 0.28, 0.40].enumerated() {
        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: size * radius,
            startAngle: 38,
            endAngle: 142,
            clockwise: false
        )
        path.lineWidth = max(size * (0.04 - CGFloat(index) * 0.004), 1.3)
        path.lineCapStyle = .round
        strokeColor.setStroke()
        path.stroke()
    }

    let dotRadius = size * 0.045
    let dotRect = NSRect(
        x: center.x - dotRadius,
        y: size * 0.24 - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    )
    strokeColor.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    return image
}

private func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }

    return bitmap.representation(using: .png, properties: [:])
}
