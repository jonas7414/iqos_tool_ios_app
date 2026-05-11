import Foundation

enum IQOSProtocol {
    static let deviceInfoServiceUUID = "180A"
    static let coreServiceUUID = "DAEBB240-B041-11E4-9E45-0002A5D5C51B"
    static let batteryCharacteristicUUID = "F8A54120-B041-11E4-9BE7-0002A5D5C51B"
    static let scpControlCharacteristicUUID = "E16C6E20-B041-11E4-A4C3-0002A5D5C51B"

    static let modelNumberCharacteristicUUID = "2A24"
    static let serialNumberCharacteristicUUID = "2A25"
    static let softwareRevisionCharacteristicUUID = "2A28"
    static let manufacturerNameCharacteristicUUID = "2A29"

    static let loadBrightness: [UInt8] = [0x00, 0xC0, 0x02, 0x23, 0xC3]
    static let setBrightnessHigh: [[UInt8]] = [
        [0x00, 0xC0, 0x46, 0x23, 0x64, 0x00, 0x00, 0x00, 0x4F],
        [0x00, 0xC0, 0x02, 0x23, 0xC3],
        [0x00, 0xC9, 0x44, 0x24, 0x64, 0x00, 0x00, 0x00, 0x34]
    ]
    static let setBrightnessLow: [[UInt8]] = [
        [0x00, 0xC0, 0x46, 0x23, 0x1E, 0x00, 0x00, 0x00, 0xE1],
        [0x00, 0xC0, 0x02, 0x23, 0xC3],
        [0x00, 0xC9, 0x44, 0x24, 0x1E, 0x00, 0x00, 0x00, 0x9A]
    ]

    static let loadFlexPuff: [UInt8] = [0x00, 0xD2, 0x05, 0x22, 0x03, 0x00, 0x00, 0x00, 0x17]
    static let flexPuffEnable: [UInt8] = [0x00, 0xD2, 0x45, 0x22, 0x03, 0x01, 0x00, 0x00, 0x0A]
    static let flexPuffDisable: [UInt8] = [0x00, 0xD2, 0x45, 0x22, 0x03, 0x00, 0x00, 0x00, 0x0A]

