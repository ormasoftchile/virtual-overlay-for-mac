import AppKit
import CoreGraphics
import Foundation

struct RGBA {
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
  let alpha: CGFloat

  init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
    self.red = red / 255
    self.green = green / 255
    self.blue = blue / 255
    self.alpha = alpha
  }

  var color: NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
  }

  var cgColor: CGColor {
    color.cgColor
  }
}

let canvas: CGFloat = 1024
let outputPath = CommandLine.arguments.dropFirst().first ?? "../../Resources/AppIcon.iconset"
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
let fileManager = FileManager.default

try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

for item in try fileManager.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: nil) {
  try fileManager.removeItem(at: item)
}

let iconFiles: [(name: String, pixels: Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

for file in iconFiles {
  let bitmap = try renderIcon(pixels: file.pixels)
  let destination = outputURL.appendingPathComponent(file.name)
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw IconGeneratorError.pngEncodingFailed(file.name)
  }
  try data.write(to: destination, options: .atomic)
  print("Wrote \(destination.path)")
}

enum IconGeneratorError: Error {
  case bitmapCreationFailed(Int)
  case graphicsContextUnavailable
  case pngEncodingFailed(String)
}

func renderIcon(pixels: Int) throws -> NSBitmapImageRep {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    throw IconGeneratorError.bitmapCreationFailed(pixels)
  }

  bitmap.size = NSSize(width: pixels, height: pixels)

  guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw IconGeneratorError.graphicsContextUnavailable
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphicsContext
  defer { NSGraphicsContext.restoreGraphicsState() }

  let context = graphicsContext.cgContext
  let scale = CGFloat(pixels) / canvas

  context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  context.interpolationQuality = .high
  context.scaleBy(x: scale, y: scale)

  drawShadow(in: context)
  drawBody(in: context)
  drawMark(in: context)

  return bitmap
}

func drawShadow(in context: CGContext) {
  let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
  let path = CGPath(roundedRect: rect, cornerWidth: 184, cornerHeight: 184, transform: nil)

  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: RGBA(0, 0, 0, 0.18).cgColor)
  context.setFillColor(RGBA(0, 0, 0, 0.01).cgColor)
  context.addPath(path)
  context.fillPath()
  context.restoreGState()
}

func drawBody(in context: CGContext) {
  let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
  let path = CGPath(roundedRect: rect, cornerWidth: 184, cornerHeight: 184, transform: nil)

  context.saveGState()
  context.addPath(path)
  context.setFillColor(RGBA(17, 20, 22).cgColor)
  context.fillPath()

  context.addPath(path)
  context.setStrokeColor(RGBA(255, 255, 255, 0.07).cgColor)
  context.setLineWidth(2)
  context.strokePath()
  context.restoreGState()
}

func drawMark(in context: CGContext) {
  context.saveGState()
  context.setStrokeColor(RGBA(244, 241, 234, 0.94).cgColor)
  context.setLineWidth(16)
  context.setLineCap(.square)
  context.setLineJoin(.miter)

  drawBracket(in: context, x: 284, top: 720, bottom: 304, returnLength: 44, direction: 1)
  drawBracket(in: context, x: 740, top: 720, bottom: 304, returnLength: 44, direction: -1)
  context.restoreGState()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center

  let font = NSFont.systemFont(ofSize: 500, weight: .ultraLight)
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: RGBA(244, 241, 234, 0.94).color,
    .paragraphStyle: paragraph,
  ]
  let string = NSAttributedString(string: "V", attributes: attributes)
  let textSize = string.size()
  let rect = CGRect(
    x: 512 - textSize.width / 2,
    y: 512 - textSize.height / 2 - 18,
    width: textSize.width,
    height: textSize.height
  )
  string.draw(in: rect)
}

func drawBracket(
  in context: CGContext,
  x: CGFloat,
  top: CGFloat,
  bottom: CGFloat,
  returnLength: CGFloat,
  direction: CGFloat
) {
  context.beginPath()
  context.move(to: CGPoint(x: x + returnLength * direction, y: top))
  context.addLine(to: CGPoint(x: x, y: top))
  context.addLine(to: CGPoint(x: x, y: bottom))
  context.addLine(to: CGPoint(x: x + returnLength * direction, y: bottom))
  context.strokePath()
}

