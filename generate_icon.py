#!/usr/bin/env python3
"""Generate MemoryKeeper app icon with warm nostalgic theme."""

import subprocess
import os

# Check if we have the tools we need
def generate_icons():
    base_path = "/Users/archuser/Downloads/ndi/nodaysidle-memorykeeper/MemoryKeeper/Assets.xcassets/AppIcon.appiconset"

    # Icon sizes needed for macOS
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    # Create base 1024x1024 icon using sips (macOS built-in) and Core Graphics
    # We'll use a Swift script to generate the icon
    swift_script = '''
import Cocoa
import CoreGraphics

func createIcon(size: Int, path: String) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    // Warm cream background
    let warmCream = CGColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1.0)
    context.setFillColor(warmCream)

    // Rounded rectangle background
    let cornerRadius = CGFloat(size) * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(bgPath)
    context.fillPath()

    // Add subtle gradient overlay
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.88, green: 0.75, blue: 0.45, alpha: 0.15),
            CGColor(red: 0.85, green: 0.65, blue: 0.45, alpha: 0.1)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])
    context.restoreGState()

    // Draw stacked polaroid photos
    let photoSize = CGFloat(size) * 0.35
    let center = CGFloat(size) / 2

    // Back photo (rotated left)
    context.saveGState()
    context.translateBy(x: center, y: center)
    context.rotate(by: -0.15)
    drawPolaroid(context: context, size: photoSize, offset: CGPoint(x: -photoSize/2 - 5, y: -photoSize/2 + 5), accentColor: CGColor(red: 0.85, green: 0.65, blue: 0.45, alpha: 1.0))
    context.restoreGState()

    // Front photo (rotated right)
    context.saveGState()
    context.translateBy(x: center, y: center)
    context.rotate(by: 0.1)
    drawPolaroid(context: context, size: photoSize, offset: CGPoint(x: -photoSize/2 + 5, y: -photoSize/2 - 5), accentColor: CGColor(red: 0.88, green: 0.75, blue: 0.45, alpha: 1.0))
    context.restoreGState()

    // Draw sparkle
    let sparkleSize = CGFloat(size) * 0.12
    drawSparkle(context: context, center: CGPoint(x: center + photoSize * 0.5, y: center - photoSize * 0.4), size: sparkleSize)

    // Save to file
    guard let image = context.makeImage() else { return }
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)

    print("Created: \\(path)")
}

func drawPolaroid(context: CGContext, size: CGFloat, offset: CGPoint, accentColor: CGColor) {
    let frameWidth = size
    let frameHeight = size * 1.15
    let photoMargin = size * 0.08
    let bottomMargin = size * 0.2

    // White frame with shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 2, height: -2), blur: 8, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.2))
    context.setFillColor(CGColor.white)
    let frameRect = CGRect(x: offset.x, y: offset.y - (frameHeight - size) / 2, width: frameWidth, height: frameHeight)
    let framePath = CGPath(roundedRect: frameRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
    context.addPath(framePath)
    context.fillPath()
    context.restoreGState()

    // Photo area with warm color
    let photoRect = CGRect(
        x: offset.x + photoMargin,
        y: offset.y + bottomMargin - photoMargin,
        width: frameWidth - photoMargin * 2,
        height: size - photoMargin
    )
    context.setFillColor(accentColor)
    context.addPath(CGPath(rect: photoRect, transform: nil))
    context.fillPath()

    // Small heart or sun icon in photo
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    let iconSize = size * 0.2
    let iconRect = CGRect(
        x: photoRect.midX - iconSize/2,
        y: photoRect.midY - iconSize/2,
        width: iconSize,
        height: iconSize
    )
    context.fillEllipse(in: iconRect)
}

func drawSparkle(context: CGContext, center: CGPoint, size: CGFloat) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)

    // Gold gradient sparkle
    let sparkleColor = CGColor(red: 0.88, green: 0.75, blue: 0.45, alpha: 1.0)
    context.setFillColor(sparkleColor)

    // Four-pointed star
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: -size/2))
    path.addLine(to: CGPoint(x: size * 0.15, y: -size * 0.15))
    path.addLine(to: CGPoint(x: size/2, y: 0))
    path.addLine(to: CGPoint(x: size * 0.15, y: size * 0.15))
    path.addLine(to: CGPoint(x: 0, y: size/2))
    path.addLine(to: CGPoint(x: -size * 0.15, y: size * 0.15))
    path.addLine(to: CGPoint(x: -size/2, y: 0))
    path.addLine(to: CGPoint(x: -size * 0.15, y: -size * 0.15))
    path.closeSubpath()

    context.addPath(path)
    context.fillPath()

    context.restoreGState()
}

// Generate all sizes
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let basePath = "/Users/archuser/Downloads/ndi/nodaysidle-memorykeeper/MemoryKeeper/Assets.xcassets/AppIcon.appiconset"

for (size, filename) in sizes {
    let path = "\\(basePath)/\\(filename)"
    createIcon(size: size, path: path)
}

print("All icons generated successfully!")
'''

    # Write and run Swift script
    script_path = "/tmp/generate_icon.swift"
    with open(script_path, "w") as f:
        f.write(swift_script)

    os.system(f"swift {script_path}")

if __name__ == "__main__":
    generate_icons()
