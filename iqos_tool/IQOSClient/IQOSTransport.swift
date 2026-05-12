import Foundation

public protocol IQOSTransport: Sendable {
    var model: IQOSDeviceModel { get }
    var deviceInfo: IQOSDeviceInfo { get }

    func readBatteryLevel() async throws -> UInt8
    func request(_ command: [UInt8], timeout: TimeInterval) async throws -> [UInt8]
    func send(_ command: [UInt8]) async throws
}

public extension IQOSTransport {
    func request(_ command: [UInt8]) async throws -> [UInt8] {
        try await request(command, timeout: 5)
    }
}

public actor IQOSDevice {
    public let connectedDevice: IQOSConnectedDevice
    private let transport: any IQOSTransport

    public init(transport: any IQOSTransport, identifier: UUID, localName: String?) {
        self.transport = transport
        self.connectedDevice = IQOSConnectedDevice(
            identifier: identifier,
            localName: localName,
            model: transport.model,
            deviceInfo: transport.deviceInfo
        )
    }

    public func readBatteryLevel() async throws -> UInt8 {
        try await transport.readBatteryLevel()
    }

    public func readBrightness() async throws -> IQOSBrightnessLevel {
        try require(.brightness)
        let response = try await transport.request(IQOSProtocol.loadBrightness)
        return try IQOSProtocolParser.brightness(from: response)
    }

    public func setBrightness(_ level: IQOSBrightnessLevel) async throws {
        try require(.brightness)
        for command in IQOSProtocol.brightnessCommands(for: level) {
            try await transport.send(command)
        }
    }

    public func readFlexPuffEnabled() async throws -> Bool {
        try require(.flexPuff)
        let response = try await transport.request(IQOSProtocol.loadFlexPuff)
        return try IQOSProtocolParser.flexPuffEnabled(from: response)
    }

    public func setFlexPuffEnabled(_ enabled: Bool) async throws {
        try require(.flexPuff)
        try await transport.send(IQOSProtocol.flexPuffCommand(enabled: enabled))
    }

    public func readFlexBatterySettings() async throws -> IQOSFlexBatterySettings {
        try require(.flexBattery)
        let modeResponse = try await transport.request(IQOSProtocol.loadFlexBattery)
        let pauseResponse = try await transport.request(IQOSProtocol.loadPauseMode)
        return IQOSFlexBatterySettings(
            mode: try IQOSProtocolParser.flexBatteryMode(from: modeResponse),
            pauseMode: try IQOSProtocolParser.pauseMode(from: pauseResponse)
        )
    }

    public func setFlexBatterySettings(_ settings: IQOSFlexBatterySettings) async throws {
        try require(.flexBattery)
        try await transport.send(IQOSProtocol.flexBatteryCommand(mode: settings.mode))
        try await transport.send(IQOSProtocol.loadFlexBattery)
        if let pauseMode = settings.pauseMode {
            try await transport.send(IQOSProtocol.pauseModeCommand(enabled: pauseMode))
            try await transport.send(IQOSProtocol.loadPauseMode)
        }
    }

    public func setSmartGestureEnabled(_ enabled: Bool) async throws {
        try require(.smartGesture)
        try await transport.send(IQOSProtocol.smartGestureCommand(enabled: enabled))
    }

    public func readAutoStartEnabled() async throws -> Bool {
        try require(.autoStart)
        let response = try await transport.request(IQOSProtocol.loadAutoStart)
        return try IQOSProtocolParser.autoStart(from: response)
    }

    public func setAutoStartEnabled(_ enabled: Bool) async throws {
        try require(.autoStart)
        try await transport.send(IQOSProtocol.autoStartCommand(enabled: enabled))
    }

    public func lock() async throws {
        try require(.deviceLock)
        for command in IQOSProtocol.lockCommands {
            try await transport.send(command)
        }
    }

    public func unlock() async throws {
        try require(.deviceLock)
        for command in IQOSProtocol.unlockCommands {
            try await transport.send(command)
        }
    }

    public func readVibrationSettings() async throws -> IQOSVibrationSettings {
        try require(.vibration)
        var chargeStart: Bool?
        if transport.model.supports(.chargeStartVibration) {
            let response = try await transport.request(IQOSProtocol.loadVibrateChargeStart)
            chargeStart = try IQOSProtocolParser.chargeStartVibration(from: response)
        }

        let response = try await transport.request(IQOSProtocol.loadVibrationSettings)
        var settings = try IQOSProtocolParser.vibrationSettings(from: response, model: transport.model)
        settings.whenChargingStart = chargeStart
        return settings
    }

    public func setVibrationSettings(_ settings: IQOSVibrationSettings) async throws {
        try require(.vibration)
        var normalized = settings
        if transport.model.supports(.chargeStartVibration), normalized.whenChargingStart == nil {
            normalized.whenChargingStart = (try? await readVibrationSettings())?.whenChargingStart ?? false
        } else if !transport.model.supports(.chargeStartVibration) {
            normalized.whenChargingStart = nil
        }

        for command in try IQOSProtocol.vibrationCommands(for: normalized, model: transport.model) {
            try await transport.send(command)
        }
    }

    public func startFindMyIQOS() async throws {
        try await transport.send(IQOSProtocol.startVibrate)
    }

    public func stopFindMyIQOS() async throws {
        try await transport.send(IQOSProtocol.stopVibrate)
    }

    public func readDiagnosis() async throws -> IQOSDiagnosticData {
        var data = IQOSDiagnosticData()
        for command in IQOSProtocol.allDiagnosisCommands {
            let response = try await transport.request(command, timeout: 10)
            data = try IQOSProtocolParser.diagnosis(accumulating: data, from: response)
        }
        return data
    }

    public func readFirmwareVersion(kind: IQOSFirmwareKind) async throws -> IQOSFirmwareVersion {
        let response = try await transport.request(IQOSProtocol.firmwareCommand(kind: kind))
        return try IQOSProtocolParser.firmwareVersion(from: response, kind: kind)
    }

    public func readProductNumber(kind: IQOSProductNumberKind) async throws -> String {
        let response = try await transport.request(IQOSProtocol.productNumberCommand(kind: kind))
        return try IQOSProtocolParser.productNumber(from: response, kind: kind)
    }

    public func readBatteryVoltage() async throws -> Float {
        let response = try await transport.request(IQOSProtocol.loadBatteryVoltage)
        let data = try IQOSProtocolParser.diagnosis(accumulating: IQOSDiagnosticData(), from: response)
        guard let voltage = data.batteryVoltage else {
            throw IQOSError.protocolDecode("battery voltage not present in response")
        }
        return voltage
    }

    public func readDeviceStatus() async throws -> IQOSDeviceStatus {
        let productNumber = try await readProductNumber(kind: .stick)
        let stickFirmware = try await readFirmwareVersion(kind: .stick)

        var holderProductNumber: String?
        var holderFirmware: IQOSFirmwareVersion?
        if transport.model.supportsHolderFeatures {
            holderProductNumber = try await readProductNumber(kind: .holder)
            holderFirmware = try await readFirmwareVersion(kind: .holder)
        }

        let voltage: Float?
        do {
            voltage = try await readBatteryVoltage()
        } catch IQOSError.transport {
            voltage = nil
        }

        return IQOSDeviceStatus(
            model: transport.model,
            deviceInfo: transport.deviceInfo,
            productNumber: productNumber,
            stickFirmware: stickFirmware,
            holderProductNumber: holderProductNumber,
            holderFirmware: holderFirmware,
            batteryVoltage: voltage
        )
    }

    private func require(_ capability: IQOSDeviceCapability) throws {
        guard transport.model.supports(capability) else {
            throw IQOSError.unsupported("\(capability) is not supported for model \(transport.model.rawValue)")
        }
    }
}
