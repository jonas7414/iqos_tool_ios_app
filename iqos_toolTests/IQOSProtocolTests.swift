import XCTest
@testable import iqos_tool

final class IQOSProtocolTests: XCTestCase {
    func testParsesBrightness() throws {
        XCTAssertEqual(
            try IQOSProtocolParser.brightness(from: [0x00, 0xC0, 0x86, 0x23, 0x64, 0, 0, 0, 0]),
            .high
        )
        XCTAssertEqual(
            try IQOSProtocolParser.brightness(from: [0x00, 0xC0, 0x86, 0x23, 0x1E, 0, 0, 0, 0]),
            .low
        )
    }

    func testParsesFlexPuff() throws {
        XCTAssertTrue(try IQOSProtocolParser.flexPuffEnabled(from: [0x00, 0x90, 0x85, 0x22, 0x03, 0x01, 0, 0, 0]))
        XCTAssertFalse(try IQOSProtocolParser.flexPuffEnabled(from: [0x00, 0x90, 0x85, 0x22, 0x03, 0x00, 0, 0, 0]))
    }

    func testParsesFlexBatteryAndPauseMode() throws {
        XCTAssertEqual(
            try IQOSProtocolParser.flexBatteryMode(from: [0x00, 0x08, 0x84, 0x25, 0x01, 0, 0, 0, 0]),
            .eco
        )
        XCTAssertTrue(try IQOSProtocolParser.pauseMode(from: [0x00, 0x08, 0x87, 0x24, 0x02, 0x01, 0, 0, 0]))
    }

    func testParsesVibrationSettings() throws {
        let settings = try IQOSProtocolParser.vibrationSettings(
            from: [0x00, 0x08, 0x84, 0x23, 0x10, 0x00, 0x01, 0x10, 0x77],
            model: .ilumaOne
        )

        XCTAssertTrue(settings.whenHeatingStart)
        XCTAssertFalse(settings.whenStartingToUse)
        XCTAssertFalse(settings.whenPuffEnd)
        XCTAssertTrue(settings.whenManuallyTerminated)
    }

    func testParsesFirmwareAndProductNumber() throws {
        let firmware = try IQOSProtocolParser.firmwareVersion(
            from: [0x00, 0x08, 0x88, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x19],
            kind: .holder
        )
        XCTAssertEqual(firmware.description, "v1.2.3.25")

        let bytes = [UInt8]([0x00, 0xC0, 0x88, 0x03]) + Array("ABCD123456".utf8) + [0xAA]
        XCTAssertEqual(try IQOSProtocolParser.productNumber(from: bytes, kind: .stick), "ABCD123456")
    }

    func testAccumulatesDiagnosisFrames() throws {
        var data = IQOSDiagnosticData()
        data = try IQOSProtocolParser.diagnosis(
            accumulating: data,
            from: [0x00, 0x08, 0x80, 0x02, 0x1E, 0x00, 0x00, 0x00]
        )
        data = try IQOSProtocolParser.diagnosis(
            accumulating: data,
            from: [0x00, 0x08, 0x88, 0x21, 0x00, 0xE8, 0x0F, 0x00, 0x00]
        )

        XCTAssertEqual(data.daysUsed, 30)
        XCTAssertEqual(data.batteryVoltage, 4.072)
    }

    func testModelDetectionOrder() {
        XCTAssertEqual(IQOSDeviceModel(localName: "IQOS ILUMA i PRIME"), .ilumaIPrime)
        XCTAssertEqual(IQOSDeviceModel(localName: "IQOS ILUMA i ONE"), .ilumaIOne)
        XCTAssertEqual(IQOSDeviceModel(localName: "IQOS ILUMA PRIME"), .ilumaPrime)
    }
}
