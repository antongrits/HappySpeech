import Foundation
import OSLog

// MARK: - DiaryStorage
//
// Атомарная запись / чтение шифрованных blob'ов под `Documents/SpeechGrowthDiary/`.
//
// Каждый клип = два файла:
//   • `<id>.bin`        — encrypted video bytes
//   • `<id>.thumb.bin`  — encrypted thumbnail bytes
//
// Storage не знает о шифровании — он работает с уже зашифрованными Data
// (вся криптография в DiaryEncryptionWorker).

actor DiaryStorage {

    private let folderName: String
    private let logger = Logger(
        subsystem: "ru.happyspeech", category: "Diary.Storage"
    )

    init(folderName: String = "SpeechGrowthDiary") {
        self.folderName = folderName
    }

    // MARK: - Paths

    func directory() throws -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "DiaryStorage",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No documents directory."])
        }
        let dir = docs.appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func clipURL(id: String) throws -> URL {
        try directory().appendingPathComponent("\(id).bin")
    }

    func thumbnailURL(id: String) throws -> URL {
        try directory().appendingPathComponent("\(id).thumb.bin")
    }

    // MARK: - Read / Write

    /// Возвращает относительный путь от Documents/ (для хранения в Realm).
    func writeEncryptedClip(_ data: Data, id: String) throws -> String {
        let url = try clipURL(id: id)
        try data.write(to: url, options: [.atomic])
        return "\(folderName)/\(id).bin"
    }

    func writeEncryptedThumbnail(_ data: Data, id: String) throws -> String {
        let url = try thumbnailURL(id: id)
        try data.write(to: url, options: [.atomic])
        return "\(folderName)/\(id).thumb.bin"
    }

    func readEncryptedClip(id: String) throws -> Data {
        let url = try clipURL(id: id)
        return try Data(contentsOf: url)
    }

    func readEncryptedThumbnail(id: String) throws -> Data {
        let url = try thumbnailURL(id: id)
        return try Data(contentsOf: url)
    }

    /// Удаляет файлы клипа. Игнорирует отсутствующие.
    func deleteClipFiles(id: String) throws {
        let fm = FileManager.default
        if let clip = try? clipURL(id: id), fm.fileExists(atPath: clip.path) {
            try fm.removeItem(at: clip)
        }
        if let thumb = try? thumbnailURL(id: id), fm.fileExists(atPath: thumb.path) {
            try fm.removeItem(at: thumb)
        }
    }
}
