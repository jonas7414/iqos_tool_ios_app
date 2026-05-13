#if canImport(CoreBluetooth)
import CoreBluetooth
import Foundation

public final class CoreBluetoothIQOSClient: NSObject, @unchecked Sendable {
    public private(set) var discoveredDevices: [IQOSDiscoveredDevice] = []

    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)
    private var scanContinuation: AsyncStream<IQOSDiscoveredDevice>.Continuation?
    private var scanSessionID: UUID?
    private var scanTimeoutTask: Task<Void, Never>?
    private var connectContinuation: CheckedContinuation<CBPeripheral, Error>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var targetPeripheralID: UUID?
    private var peripherals: [UUID: CBPeripheral] = [:]

    public override init() {
        super.init()
    }

    public func scan(timeout: TimeInterval = 8) -> AsyncStream<IQOSDiscoveredDevice> {
        AsyncStream { continuation in
            self.stopScan()

            let sessionID = UUID()
            self.scanSessionID = sessionID
            self.scanContinuation = continuation

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.finishScan(sessionID: sessionID, reason: "terminated")
                }
            }

            self.scanTimeoutTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.waitUntilPoweredOn()
                } catch {
                    Self.log("Scan skipped: \(error)")
                    self.finishScan(sessionID: sessionID, reason: "unavailable")
                    return
                }

                guard self.scanSessionID == sessionID else { return }
                Self.log("Scan started")
                self.centralManager.scanForPeripherals(
                    withServices: [CBUUID(string: IQOSProtocol.coreServiceUUID)],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.finishScan(sessionID: sessionID, reason: "timeout")
            }
        }
    }

    public func stopScan() {
        finishScan(sessionID: scanSessionID, reason: "caller")
    }

    private func finishScan(sessionID: UUID?, reason: String) {
        guard let activeSessionID = scanSessionID, activeSessionID == sessionID else { return }
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        centralManager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
        scanSessionID = nil
        Self.log("Scan stopped (\(reason))")
    }

    public func connect(to discoveredDevice: IQOSDiscoveredDevice, timeout: TimeInterval = 12) async throws -> IQOSDevice {
        try await waitUntilPoweredOn()
        Self.log("Connect requested: \(discoveredDevice.id.uuidString)")

        guard let peripheral = peripherals[discoveredDevice.id] else {
            Self.log("Connect failed: peripheral not found")
            throw IQOSError.deviceNotFound
        }

        let connected = try await connectPeripheral(peripheral, timeout: timeout)

        let transport = try await CoreBluetoothIQOSTransport(peripheral: connected, advertisedName: discoveredDevice.name)
        Self.log("Transport ready: \(connected.identifier.uuidString)")
        return IQOSDevice(transport: transport, identifier: connected.identifier, localName: connected.name)
    }

    public func connectToKnownDevice(identifier: UUID, localName: String?, timeout: TimeInterval = 12) async throws -> IQOSDevice {
        try await waitUntilPoweredOn()
        Self.log("Known device connect requested: \(identifier.uuidString)")

        let serviceUUID = CBUUID(string: IQOSProtocol.coreServiceUUID)
        var effectiveLocalName = localName
        var peripheral = peripherals[identifier]
            ?? centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
            ?? centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID]).first(where: { $0.identifier == identifier })

        if peripheral == nil,
           let discovered = await scanForKnownDevice(identifier: identifier, localName: localName, timeout: min(timeout, 5)) {
            effectiveLocalName = discovered.name ?? localName
            peripheral = peripherals[discovered.id]
        }

        guard let peripheral else {
            Self.log("Known device connect failed: peripheral not found")
            throw IQOSError.deviceNotFound
        }

        peripherals[identifier] = peripheral

        let connected = peripheral.state == .connected ? peripheral : try await connectPeripheral(peripheral, timeout: timeout)

        let transport = try await CoreBluetoothIQOSTransport(peripheral: connected, advertisedName: effectiveLocalName)
        Self.log("Known device transport ready: \(connected.identifier.uuidString)")
        return IQOSDevice(transport: transport, identifier: connected.identifier, localName: connected.name ?? effectiveLocalName)
    }

    private func scanForKnownDevice(identifier: UUID, localName: String?, timeout: TimeInterval) async -> IQOSDiscoveredDevice? {
        Self.log("Known device scan fallback started: \(identifier.uuidString)")
        for await discovered in scan(timeout: timeout) {
            if discovered.id == identifier {
                Self.log("Known device found by identifier during scan fallback")
                stopScan()
                return discovered
            }

            guard let localName else { continue }
            let discoveredName = discovered.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let savedName = localName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !savedName.isEmpty, discoveredName == savedName {
                Self.log("Known device found by local name during scan fallback")
                stopScan()
                return discovered
            }
        }

        Self.log("Known device scan fallback finished without match")
        return nil
    }

    private func waitUntilPoweredOn() async throws {
        while centralManager.state == .unknown || centralManager.state == .resetting {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard centralManager.state == .poweredOn else {
            Self.log("Bluetooth unavailable: state=\(centralManager.state.rawValue)")
            throw IQOSError.bluetoothUnavailable
        }
    }

    private func connectPeripheral(_ peripheral: CBPeripheral, timeout: TimeInterval) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBPeripheral, Error>) in
            if connectContinuation != nil {
                continuation.resume(throwing: IQOSError.transport("another connection is already in progress"))
                return
            }

            connectContinuation = continuation
            targetPeripheralID = peripheral.identifier
            Self.log("Central connect started: \(peripheral.identifier.uuidString), state=\(peripheral.state.rawValue)")
            centralManager.connect(peripheral)
            connectTimeoutTask = Task { [weak self, weak peripheral] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self, let peripheral, self.targetPeripheralID == peripheral.identifier else { return }
                Self.log("Central connect timed out: \(peripheral.identifier.uuidString)")
                self.centralManager.cancelPeripheralConnection(peripheral)
                self.connectContinuation?.resume(throwing: IQOSError.timeout)
                self.connectContinuation = nil
                self.targetPeripheralID = nil
                self.connectTimeoutTask = nil
            }
        }
    }

    private static func log(_ message: String) {
        print("[IQOS BLE] \(message)")
    }
}

extension CoreBluetoothIQOSClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Self.log("Central state changed: \(central.state.rawValue)")
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard (name ?? "").uppercased().contains("IQOS") else { return }

        peripherals[peripheral.identifier] = peripheral
        Self.log("Discovered peripheral: \(peripheral.identifier.uuidString), name=\(name ?? "nil"), rssi=\(RSSI)")
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
        Self.log("Central connected: \(peripheral.identifier.uuidString)")
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connectContinuation?.resume(returning: peripheral)
        connectContinuation = nil
        targetPeripheralID = nil
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == targetPeripheralID else { return }
        Self.log("Central failed to connect: \(peripheral.identifier.uuidString), error=\(String(describing: error))")
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connectContinuation?.resume(throwing: error ?? IQOSError.transport("failed to connect"))
        connectContinuation = nil
        targetPeripheralID = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Self.log("Central disconnected: \(peripheral.identifier.uuidString), error=\(String(describing: error))")
        guard peripheral.identifier == targetPeripheralID else { return }
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connectContinuation?.resume(throwing: error ?? IQOSError.transport("disconnected while connecting"))
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
    private var notificationTimeoutTask: Task<Void, Never>?
    private var writeContinuation: CheckedContinuation<Void, Error>?
    private var writeTimeoutTask: Task<Void, Never>?
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

    public func request(_ command: [UInt8], timeout: TimeInterval = 5) async throws -> [UInt8] {
        return try await withCheckedThrowingContinuation { continuation in
            if notificationContinuation != nil {
                continuation.resume(throwing: IQOSError.transport("another request is already waiting for a response"))
                return
            }

            notificationContinuation = continuation
            notificationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self, self.notificationContinuation != nil else { return }
                self.notificationContinuation?.resume(throwing: IQOSError.timeout)
                self.notificationContinuation = nil
                self.notificationTimeoutTask = nil
            }
            Task {
                do {
                    try await send(command)
                } catch {
                    if self.notificationContinuation != nil {
                        self.notificationTimeoutTask?.cancel()
                        self.notificationTimeoutTask = nil
                        self.notificationContinuation = nil
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func send(_ command: [UInt8]) async throws {
        guard let characteristic = scpControlCharacteristic else {
            throw IQOSError.characteristicNotFound(IQOSProtocol.scpControlCharacteristicUUID)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if writeContinuation != nil {
                continuation.resume(throwing: IQOSError.transport("another write is already in progress"))
                return
            }

            writeContinuation = continuation
            writeTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, self.writeContinuation != nil else { return }
                self.writeContinuation?.resume(throwing: IQOSError.timeout)
                self.writeContinuation = nil
                self.writeTimeoutTask = nil
            }
            peripheral.writeValue(Data(command), for: characteristic, type: .withResponse)
        }
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
            notificationTimeoutTask?.cancel()
            notificationTimeoutTask = nil
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

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == CBUUID(string: IQOSProtocol.scpControlCharacteristicUUID),
              let continuation = writeContinuation else {
            return
        }

        writeTimeoutTask?.cancel()
        writeTimeoutTask = nil
        writeContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
#endif
