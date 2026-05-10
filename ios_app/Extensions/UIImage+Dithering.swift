import UIKit
import CoreGraphics

extension UIImage {
    /// Converts the image to a 1-bit black/white array of bytes (MSB first) using Floyd-Steinberg dithering.
    /// Expected input size is 400x240, but dynamically uses the image's size.
    func to1BitDithered() -> [UInt8]? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to Float array for error diffusion
        var floatPixels = pixelData.map { Float($0) }

        // Floyd-Steinberg dithering
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = floatPixels[index]

                // Threshold is 128 (0 is black, 255 is white)
                let newPixel: Float = oldPixel < 128.0 ? 0.0 : 255.0
                floatPixels[index] = newPixel

                let quantError = oldPixel - newPixel

                if x + 1 < width {
                    floatPixels[y * width + (x + 1)] += quantError * 7.0 / 16.0
                }
                if y + 1 < height {
                    if x - 1 >= 0 {
                        floatPixels[(y + 1) * width + (x - 1)] += quantError * 3.0 / 16.0
                    }
                    floatPixels[(y + 1) * width + x] += quantError * 5.0 / 16.0
                    if x + 1 < width {
                        floatPixels[(y + 1) * width + (x + 1)] += quantError * 1.0 / 16.0
                    }
                }
            }
        }

        // Pack into 1-bit MSB-first bytes
        let rowBytes = (width + 7) / 8
        var packedData = [UInt8](repeating: 0, count: rowBytes * height)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixelValue = floatPixels[index]

                // For display purposes: 1 for white, 0 for black.
                // Assuming standard drawing where MSB is the left-most pixel.
                let isWhite = pixelValue > 127.0

                if isWhite {
                    let byteIndex = y * rowBytes + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    packedData[byteIndex] |= (1 << bitIndex)
                }
            }
        }

        return packedData
    }

    /// Generates a UIImage from a 1-bit black/white array of bytes (MSB first).
    /// Assumes 400x240 by default.
    static func from1BitDithered(_ data: [UInt8], width: Int = 400, height: Int = 240) -> UIImage? {
        let rowBytes = (width + 7) / 8
        guard data.count >= rowBytes * height else { return nil }

        var pixelData = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * rowBytes + (x / 8)
                let bitIndex = 7 - (x % 8)
                let bit = (data[byteIndex] >> bitIndex) & 1

                pixelData[y * width + x] = bit == 1 ? 255 : 0
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cgImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
