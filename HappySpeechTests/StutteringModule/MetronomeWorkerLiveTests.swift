@testable import HappySpeech
import XCTest

// MARK: - MetronomeWorkerLiveTests
//
// Phase 2.7 v25 — покрытие live-реализации MetronomeWorker.
// StutteringWorkerTests тестирует только MockMetronomeWorker; здесь покрывается
// реальный MetronomeWorker: запуск таймера, тик-замыкание, остановка, idempotency.

@MainActor
final class MetronomeWorkerLiveTests: XCTestCase {

    private var sut: MetronomeWorker!

    override func setUp() {
        super.setUp()
        sut = MetronomeWorker()
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }

    // MARK: - start / stop

    func test_start_doesNotCrash() {
        sut.start(bpm: 60) {}
        XCTAssertNoThrow(sut.stop())
    }

    func test_stop_withoutStart_doesNotCrash() {
        XCTAssertNoThrow(sut.stop())
    }

    func test_stop_calledTwice_isIdempotent() {
        sut.start(bpm: 90) {}
        sut.stop()
        XCTAssertNoThrow(sut.stop())
    }

    func test_start_calledTwice_restartsCleanly() {
        sut.start(bpm: 60) {}
        // Повторный start вызывает stop() внутри — не должно крашить.
        XCTAssertNoThrow(sut.start(bpm: 120) {})
        sut.stop()
    }

    // MARK: - BPM граничные значения

    func test_start_zeroBPM_clampedToOne_doesNotCrash() {
        // bpm = 0 → max(1, 0) = 1 → interval 60s, без краша / деления на ноль.
        XCTAssertNoThrow(sut.start(bpm: 0) {})
        sut.stop()
    }

    func test_start_highBPM_doesNotCrash() {
        XCTAssertNoThrow(sut.start(bpm: 240) {})
        sut.stop()
    }

    // MARK: - Тик-замыкание

    func test_start_firesTickWithinInterval() async {
        // BPM 600 → interval 0.1s. Ожидаем хотя бы один тик за ~0.4s.
        let expectation = expectation(description: "metronome tick")
        expectation.assertForOverFulfill = false
        sut.start(bpm: 600) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        sut.stop()
    }

    func test_stop_haltsTicks() async {
        let counter = TickCounter()
        sut.start(bpm: 600) {
            counter.increment()
        }
        // Ждём пару тиков, затем останавливаем.
        try? await Task.sleep(nanoseconds: 250_000_000)
        sut.stop()
        let countAtStop = counter.value
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(counter.value, countAtStop, "После stop() тиков быть не должно")
    }
}

// MARK: - TickCounter
//
// Потокобезопасный счётчик тиков для проверки остановки метронома.

private final class TickCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
