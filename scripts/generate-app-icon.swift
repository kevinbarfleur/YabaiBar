#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSpec {
    let logicalSize: Int
    let scale: Int

    var pixelSize: Int { logicalSize * scale }
    var fileName: String {
        if scale == 1 {
            return "icon_\(logicalSize)x\(logicalSize).png"
        }

        return "icon_\(logicalSize)x\(logicalSize)@2x.png"
    }
}

let specs = [
    IconSpec(logicalSize: 16, scale: 1),
    IconSpec(logicalSize: 16, scale: 2),
    IconSpec(logicalSize: 32, scale: 1),
    IconSpec(logicalSize: 32, scale: 2),
    IconSpec(logicalSize: 128, scale: 1),
    IconSpec(logicalSize: 128, scale: 2),
    IconSpec(logicalSize: 256, scale: 1),
    IconSpec(logicalSize: 256, scale: 2),
    IconSpec(logicalSize: 512, scale: 1),
    IconSpec(logicalSize: 512, scale: 2),
]

let fileManager = FileManager.default
let outputDirectory: URL

if CommandLine.arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
} else {
    outputDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
}

try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let image = renderIcon(pixelSize: spec.pixelSize)
    let destination = outputDirectory.appendingPathComponent(spec.fileName)
    try writePNG(image: image, to: destination)
}

func renderIcon(pixelSize: Int) -> NSImage {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: size)

    image.lockFocus()

    guard let context = NSGraphicsContext.current else {
        fatalError("Missing graphics context")
    }

    context.imageInterpolation = .high

    let bounds = NSRect(origin: .zero, size: size)
    let inset = CGFloat(pixelSize) * 0.035
    let backgroundRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = CGFloat(pixelSize) * 0.23

    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )

    NSColor(calibratedWhite: 0.07, alpha: 1.0).setFill()
    backgroundPath.fill()

    NSColor(calibratedWhite: 0.18, alpha: 1.0).setStroke()
    backgroundPath.lineWidth = max(1.0, CGFloat(pixelSize) * 0.012)
    backgroundPath.stroke()

    let symbol = configuredSymbol(for: pixelSize)
    let symbolSide = CGFloat(pixelSize) * 0.58
    let symbolRect = NSRect(
        x: (CGFloat(pixelSize) - symbolSide) / 2.0,
        y: (CGFloat(pixelSize) - symbolSide) / 2.0 + CGFloat(pixelSize) * 0.015,
        width: symbolSide,
        height: symbolSide
    )

    let shadow = NSShadow()
    shadow.shadowBlurRadius = CGFloat(pixelSize) * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(pixelSize) * 0.015)
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.28)
    shadow.set()

    symbol.draw(in: symbolRect)

    image.unlockFocus()
    return image
}

func configuredSymbol(for pixelSize: Int) -> NSImage {
    let baseImage = NSImage(
        systemSymbolName: "square.3.layers.3d.top.filled",
        accessibilityDescription: nil
    )!
    let sizeConfiguration = NSImage.SymbolConfiguration(
        pointSize: CGFloat(pixelSize) * 0.54,
        weight: .bold,
        scale: .large
    )
    let colorConfiguration = NSImage.SymbolConfiguration(
        paletteColors: [
            NSColor(calibratedWhite: 0.92, alpha: 1.0)
        ]
    )

    return baseImage.withSymbolConfiguration(sizeConfiguration.applying(colorConfiguration)) ?? baseImage
}

func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "YabaiBarIconGenerator", code: 1)
    }

    try pngData.write(to: url)
}
