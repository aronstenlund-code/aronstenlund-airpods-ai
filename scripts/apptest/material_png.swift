// T21 (Toby 2): a picture of a page of material, for the Simulator's photo library (`simctl addmedia`), so the
// first-start test can choose it under Välj bilder. Black text on white, A4 at 150 dpi. macOS only (AppKit).
//
//   xcrun swift scripts/apptest/material_png.swift out.png "Text …"
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: material_png.swift out.png text\n".utf8))
    exit(2)
}
let size = NSSize(width: 1240, height: 1754)
let image = NSImage(size: size)
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
let style = NSMutableParagraphStyle()
style.lineSpacing = 14
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 46),
    .foregroundColor: NSColor.black,
    .paragraphStyle: style,
]
(arguments[2] as NSString).draw(in: NSRect(x: 110, y: 110, width: 1020, height: 1500), withAttributes: attributes)
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: arguments[1]))
print("wrote \(arguments[1])")