    static let loadFlexBattery: [UInt8] = [0x00, 0xC9, 0x00, 0x25, 0xFB]
    static let loadPauseMode: [UInt8] = [0x00, 0xC9, 0x07, 0x24, 0x02, 0x00, 0x00, 0x00, 0x18]
    static let flexBatteryEco: [UInt8] = [0x00, 0xC9, 0x44, 0x25, 0x01, 0x00, 0x00, 0x00, 0x4D]
    static let flexBatteryPerformance: [UInt8] = [0x00, 0xC9, 0x44, 0x25, 0x00, 0x00, 0x00, 0x00, 0x5B]
    static let pauseModeEnable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x02, 0x01, 0x00, 0x00, 0x05]
    static let pauseModeDisable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x02, 0x00, 0x00, 0x00, 0x6E]

    static let smartGestureEnable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x04, 0x01, 0x00, 0x00, 0x3C]
    static let smartGestureDisable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x04, 0x00, 0x00, 0x00, 0x57]
    static let autoStartEnable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x01, 0x01, 0x00, 0x00, 0x3F]
    static let autoStartDisable: [UInt8] = [0x00, 0xC9, 0x47, 0x24, 0x01, 0x00, 0x00, 0x00, 0x54]
    static let loadAutoStart: [UInt8] = [0x00, 0xC9, 0x07, 0x24, 0x01, 0x00, 0x00, 0x00, 0x22]

    static let lockCommands: [[UInt8]] = [
        [0x00, 0xC9, 0x44, 0x04, 0x02, 0xFF, 0x00, 0x00, 0x5A],
        [0x00, 0xC9, 0x00, 0x04, 0x1C],
        [0x00, 0xC0, 0x01, 0x00, 0xF6]
    ]
    static let unlockCommands: [[UInt8]] = [
        [0x00, 0xC9, 0x44, 0x04, 0x00, 0x00, 0x00, 0x00, 0x5D],
        [0x00, 0xC9, 0x00, 0x04, 0x1C],
        [0x00, 0xC0, 0x01, 0x00, 0xF6]
    ]

    static let loadVibrationSettings: [UInt8] = [0x00, 0xC9, 0x00, 0x23, 0xE9]
    static let loadVibrateChargeStart: [UInt8] = [0x00, 0xC9, 0x07, 0x04, 0x04, 0x00, 0x00, 0x00, 0x08]
    static let startVibrate: [UInt8] = [0x00, 0xC0, 0x45, 0x22, 0x01, 0x1E, 0x00, 0x00, 0xC3]
    static let stopVibrate: [UInt8] = [0x00, 0xC0, 0x45, 0x22, 0x00, 0x1E, 0x00, 0x00, 0xD5]

    static let loadTelemetry: [UInt8] = [0x00, 0xC9, 0x10, 0x02, 0x01, 0x01, 0x75, 0xD6]
    static let loadTimestamp: [UInt8] = [0x00, 0xC0, 0x10, 0x02, 0x00, 0x04, 0x38, 0xEF]
    static let loadBatteryVoltage: [UInt8] = [0x00, 0xC0, 0x00, 0x21, 0xE7]
    static let allDiagnosisCommands = [loadTelemetry, loadTimestamp, loadTelemetry, loadBatteryVoltage]

    static let loadStickFirmware: [UInt8] = [0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00]
    static let loadHolderFirmware: [UInt8] = [0x00, 0xC9, 0x00, 0x00, 0x00, 0x00, 0x00]
    static let productNumber: [UInt8] = [0x00, 0xC0, 0x00, 0x03, 0x09]
    static let holderProductNumber: [UInt8] = [0x00, 0xC9, 0x00, 0x03, 0x09]
}

enum IQOSProtocolParser {
    static func brightness(from bytes: [UInt8]) throws -> IQOSBrightnessLevel {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid brightness response: frame too short") }
        guard bytes[0...3].elementsEqual([0x00, 0xC0, 0x86, 0x23]) else {
            throw IQOSError.protocolDecode("invalid brightness response: header mismatch")
        }
        switch bytes[4] {
        case 0x64: return .high
        case 0x1E: return .low
        default: throw IQOSError.protocolDecode("invalid brightness response: unknown level flag")
        }
    }

    static func flexPuffEnabled(from bytes: [UInt8]) throws -> Bool {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid FlexPuff response: frame too short") }
        guard bytes[0...4].elementsEqual([0x00, 0x90, 0x85, 0x22, 0x03]) else {
            throw IQOSError.protocolDecode("invalid FlexPuff response: header mismatch")
        }
        switch bytes[5] {
        case 0x01: return true
        case 0x00: return false
        default: throw IQOSError.protocolDecode("invalid FlexPuff response: unknown flag byte")
        }
    }

    static func flexBatteryMode(from bytes: [UInt8]) throws -> IQOSFlexBatteryMode {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid FlexBattery response: frame too short") }
        guard bytes[0...3].elementsEqual([0x00, 0x08, 0x84, 0x25]) else {
            throw IQOSError.protocolDecode("invalid FlexBattery response: header mismatch")
        }
        switch bytes[4] {
        case 0x00: return .performance
        case 0x01: return .eco
        default: throw IQOSError.protocolDecode("invalid FlexBattery response: unknown mode byte")
        }
    }

    static func pauseMode(from bytes: [UInt8]) throws -> Bool {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid Pause Mode response: frame too short") }
        guard bytes[0...3].elementsEqual([0x00, 0x08, 0x87, 0x24]) else {
            throw IQOSError.protocolDecode("invalid Pause Mode response: header mismatch")
        }
        switch bytes[5] {
        case 0x00: return false
        case 0x01: return true
        default: throw IQOSError.protocolDecode("invalid Pause Mode response: unknown flag byte")
        }
    }

