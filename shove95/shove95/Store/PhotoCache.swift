//
//  PhotoCache.swift
//  shove95
//
//  Decoded photos, held so a row can be redrawn without re-decoding them.
//
//  `UIImage(data:)` inside a view's body decodes the JPEG every time the body
//  runs — and a body runs often: a press, a swipe, a menu opening, a
//  neighbouring row changing. On a row carrying a photo that showed as a
//  flicker under long-press, because the image was being rebuilt mid-gesture
//  while the row was already animating (founder bug report 2026-08-17).
//
//  An NSCache rather than a dictionary: it empties itself under memory
//  pressure, which is the right behaviour for something that can always be
//  decoded again.
//

import UIKit

@MainActor
enum PhotoCache {
    private static let cache: NSCache<NSData, UIImage> = {
        let c = NSCache<NSData, UIImage>()
        // Counted AND weighed. A count alone said nothing about how much
        // memory this holds: entries are full decodes of 2048px-edge JPEGs,
        // about 12.6 MB of bitmap each, so 120 of them is roughly 1.5 GB —
        // held to draw thumbnails, and evicted only if the OS memory-pressure
        // notification beat jetsam to it (found in review 2026-08-26).
        c.countLimit = 120
        // 96 MB, which is a comfortable few screens of rows and still an
        // order of magnitude under where a photo-light app gets killed.
        c.totalCostLimit = 96 * 1024 * 1024
        return c
    }()

    /// Bytes a decoded image actually occupies, which is its PIXEL count — not
    /// the size of the JPEG it came from. A 2 MB JPEG is ~12 MB decoded, so
    /// costing by `data.count` would under-report by roughly six times and
    /// make the limit above meaningless.
    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else {
            return Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        }
        return cg.bytesPerRow * cg.height
    }

    static func image(_ data: Data) -> UIImage? {
        let key = data as NSData
        if let hit = cache.object(forKey: key) { return hit }
        guard let decoded = UIImage(data: data) else { return nil }
        cache.setObject(decoded, forKey: key, cost: cost(of: decoded))
        return decoded
    }
}
