#if canImport(CoreBluetooth)
import CoreBluetooth
import Foundation

public final class CoreBluetoothIQOSClient: NSObject, @unchecked Sendable {
    public private(set) var discoveredDevices: [IQOSDiscoveredDevice] = []

    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)
    private var scanContinuation: AsyncStream<IQOSDiscoveredDevice>.Continuation?
    private var connectContinuation: CheckedContinuation<CBPeripheral, Error>?
    private var targetPeripheralID: UUID?
    private var peripherals: [UUID: CBPeripheral] = [:]

    public override init() {
        super.init()
    }

    public func scan(timeout: TimeInterval = 8) -> AsyncStream<IQOSDiscoveredDevice> {
        AsyncStream { continuation in
            self.scanContinuation = continuation
            Task {
                try? await self.waitUntilPoweredOn()
                self.centralManager.scanForPeripherals(
                    withServices: [CBUUID(string: IQOSProtocol.coreServiceUUID)],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.centralManager.stopScan()
                continuation.finish()
            }
        }
    }

    public func connect(to discoveredDevice: IQOSDiscoveredDevice, timeout: TimeInterval = 12) async throws -> IQOSDevice {
        try await waitUntilPoweredOn()

        guard let peripheral = peripherals[discoveredDevice.id] else {
            throw IQOSError.deviceNotFound
        }

        let connected = try await withThrowingTaskGroup(of: CBPeripheral.self) { group in
            group.addTask {
                try await self.connectPeripheral(peripheral)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw IQOSError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        let transport = try await CoreBluetoothIQOSTransport(peripheral: connected, advertisedName: discoveredDevice.name)
        return IQOSDevice(transport: transport, identifier: connected.identifier, localName: connected.name)
    }

    public func connectToKnownDevice(identifier: UUID, localName: String?, timeout: TimeInterval = 12) async throws -> IQOSDevice {
        try await waitUntilPoweredOn()

        let serviceUUID = CBUUID(string: IQOSProtocol.coreServiceUUID)
        let peripheral = peripherals[identifier]
            ?? centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
            ?? centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID]).first(where: { $0.identifier == identifier })

        guard let peripheral else {
            throw IQOSError.deviceNotFound
        }

        peripherals[identifier] = peripheral

        let connected = try await withThrowingTaskGroup(of: CBPeripheral.self) { group in
            group.addTask {
                if peripheral.state == .connected {
                    return peripheral
                }
                return try await self.connectPeripheral(peripheral)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw IQOSError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        let transport = try await CoreBluetoothIQOSTransport(peripheral: connected, advertisedName: localName)
        return IQOSDevice(transport: transport, identifier: connected.identifier, localName: connected.name ?? localName)
    }

    private func waitUntilPoweredOn() async throws {
        while centralManager.state == .unknown || centralManager.state == .resetting {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard centralManager.state == .poweredOn else {
            throw IQOSError.bluetoothUnavailable
        }
    }

    private func connectPeripheral(_ peripheral: CBPeripheral) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { continuation in
            connectContinuation = continuation
            targetPeripheralID = peripheral.identifier
            centralManager.connect(peripheral)
        }
    }
}

extension CoreBluetoothIQOSClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard (name ?? "").uppercased().contains("IQOS") else { return }

        peripherals[peripheral.identifier] = peripheral
        let device = IQOSDiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            model: IQOSDeviceModel(localName: name),
            rssi: RSSI.intValue
        )

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
            scanContinuation?.yield(device)
        } else {
            discoveredDevices.append(device)
            scanContinuation?.yield(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == targetPeripheralID else { return }
        connectContinuation?.resume(returning: peripheral)
        connectContinuation = nil
        targetPeripheralID = nil
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == targetPeripheralID else { return }
        connectContinuation?.resume(throwing: error ?? IQOSError.transport("failed to connect"))
        connectContinuation = nil
        targetPeripheralID = nil
    }
}

public final class CoreBluetoothIQOSTransport: NSObject, IQOSTransport, @unchecked Sendable {
    public private(set) var model: IQOSDeviceModel = .unknown
    public private(set) var deviceInfo = IQOSDeviceInfo()