    static func autoStart(from bytes: [UInt8]) throws -> Bool {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid Auto Start response: frame too short") }
        guard bytes[0...3].elementsEqual([0x00, 0x08, 0x87, 0x24]) else {
            throw IQOSError.protocolDecode("invalid Auto Start response: header mismatch")
        }
        guard bytes[4] == 0x01 else { throw IQOSError.protocolDecode("invalid Auto Start response: setting ID mismatch") }
        switch bytes[5] {
        case 0x00: return false
        case 0x01: return true
        default: throw IQOSError.protocolDecode("invalid Auto Start response: unknown flag byte")
        }
    }

    static func firmwareVersion(from bytes: [UInt8], kind: IQOSFirmwareKind) throws -> IQOSFirmwareVersion {
        guard bytes.count >= 10 else { throw IQOSError.protocolDecode("invalid firmware response: frame too short") }
        let kindByte: UInt8 = kind == .stick ? 0xC0 : 0x08
        guard bytes[0] == 0x00, bytes[1] == kindByte, bytes[2] == 0x88, bytes[3] == 0x00 else {
            throw IQOSError.protocolDecode("invalid firmware response: header mismatch")
        }
        return IQOSFirmwareVersion(major: bytes[6], minor: bytes[7], patch: bytes[8], year: bytes[9])
    }

    static func productNumber(from bytes: [UInt8], kind: IQOSProductNumberKind) throws -> String {
        let prefix: [UInt8] = kind == .stick ? [0x00, 0xC0, 0x88, 0x03] : [0x00, 0x08, 0x88, 0x03]
        guard bytes.count >= prefix.count else { throw IQOSError.protocolDecode("invalid product number response: frame too short") }
        guard bytes.prefix(prefix.count).elementsEqual(prefix) else {
            throw IQOSError.protocolDecode("invalid product number response: header mismatch")
        }

        let payload: ArraySlice<UInt8>
        switch kind {
        case .stick:
            guard bytes.count > prefix.count + 1 else {
                throw IQOSError.protocolDecode("invalid product number response: missing stick payload")
            }
            payload = bytes[prefix.count..<(bytes.count - 1)]
        case .holder:
            guard bytes.count > prefix.count else {
                throw IQOSError.protocolDecode("invalid product number response: missing holder payload")
            }
            payload = bytes[prefix.count..<bytes.count]
        }

        return String(payload.map { byte in
            byte >= 0x20 && byte <= 0x7E ? Character(UnicodeScalar(byte)) : "."
        })
    }

    static func vibrationSettings(from bytes: [UInt8], model: IQOSDeviceModel) throws -> IQOSVibrationSettings {
        guard bytes.count >= 9 else { throw IQOSError.protocolDecode("invalid vibration response: frame too short") }
        guard bytes[0...3].elementsEqual([0x00, 0x08, 0x84, 0x23]) else {
            throw IQOSError.protocolDecode("invalid vibration response: header mismatch")
        }
        if model.supports(.chargeStartVibration) {
            guard bytes[4] == 0x10 || bytes[4] == 0x03 else {
                throw IQOSError.protocolDecode("invalid vibration response: header mismatch")
            }
        } else if bytes[4] != 0x10 {
            throw IQOSError.protocolDecode("invalid vibration response: header mismatch")
        }

        return IQOSVibrationSettings(
            whenHeatingStart: (bytes[6] & 0x01) != 0,
            whenStartingToUse: (bytes[6] & 0x10) != 0,
            whenPuffEnd: (bytes[7] & 0x01) != 0,
            whenManuallyTerminated: (bytes[7] & 0x10) != 0
        )
    }

