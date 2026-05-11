import Foundation

public struct IQOSSavedDevice: Codable, Equatable, Sendable {
    public var identifier: UUID
    public var localName: String?
    public var model: IQOSDeviceModel
    public var serialNumber: String?

    public init(identifier: UUID, localName: String?, model: IQOSDeviceModel, serialNumber: String?) {
        self.identifier = identifier
        self.localName = localName
        self.model = model
        self.serialNumber = serialNumber
    }
}

public final class IQOSDeviceStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = "IQOSClient.savedDevices") {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func all() -> [String: IQOSSavedDevice] {
        guard let data = userDefaults.data(forKey: key) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: IQOSSavedDevice].self, from: data)) ?? [:]
    }

    public func device(label: String) -> IQOSSavedDevice? {
        all()[label.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    public func save(_ device: IQOSConnectedDevice, label: String) throws {
        let trimmed = try normalizedLabel(label)
        var devices = all()
        devices[trimmed] = IQOSSavedDevice(
            identifier: device.identifier,
            localName: device.localName,
            model: device.model,
            serialNumber: device.deviceInfo.serialNumber
        )
        try persist(devices)
    }

    public func remove(label: String) throws {
        let trimmed = try normalizedLabel(label)
        var devices = all()
        devices.removeValue(forKey: trimmed)
        try persist(devices)
    }

    private func persist(_ devices: [String: IQOSSavedDevice]) throws {
        let data = try JSONEncoder().encode(devices)
        userDefaults.set(data, forKey: key)
    }

    private func normalizedLabel(_ label: String) throws -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IQOSError.protocolEncode("label must not be empty")
        }
        return trimmed
    }
}
