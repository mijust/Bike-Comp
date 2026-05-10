import Foundation
import CoreBluetooth

enum BLEConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
}

class BLEManager: NSObject, ObservableObject {
    @Published var connectionState: BLEConnectionState = .disconnected

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?

    // Nordic UART Service UUIDs
    let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let rxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // App writes to RX

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        connectionState = .scanning
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    func disconnect() {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - Data Transmission

    /// Sends Heart Rate TLV: Type 'H', Length 1, Data: [HR]
    func sendHeartRate(_ hr: UInt8) {
        guard let peripheral = targetPeripheral, let tx = txCharacteristic else { return }

        var data = Data()
        data.append(Character("H").asciiValue!)
        let length: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
        data.append(hr)

        peripheral.writeValue(data, for: tx, type: .withoutResponse)
    }

    /// Sends Map Data TLV asynchronously: Type 'M', Length, then chunks of data
    func sendMapData(_ mapBytes: [UInt8]) {
        guard let peripheral = targetPeripheral, let tx = txCharacteristic else { return }

        Task {
            // Send Header: 'M', Length
            var header = Data()
            header.append(Character("M").asciiValue!)
            let length = UInt16(mapBytes.count)
            header.append(contentsOf: withUnsafeBytes(of: length.littleEndian) { Array($0) })
            peripheral.writeValue(header, for: tx, type: .withoutResponse)

            // Allow a tiny delay after header just in case
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // Send Chunks
            let chunkSize = 200
            for i in stride(from: 0, to: mapBytes.count, by: chunkSize) {
                let end = min(i + chunkSize, mapBytes.count)
                let chunk = Data(mapBytes[i..<end])

                peripheral.writeValue(chunk, for: tx, type: .withoutResponse)

                // Yield and introduce a 10ms delay between chunks to prevent buffer overflow
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // startScanning() // Auto-scan if desired, but better to control via UI
        } else {
            connectionState = .disconnected
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == "BikeComp" || peripheral.name == "Adafruit Bluefruit LE" {
            targetPeripheral = peripheral
            centralManager.stopScan()
            connectionState = .connecting
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        targetPeripheral = nil
        txCharacteristic = nil
        // Optionally auto-reconnect or restart scanning
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([rxUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == rxUUID {
                self.txCharacteristic = characteristic
            }
        }
    }
}