    static func chargeStartVibration(from bytes: [UInt8]) throws -> Bool {
        guard bytes.count >= 19 else {
            throw IQOSError.protocolDecode("invalid charge-start vibration response: frame too short")
        }
        let on: [UInt8] = [0x00, 0x08, 0x8B, 0x04, 0x04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x56]
        let off: [UInt8] = [0x00, 0x08, 0x8B, 0x04, 0x04, 0, 0, 0, 0, 0x09, 0, 0, 0, 0, 0, 0, 0, 0, 0xEE]
        if bytes == on { return true }
        if bytes == off { return false }
        return bytes[8] == 0x01
    }

    static func diagnosis(accumulating current: IQOSDiagnosticData, from bytes: [UInt8]) throws -> IQOSDiagnosticData {
        guard bytes.count >= 4 else { throw IQOSError.protocolDecode("diagnosis response too short for header") }
        var output = current
        switch [bytes[2], bytes[3]] {
        case [0x90, 0x22]:
            guard bytes.count >= 6 else { throw IQOSError.protocolDecode("invalid telemetry frame: too short for marker") }
            guard UInt16(littleEndianBytes: bytes[4], bytes[5]) == 0x0101 else {
                throw IQOSError.protocolDecode("invalid telemetry frame: wrong marker")
            }
            let blockCount = max(Int(bytes[3]).subtractingReportingOverflow(2).partialValue, 0) / 8
            let required = 6 + blockCount * 8
            guard bytes.count >= required else {
                throw IQOSError.protocolDecode("invalid telemetry frame: expected \(required) bytes, got \(bytes.count)")
            }
            for index in 0..<blockCount {
                let offset = 6 + index * 8
                let value = UInt16(littleEndianBytes: bytes[offset + 4], bytes[offset + 5])
                switch bytes[offset + 7] {
                case 0x8E: output.totalSmokingCount = value
                case 0x17: output.daysUsed = value
                default: break
                }
            }
        case [0x80, 0x02]:
            guard bytes.count >= 6 else { throw IQOSError.protocolDecode("invalid timestamp frame: too short") }
            output.daysUsed = UInt16(littleEndianBytes: bytes[4], bytes[5])
        case [0x88, 0x21]:
            guard bytes.count >= 7 else { throw IQOSError.protocolDecode("invalid battery voltage frame: too short") }
            output.batteryVoltage = Float(UInt16(littleEndianBytes: bytes[5], bytes[6])) / 1000.0
        default:
            break
        }
        return output
    }
}

extension IQOSProtocol {
    static func brightnessCommands(for level: IQOSBrightnessLevel) -> [[UInt8]] {
        level == .high ? setBrightnessHigh : setBrightnessLow
    }

    static func flexPuffCommand(enabled: Bool) -> [UInt8] {
        enabled ? flexPuffEnable : flexPuffDisable
    }

    static func flexBatteryCommand(mode: IQOSFlexBatteryMode) -> [UInt8] {
        mode == .eco ? flexBatteryEco : flexBatteryPerformance
    }

    static func pauseModeCommand(enabled: Bool) -> [UInt8] {
        enabled ? pauseModeEnable : pauseModeDisable
    }

    static func smartGestureCommand(enabled: Bool) -> [UInt8] {
        enabled ? smartGestureEnable : smartGestureDisable
    }

    static func autoStartCommand(enabled: Bool) -> [UInt8] {
        enabled ? autoStartEnable : autoStartDisable
    }

    static func firmwareCommand(kind: IQOSFirmwareKind) -> [UInt8] {
        kind == .stick ? loadStickFirmware : loadHolderFirmware
    }

    static func productNumberCommand(kind: IQOSProductNumberKind) -> [UInt8] {
        kind == .stick ? productNumber : holderProductNumber
    }
}

extension UInt16 {
    fileprivate init(littleEndianBytes low: UInt8, _ high: UInt8) {
        self = UInt16(low) | (UInt16(high) << 8)
    }
}
