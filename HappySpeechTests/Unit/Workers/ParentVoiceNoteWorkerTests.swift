@testable import HappySpeech
import Foundation
import XCTest

// MARK: - ParentVoiceNoteWorkerTests
//
// Фаза E, Волна 8. ParentVoiceNoteWorker — ТОНКАЯ обёртка над RealmActor
// (fetch/save/delete/setEnabled) + файловой системой Documents + AVAudioPlayer
// (playback). Бизнес-логики выбора/скоринга здесь нет. Покрываем доступную
// безопасную часть — валидацию входа и безопасные no-op:
//  • fetchClips/activeClip для несуществующего ребёнка → пусто/nil;
//  • deleteClip несуществующей записи → false (нет файла, нет записи);
//  • play с несуществующим файлом → безопасный no-op (ранняя проверка
//    FileManager.fileExists), без падения;
//  • stopPlayback без активного плеера → безопасно.
// saveClip/persistTempFile (перемещение файла + запись в Realm) и реальное
// воспроизведение в unit-тестах не запускаются — это hardware/IO side.

@MainActor
final class ParentVoiceNoteWorkerTests: XCTestCase {

    private func makeSUT() -> ParentVoiceNoteWorker {
        ParentVoiceNoteWorker(realmActor: RealmActor())
    }

    private func clip(
        id: String = "clip-\(UUID().uuidString)",
        fileURL: String
    ) -> ParentVoiceClipData {
        ParentVoiceClipData(
            id: id,
            childId: "c-1",
            lessonTemplate: "repeat-after-model",
            fileURL: fileURL,
            durationSec: 1.0,
            recordedAt: Date(),
            isEnabled: true
        )
    }

    // MARK: - Fetch / active for unknown child

    func test_fetchClips_unknownChild_returnsEmpty() async {
        let sut = makeSUT()
        let clips = await sut.fetchClips(childId: "no-such-child-\(UUID().uuidString)")
        XCTAssertTrue(clips.isEmpty)
    }

    func test_activeClip_unknownChild_returnsNil() async {
        let sut = makeSUT()
        let active = await sut.activeClip(
            childId: "no-such-child-\(UUID().uuidString)",
            lessonTemplate: "repeat-after-model"
        )
        XCTAssertNil(active)
    }

    // MARK: - Delete non-existent clip

    func test_deleteClip_nonExistent_returnsFalse() async {
        // Нет файла на диске и нет записи в Realm → обе ветки дают false.
        let sut = makeSUT()
        let nonExistent = clip(fileURL: "ParentVoiceNotes/does-not-exist-\(UUID().uuidString).m4a")
        let removed = await sut.deleteClip(nonExistent)
        XCTAssertFalse(removed)
    }

    // MARK: - Playback safe no-op

    func test_play_missingFile_isSafeNoOp() async {
        // Файл не существует → ранняя проверка fileExists возвращает без
        // создания AVAudioPlayer. Тест подтверждает отсутствие падения.
        let sut = makeSUT()
        let missing = clip(fileURL: "ParentVoiceNotes/missing-\(UUID().uuidString).m4a")
        await sut.play(missing)
        sut.stopPlayback()
    }

    func test_stopPlayback_withoutActivePlayer_isSafe() {
        let sut = makeSUT()
        sut.stopPlayback() // без падения
        sut.stopPlayback()
    }

    // MARK: - setEnabledForChild on empty child is a safe no-op

    func test_setEnabledForChild_unknownChild_isSafe() async {
        let sut = makeSUT()
        await sut.setEnabledForChild("no-such-child-\(UUID().uuidString)", isEnabled: false)
        // Нет записей — операция завершается без эффекта и без падения.
    }
}
