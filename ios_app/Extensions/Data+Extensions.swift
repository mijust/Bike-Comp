import Foundation

extension Data {
    /// Creates Data from an integer using little endian encoding.
    init<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        self.init(bytes: &littleEndianValue, count: MemoryLayout<T>.size)
    }

    /// Appends an integer using little endian encoding.
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        self.append(withUnsafeBytes(of: &littleEndianValue) { Data($0) })
    }
}