    private let peripheral: CBPeripheral
    private let advertisedName: String?
    private var batteryCharacteristic: CBCharacteristic?
    private var scpControlCharacteristic: CBCharacteristic?
    private var readContinuations: [CBUUID: CheckedContinuation<[UInt8], Error>] = [:]
    private var notificationContinuation: CheckedContinuation<[UInt8], Error>?
    private var discoveryContinuation: CheckedContinuation<Void, Error>?

    public init(peripheral: CBPeripheral, advertisedName: String? = nil) async throws {
        self.peripheral = peripheral
        self.advertisedName = advertisedName
        super.init()
        peripheral.delegate = self
        try await discover()
    }

    public func readBatteryLevel() async throws -> UInt8 {
        guard let characteristic = batteryCharacteristic else {
            throw IQOSError.characteristicNotFound(IQOSProtocol.batteryCharacteristicUUID)
        }
        let frame = try await read(characteristic)
        guard frame.count >= 3 else {
            throw IQOSError.protocolDecode("battery characteristic frame too short to extract level")
        }
        return frame[2]
    }

    public func request(_ command: [UInt8]) async throws -> [UInt8] {
        try await send(command)
        return try await withCheckedThrowingContinuation { continuation in
            notificationContinuation = continuation
        }
    }

    public func send(_ command: [UInt8]) async throws {
        guard let characteristic = scpControlCharacteristic else {
            throw IQOSError.characteristicNotFound(IQOSProtocol.scpControlCharacteristicUUID)
        }
        peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
    }

    private func discover() async throws {
        try await withCheckedThrowingContinuation { continuation in
            discoveryContinuation = continuation
            peripheral.discoverServices([
                CBUUID(string: IQOSProtocol.deviceInfoServiceUUID),
                CBUUID(string: IQOSProtocol.coreServiceUUID)
            ])
        }
        model = IQOSDeviceModel(localName: peripheral.name ?? advertisedName)
    }

    private func read(_ characteristic: CBCharacteristic) async throws -> [UInt8] {
        try await withCheckedThrowingContinuation { continuation in
            readContinuations[characteristic.uuid] = continuation
            peripheral.readValue(for: characteristic)
        }
    }
}

extension CoreBluetoothIQOSTransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            discoveryContinuation?.resume(throwing: error)
            discoveryContinuation = nil
            return
        }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            discoveryContinuation?.resume(throwing: error)
            discoveryContinuation = nil
            return
        }

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case CBUUID(string: IQOSProtocol.batteryCharacteristicUUID):
                batteryCharacteristic = characteristic
            case CBUUID(string: IQOSProtocol.scpControlCharacteristicUUID):
                scpControlCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case CBUUID(string: IQOSProtocol.modelNumberCharacteristicUUID),
                CBUUID(string: IQOSProtocol.serialNumberCharacteristicUUID),
                CBUUID(string: IQOSProtocol.softwareRevisionCharacteristicUUID),
                CBUUID(string: IQOSProtocol.manufacturerNameCharacteristicUUID):
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }

        if batteryCharacteristic != nil, scpControlCharacteristic != nil {
            discoveryContinuation?.resume()
            discoveryContinuation = nil
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let continuation = readContinuations.removeValue(forKey: characteristic.uuid) {
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: [UInt8](characteristic.value ?? Data()))
            }
            return
        }

        if characteristic.uuid == CBUUID(string: IQOSProtocol.scpControlCharacteristicUUID),
           let continuation = notificationContinuation {
            notificationContinuation = nil
            continuation.resume(returning: [UInt8](characteristic.value ?? Data()))
            return
        }

        guard let value = characteristic.value.flatMap({ String(data: $0, encoding: .utf8) }) else {
            return
        }
        switch characteristic.uuid {
        case CBUUID(string: IQOSProtocol.modelNumberCharacteristicUUID):
            deviceInfo.modelNumber = value
        case CBUUID(string: IQOSProtocol.serialNumberCharacteristicUUID):
            deviceInfo.serialNumber = value
        case CBUUID(string: IQOSProtocol.softwareRevisionCharacteristicUUID):
            deviceInfo.softwareRevision = value
        case CBUUID(string: IQOSProtocol.manufacturerNameCharacteristicUUID):
            deviceInfo.manufacturerName = value
        default:
            break
        }
    }
}
#endif
