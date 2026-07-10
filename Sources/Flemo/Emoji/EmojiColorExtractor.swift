import AppKit
import Foundation
import simd
import SwiftUI

final class EmojiColorExtractor {
    static let shared = EmojiColorExtractor()
    private var cache: [String: [SwiftUI.Color]] = [:]
    private let lock = NSLock()

    func colors(for character: String) -> [SwiftUI.Color] {
        lock.lock()
        if let cached = cache[character] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let extracted = extract(from: character)

        lock.lock()
        cache[character] = extracted
        lock.unlock()
        return extracted
    }

    private func extract(from character: String) -> [SwiftUI.Color] {
        guard let pixels = renderPixels(character), !pixels.isEmpty else {
            return fallback
        }
        let clusters = kMeans(pixels, k: 2, iterations: 6)
        if clusters.count >= 2 {
            return [clusters[0], clusters[1]]
        }
        if clusters.count == 1 {
            return [clusters[0], clusters[0].opacity(0.6)]
        }
        return fallback
    }

    private func renderPixels(_ char: String) -> [NSColor]? {
        let w = 40, h = 40
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: w * 4,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext

        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))

        let font = NSFont.systemFont(ofSize: 32)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let str = NSAttributedString(string: char, attributes: attrs)
        let size = str.size()
        let drawRect = CGRect(
            x: (CGFloat(w) - size.width) / 2,
            y: (CGFloat(h) - size.height) / 2 - 2,
            width: size.width,
            height: size.height
        )
        str.draw(in: drawRect)
        NSGraphicsContext.restoreGraphicsState()

        guard let ptr = rep.bitmapData else { return nil }
        var colors: [NSColor] = []
        let step = 2
        for y in stride(from: 0, to: h, by: step) {
            for x in stride(from: 0, to: w, by: step) {
                let offset = (y * w + x) * 4
                let a = ptr[offset + 3]
                guard a > 25 else { continue }
                let r = CGFloat(ptr[offset]) / 255
                let g = CGFloat(ptr[offset + 1]) / 255
                let b = CGFloat(ptr[offset + 2]) / 255
                let brightness = (r + g + b) / 3
                guard brightness > 0.04, brightness < 0.96 else { continue }
                colors.append(NSColor(red: r, green: g, blue: b, alpha: 1))
            }
        }
        return colors
    }

    private func kMeans(_ points: [NSColor], k: Int, iterations: Int) -> [SwiftUI.Color] {
        guard points.count >= k else { return points.map { color(from: $0) } }

        var centroids: [SIMD3<Float>] = (0..<k).map { _ in
            let p = points[Int.random(in: 0..<points.count)]
            return SIMD3(Float(p.redComponent), Float(p.greenComponent), Float(p.blueComponent))
        }

        let vecs = points.map { SIMD3(Float($0.redComponent), Float($0.greenComponent), Float($0.blueComponent)) }

        for _ in 0..<iterations {
            var sums: [SIMD3<Float>] = Array(repeating: .zero, count: k)
            var counts: [Int] = Array(repeating: 0, count: k)

            for v in vecs {
                var best = 0
                var bestDist = Float.infinity
                for (i, c) in centroids.enumerated() {
                    let d = distance_squared(v, c)
                    if d < bestDist { bestDist = d; best = i }
                }
                sums[best] += v
                counts[best] += 1
            }

            for i in 0..<k {
                if counts[i] > 0 {
                    centroids[i] = sums[i] / Float(counts[i])
                }
            }
        }

        return centroids
            .filter { $0.x > 0 || $0.y > 0 || $0.z > 0 }
            .sorted { $0.x + $0.y + $0.z > $1.x + $1.y + $1.z }
            .map { color(from: $0) }
    }

    private func color(from vec: SIMD3<Float>) -> SwiftUI.Color {
        SwiftUI.Color(
            red: Double(clamp(vec.x)),
            green: Double(clamp(vec.y)),
            blue: Double(clamp(vec.z))
        )
    }

    private func color(from ns: NSColor) -> SwiftUI.Color {
        SwiftUI.Color(
            red: Double(ns.redComponent),
            green: Double(ns.greenComponent),
            blue: Double(ns.blueComponent)
        )
    }

    private func clamp(_ v: Float) -> Float {
        min(max(v, 0), 1)
    }

    private var fallback: [SwiftUI.Color] {
        [
            SwiftUI.Color(red: 0.30, green: 0.30, blue: 0.36),
            SwiftUI.Color(red: 0.18, green: 0.18, blue: 0.23)
        ]
    }
}
