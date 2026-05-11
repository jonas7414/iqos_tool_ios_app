import Foundation

public enum IQOSDeviceModel: String, Codable, CaseIterable, Sendable {
    case ilumaOne
    case iluma
    case ilumaPrime
    case ilumaIOne
    case ilumaI
    case ilumaIPrime
    case unknown

    public init(localName: String?) {
        let normalized = (localName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalized.contains("ILUMA I PRIME") {
            self = .ilumaIPrime
        } else if normalized.contains("ILUMA I ONE") {
            self = .ilumaIOne
        } else if normalized.contains("ILUMA I") {
            self = .ilumaI
        } else if normalized.contains("ILUMA PRIME") {
            self = .ilumaPrime
        } else if normalized.contains("ILUMA ONE") {
            self = .ilumaOne
        } else if normalized.contains("ILUMA") {
            self = .iluma
        } else {
            self = .unknown
        }
    }

    public var isOneFormFactor: Bool {
        self == .ilumaOne || self == .ilumaIOne
    }

    public var isIlumaIFamily: Bool {
        self == .ilumaIOne || self == .ilumaI || self == .ilumaIPrime
    }

    public var supportsHolderFeatures: Bool {
        self == .iluma || self == .ilumaPrime || self == .ilumaI || self == .ilumaIPrime
    }

    public func supports(_ capability: IQOSDeviceCapability) -> Bool {
        switch capability {
        case .brightness, .vibration, .deviceLock:
            self != .unknown
        case .flexPuff, .flexBattery:
            self == .ilumaI || self == .ilumaIPrime
        case .smartGesture:
            self == .iluma || self == .ilumaPrime || isIlumaIFamily
        case .autoStart:
            isIlumaIFamily
        case .chargeStartVibration:
            supportsHolderFeatures
        }
    }
}

public enum IQOSDeviceCapability: Sendable {
    case brightness
    case vibration
    case flexPuff
    case flexBattery
    case smartGesture
    case autoStart
    case deviceLock
    case chargeStartVibration
}

public struct IQOSDeviceInfo: Codable, Equatable, Sendable {
    public var modelNumber: String?
    public var serialNumber: String?
    public var softwareRevision: String?
    public var manufacturerName: String?

    public init(
        modelNumber: String? = nil,
        serialNumber: String? = nil,
        softwareRevision: String? = nil,
        manufacturerName: String? = nil
    ) {
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.softwareRevision = softwareRevision
        self.manufacturerName = manufacturerName
    }
}

public struct IQOSDiscoveredDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String?
    public let model: IQOSDeviceModel
    public let rssi: Int?

    public init(id: UUID, name: String?, model: IQOSDeviceModel, rssi: Int? = nil) {
        self.id = id
        self.name = name
        self.model = model
        self.rssi = rssi
    }
}

public struct IQOSConnectedDevice: Equatable, Sendable {
    public let identifier: UUID
    public let localName: String?
    public let model: IQOSDeviceModel
    public let deviceInfo: IQOSDeviceInfo

    public init(identifier: UUID, localName: String?, model: IQOSDeviceModel, deviceInfo: IQOSDeviceInfo) {
        self.identifier = identifier
        self.localName = localName
        self.model = model
        self.deviceInfo = deviceInfo
    }
}

public enum IQOSBrightnessLevel: String, Codable, Equatable, Sendable {
    case high
    case low
}

public struct IQOSVibrationSettings: Codable, Equatable, Sendable {
    public var whenChargingStart: Bool?
    public var whenHeatingStart: Bool
    public var whenStartingToUse: Bool
    public var whenPuffEnd: Bool
    public var whenManuallyTerminated: Bool

    public init(
        whenChargingStart: Bool? = nil,
        whenHeatingStart: Bool,
        whenStartingToUse: Bool,
        whenPuffEnd: Bool,
        whenManuallyTerminated: Bool
    ) {
        self.whenChargingStart = whenChargingStart
        self.whenHeatingStart = whenHeatingStart
        self.whenStartingToUse = whenStartingToUse
        self.whenPuffEnd = whenPuffEnd
        self.whenManuallyTerminated = whenManuallyTerminated
    }
}

public enum IQOSFlexBatteryMode: String, Codable, Equatable, Sendable {
    case performance
    case eco
}

public struct IQOSFlexBatterySettings: Codable, Equatable, Sendable {
    public var mode: IQOSFlexBatteryMode
    public var pauseMode: Bool?

    public init(mode: IQOSFlexBatteryMode, pauseMode: Bool?) {
        self.mode = mode
        self.pauseMode = pauseMode
    }
}

public struct IQOSDiagnosticData: Codable, Equatable, Sendable {
    public var totalSmokingCount: UInt16?
    public var daysUsed: UInt16?
    public var batteryVoltage: Float?

    public init(totalSmokingCount: UInt16? = nil, daysUsed: UInt16? = nil, batteryVoltage: Float? = nil) {
        self.totalSmokingCount = totalSmokingCount
        self.daysUsed = daysUsed
        self.batteryVoltage = batteryVoltage
    }
}

public enum IQOSFirmwareKind: Sendable {
    case stick
    case holder
}

public struct IQOSFirmwareVersion: Codable, Equatable, CustomStringConvertible, Sendable {
    public var major: UInt8
    public var minor: UInt8
    public var patch: UInt8
    public var year: UInt8

    public init(major: UInt8, minor: UInt8, patch: UInt8, year: UInt8) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.year = year
    }

    public var description: String {
        "v\(major).\(minor).\(patch).\(year)"
    }
}

public enum IQOSProductNumberKind: Sendable {
    case stick
    case holder
}

public struct IQOSDeviceStatus: Equatable, Sendable {
    public var model: IQOSDeviceModel
    public var deviceInfo: IQOSDeviceInfo
    public var productNumber: String
    public var stickFirmware: IQOSFirmwareVersion
    public var holderProductNumber: String?
    public var holderFirmware: IQOSFirmwareVersion?
    public var batteryVoltage: Float?

    public init(
        model: IQOSDeviceModel,
        deviceInfo: IQOSDeviceInfo,
        productNumber: String,
        stickFirmware: IQOSFirmwareVersion,
        holderProductNumber: String? = nil,
        holderFirmware: IQOSFirmwareVersion? = nil,
        batteryVoltage: Float? = nil
    ) {
        self.model = model
        self.deviceInfo = deviceInfo
        self.productNumber = productNumber
        self.stickFirmware = stickFirmware
        self.holderProductNumber = holderProductNumber
        self.holderFirmware = holderFirmware
        self.batteryVoltage = batteryVoltage
    }
}
