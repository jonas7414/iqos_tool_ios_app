import Foundation

public enum IQOSError: Error, Equatable, Sendable {
    case bluetoothUnavailable
    case deviceNotFound
    case disconnected
    case characteristicNotFound(String)
    case unsupported(String)
    case protocolDecode(String)
    case protocolEncode(String)
    case timeout
    case transport(String)
}
