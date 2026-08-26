#!/usr/bin/env swift
//
// Рисует иконку приложения: монограмма «Ҳ» на диагональном градиенте
// цвета бренда. Скрипт лежит в репозитории, чтобы иконку можно было
// перерисовать, а не хранить непонятно откуда взявшийся PNG.
//
// Запуск: swift Tools/make-app-icon.swift <путь-к-png>
//
import AppKit
import CoreGraphics
import Foundation

let side = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Не удалось создать контекст")
}

// Фон: градиент от индиго к фиолетовому — цвет бренда из дизайн-системы.
let colors = [
    CGColor(red: 0.36, green: 0.31, blue: 1.00, alpha: 1),
    CGColor(red: 0.22, green: 0.19, blue: 0.72, alpha: 1)
] as CFArray

guard let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors,
    locations: [0, 1]
) else {
    fatalError("Не удалось создать градиент")
}

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

// Монограмма. «Ҳ» — первая буква названия на таджикском.
let letter = "Ҳ"
let fontSize = CGFloat(side) * 0.52
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
    .foregroundColor: NSColor.white
]

let string = NSAttributedString(string: letter, attributes: attributes)
let textSize = string.size()

let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

string.draw(at: NSPoint(
    x: (CGFloat(side) - textSize.width) / 2,
    // Оптическое, а не геометрическое центрирование: у прописной буквы
    // нижние выносные элементы отсутствуют, и по центру она кажется низкой.
    y: (CGFloat(side) - textSize.height) / 2 + CGFloat(side) * 0.02
))

NSGraphicsContext.restoreGraphicsState()

guard let image = context.makeImage() else { fatalError("Не удалось получить изображение") }

let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Не удалось закодировать PNG")
}

try data.write(to: URL(fileURLWithPath: outputPath))
print("Иконка записана: \(outputPath) (\(side)×\(side))")
