import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-icon.swift <output.png>\n", stderr)
    exit(2)
}

let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)
image.lockFocus()

NSGraphicsContext.current?.imageInterpolation = .high

let background = NSBezierPath(
    roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920),
    xRadius: 215,
    yRadius: 215
)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.92, alpha: 1),
    NSColor(calibratedRed: 0.46, green: 0.22, blue: 0.88, alpha: 1)
])!
gradient.draw(in: background, angle: -45)

NSColor.white.withAlphaComponent(0.96).setFill()
let folderBody = NSBezierPath(
    roundedRect: NSRect(x: 185, y: 235, width: 654, height: 490),
    xRadius: 72,
    yRadius: 72
)
folderBody.fill()

let folderTab = NSBezierPath()
folderTab.move(to: NSPoint(x: 225, y: 680))
folderTab.line(to: NSPoint(x: 225, y: 780))
folderTab.curve(
    to: NSPoint(x: 305, y: 835),
    controlPoint1: NSPoint(x: 225, y: 812),
    controlPoint2: NSPoint(x: 260, y: 835)
)
folderTab.line(to: NSPoint(x: 455, y: 835))
folderTab.curve(
    to: NSPoint(x: 535, y: 755),
    controlPoint1: NSPoint(x: 500, y: 835),
    controlPoint2: NSPoint(x: 515, y: 790)
)
folderTab.line(to: NSPoint(x: 558, y: 680))
folderTab.close()
folderTab.fill()

let ink = NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.50, alpha: 1)
ink.setStroke()

for y in [580.0, 495.0, 410.0] {
    let line = NSBezierPath()
    line.lineWidth = 24
    line.lineCapStyle = .round
    line.move(to: NSPoint(x: 285, y: y))
    line.line(to: NSPoint(x: 545, y: y))
    line.stroke()
}

let lens = NSBezierPath(ovalIn: NSRect(x: 515, y: 310, width: 260, height: 260))
lens.lineWidth = 34
lens.stroke()

let handle = NSBezierPath()
handle.lineWidth = 46
handle.lineCapStyle = .round
handle.move(to: NSPoint(x: 712, y: 355))
handle.line(to: NSPoint(x: 825, y: 235))
handle.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("unable to encode icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
