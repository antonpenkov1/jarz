import Foundation

/// Why a snapshot was taken; shown to the user in the restore list.
enum SnapshotKind: String, Codable {
    case deleteJar
    case importData
    case recalculateFood
    case restore
}

struct SnapshotInfo: Identifiable, Equatable {
    let id: String
    let date: Date
    let kind: SnapshotKind
    /// Free-form context, e.g. the deleted jar's name.
    let detail: String
}

/// Rolling set of full backups (the same JSON as Export data), written
/// automatically before destructive actions. Plain files, no SwiftData,
/// so it stays readable even if the store itself is in a bad state.
struct SnapshotStore {
    let directory: URL
    var limit = 5

    private struct Envelope: Codable {
        var kind: SnapshotKind
        var detail: String
        var createdAt: Date
        /// The export JSON, verbatim.
        var backup: Data
    }

    @discardableResult
    func save(backup: Data, kind: SnapshotKind, detail: String = "", date: Date = Date()) -> SnapshotInfo? {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = "\(Int(date.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        let envelope = Envelope(kind: kind, detail: detail, createdAt: date, backup: backup)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(envelope),
              (try? data.write(to: url(for: id), options: .atomic)) != nil else { return nil }
        prune()
        return SnapshotInfo(id: id, date: date, kind: kind, detail: detail)
    }

    /// Newest first.
    func list() -> [SnapshotInfo] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { file -> SnapshotInfo? in
                guard let envelope = read(file) else { return nil }
                return SnapshotInfo(id: file.deletingPathExtension().lastPathComponent,
                                    date: envelope.createdAt, kind: envelope.kind,
                                    detail: envelope.detail)
            }
            .sorted { $0.date > $1.date }
    }

    func backup(id: String) -> Data? {
        read(url(for: id))?.backup
    }

    private func prune() {
        for stale in list().dropFirst(limit) {
            try? FileManager.default.removeItem(at: url(for: stale.id))
        }
    }

    private func read(_ file: URL) -> Envelope? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Envelope.self, from: data)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("json")
    }
}
