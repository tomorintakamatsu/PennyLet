import Foundation

actor CacheService {
    static let shared = CacheService()

    private let cacheDir: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("PennyLet/Cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func cache<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: cacheDir.appendingPathComponent("\(key).json"), options: .atomic)
    }

    func load<T: Decodable>(forKey key: String) -> T? {
        let url = cacheDir.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func clear(key: String) {
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("\(key).json"))
    }
}
