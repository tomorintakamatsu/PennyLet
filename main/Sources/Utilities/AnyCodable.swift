import Foundation

/// A type-erased Codable value for encoding/decoding arbitrary JSON structures.
enum AnyCodable: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyCodable])
    case array([AnyCodable])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let string = try? container.decode(String.self) { self = .string(string); return }
        if let int = try? container.decode(Int.self) { self = .int(int); return }
        if let double = try? container.decode(Double.self) { self = .double(double); return }
        if let bool = try? container.decode(Bool.self) { self = .bool(bool); return }
        if let array = try? container.decode([AnyCodable].self) { self = .array(array); return }
        if let object = try? container.decode([String: AnyCodable].self) { self = .object(object); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    var intValue: Int? { if case .int(let i) = self { return i } else { return nil } }
    var doubleValue: Double? { if case .double(let d) = self { return d } else { return nil } }
    var boolValue: Bool? { if case .bool(let b) = self { return b } else { return nil } }
    var objectValue: [String: AnyCodable]? { if case .object(let o) = self { return o } else { return nil } }
    var arrayValue: [AnyCodable]? { if case .array(let a) = self { return a } else { return nil } }

    subscript(_ key: String) -> AnyCodable? {
        objectValue?[key]
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .int(value) }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) { self = .double(value) }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, AnyCodable)...) {
        var dict: [String: AnyCodable] = [:]
        for (k, v) in elements { dict[k] = v }
        self = .object(dict)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: AnyCodable...) { self = .array(elements) }
}
