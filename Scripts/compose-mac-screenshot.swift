// Places a window screenshot on a 2880 × 1800 canvas (a Mac App Store screenshot size), centred on
// the app's accent gradient, with the window's own shadow.
//
//   swift Scripts/compose-mac-screenshot.swift input.png output.png
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3, let window = NSImage(contentsOfFile: arguments[1]),
      let windowImage = window.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("usage: compose-mac-screenshot input.png output.png\n".utf8))
    exit(1)
}

let size = CGSize(width: 2880, height: 1800)
guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.displayP3)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

// Background: the icon's indigo gradient.
let colors = [CGColor(red: 0.388, green: 0.353, blue: 0.965, alpha: 1), CGColor(red: 0.176, green: 0.141, blue: 0.588, alpha: 1)]
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3), colors: colors as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])

// The window, scaled to at most 88 % of the canvas height, centred, with a soft shadow.
let scale = min(1, size.height * 0.88 / CGFloat(windowImage.height), size.width * 0.9 / CGFloat(windowImage.width))
let drawn = CGSize(width: CGFloat(windowImage.width) * scale, height: CGFloat(windowImage.height) * scale)
let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
context.setShadow(offset: CGSize(width: 0, height: -24), blur: 80, color: CGColor(gray: 0, alpha: 0.45))
context.interpolationQuality = .high
context.draw(windowImage, in: CGRect(origin: origin, size: drawn))

guard let output = context.makeImage(),
      let data = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: arguments[2]))
