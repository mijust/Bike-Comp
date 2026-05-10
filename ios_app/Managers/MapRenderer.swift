import Foundation
import MapKit
import CoreGraphics
import CoreLocation

class MapRenderer {

    enum RendererError: Error {
        case snapshotFailed
        case ditheringFailed
    }

    /// Renders a map snapshot with user heading arrow and returns both the preview UIImage and the dithered 1-bit buffer.
    func renderMap(at location: CLLocation, heading: CLLocationDirection?, completion: @escaping (Result<(UIImage, [UInt8]), Error>) -> Void) {

        let width: CGFloat = 400
        let height: CGFloat = 240
        let size = CGSize(width: width, height: height)

        let options = MKMapSnapshotter.Options()
        // Standard span for local routing, customize as needed
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        options.region = MKCoordinateRegion(center: location.coordinate, span: span)
        options.size = size
        options.scale = 1.0 // Render at 1x scale for exact 400x240 pixels
        // Choose standard or muted, typically muted looks better when dithered
        options.mapType = .mutedStandard
        // For black and white, traits override to light mode provides better contrast
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshotter = MKMapSnapshotter(options: options)

        snapshotter.start { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let snapshot = snapshot else {
                completion(.failure(RendererError.snapshotFailed))
                return
            }

            // Draw the user location/heading marker
            let imageWithMarker = self.drawMarker(on: snapshot.image, heading: heading)

            // Dither the image to 1-bit
            guard let ditheredData = imageWithMarker.to1BitDithered(),
                  let previewImage = UIImage.from1BitDithered(ditheredData, width: Int(width), height: Int(height)) else {
                completion(.failure(RendererError.ditheringFailed))
                return
            }

            completion(.success((previewImage, ditheredData)))
        }
    }

    private func drawMarker(on mapImage: UIImage, heading: CLLocationDirection?) -> UIImage {
        let size = mapImage.size

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        let context = UIGraphicsGetCurrentContext()!

        // Draw the map image
        mapImage.draw(in: CGRect(origin: .zero, size: size))

        // Marker center point
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)

        // Rotate context according to heading
        if let heading = heading {
            // Convert to radians (heading 0 is North)
            let radians = heading * .pi / 180.0
            context.rotate(by: CGFloat(radians))
        }

        // Draw a bold, high-contrast directional arrow pointing "Up" in local rotated context
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 0, y: -15)) // Tip
        arrowPath.addLine(to: CGPoint(x: 10, y: 10)) // Bottom Right
        arrowPath.addLine(to: CGPoint(x: 0, y: 5))  // Inner cleft
        arrowPath.addLine(to: CGPoint(x: -10, y: 10)) // Bottom Left
        arrowPath.close()

        // Thick white stroke for contrast against dithered map
        UIColor.white.setStroke()
        arrowPath.lineWidth = 3.0
        arrowPath.lineJoinStyle = .round
        arrowPath.stroke()

        // Solid black fill
        UIColor.black.setFill()
        arrowPath.fill()

        context.restoreGState()

        let finalImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return finalImage
    }
}
