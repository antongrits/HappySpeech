@testable import HappySpeech
import CoreML
import XCTest

// MARK: - MLBundleTests
//
// Доказывает, что исправление загрузки моделей реально работает:
// MLBundle.compiledModelURL(name:) находит .mlmodelc в рантайм-бандле (хост-app),
// тогда как прежний Bundle.main.url(withExtension:"mlpackage") всегда возвращал nil.
//
// Тест-таргет использует BUNDLE_LOADER / TEST_HOST = HappySpeech.app,
// поэтому Bundle.main внутри тестов == бандл хост-приложения, где
// Xcode уже скомпилировал все .mlpackage в .mlmodelc.
//
// Модели, проверяемые ниже, соответствуют файлам в Resources/Models/:
//   PronunciationScorer_hissing / sonants / velar / whistling
//   RussianPhonemeClassifier
//   Wav2Vec2RuChild
//   EmotionDetection
//   SpeakerVerification
//   TonguePostureClassifier
//   SoundClassifier

final class MLBundleTests: XCTestCase {

    // MARK: - 1. Старый способ (.mlpackage) возвращает nil — доказательство проблемы

    func test_legacyMLPackage_returnsNil_forAllModels() {
        let modelNames = [
            "PronunciationScorer_hissing",
            "PronunciationScorer_sonants",
            "PronunciationScorer_velar",
            "PronunciationScorer_whistling",
            "RussianPhonemeClassifier",
            "Wav2Vec2RuChild",
            "EmotionDetection",
            "SpeakerVerification",
            "TonguePostureClassifier",
            "SoundClassifier"
        ]
        for name in modelNames {
            let url = Bundle.main.url(forResource: name, withExtension: "mlpackage")
            XCTAssertNil(url, "'\(name).mlpackage' не должен существовать в рантайм-бандле — Xcode компилирует в .mlmodelc")
        }
    }

    // MARK: - 2. MLBundle.compiledModelURL находит каждую модель (.mlmodelc)

    func test_compiledModelURL_pronunciationScorer_hissing() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "PronunciationScorer_hissing"),
            "PronunciationScorer_hissing.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_pronunciationScorer_sonants() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "PronunciationScorer_sonants"),
            "PronunciationScorer_sonants.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_pronunciationScorer_velar() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "PronunciationScorer_velar"),
            "PronunciationScorer_velar.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_pronunciationScorer_whistling() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "PronunciationScorer_whistling"),
            "PronunciationScorer_whistling.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_russianPhonemeClassifier() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "RussianPhonemeClassifier"),
            "RussianPhonemeClassifier.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_wav2Vec2RuChild() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "Wav2Vec2RuChild"),
            "Wav2Vec2RuChild.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_emotionDetection() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "EmotionDetection"),
            "EmotionDetection.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_speakerVerification() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "SpeakerVerification"),
            "SpeakerVerification.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_tonguePostureClassifier() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "TonguePostureClassifier"),
            "TonguePostureClassifier.mlmodelc должен быть в бандле"
        )
    }

    func test_compiledModelURL_soundClassifier() {
        XCTAssertNotNil(
            MLBundle.compiledModelURL(name: "SoundClassifier"),
            "SoundClassifier.mlmodelc должен быть в бандле"
        )
    }

    // MARK: - 3. Несуществующая модель возвращает nil (санити-чек)

    func test_compiledModelURL_nonexistent_returnsNil() {
        XCTAssertNil(
            MLBundle.compiledModelURL(name: "DoesNotExistModel"),
            "Несуществующая модель должна вернуть nil"
        )
    }

    // MARK: - 4. URL ведёт на .mlmodelc (расширение правильное)

    func test_compiledModelURL_extension_isMLModelC() {
        guard let url = MLBundle.compiledModelURL(name: "RussianPhonemeClassifier") else {
            XCTFail("RussianPhonemeClassifier.mlmodelc не найден — тест не может проверить расширение")
            return
        }
        XCTAssertEqual(url.pathExtension, "mlmodelc", "URL должен вести на .mlmodelc, не .mlpackage")
    }

    // MARK: - 5. Smoke-тест: RussianPhonemeClassifier реально инициализируется как MLModel

    func test_russianPhonemeClassifier_initializesWithoutThrow() throws {
        guard let url = MLBundle.compiledModelURL(name: "RussianPhonemeClassifier") else {
            XCTFail("RussianPhonemeClassifier.mlmodelc не найден в бандле")
            return
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        let model = try MLModel(contentsOf: url, configuration: config)
        XCTAssertNotNil(model, "MLModel должен инициализироваться из скомпилированного .mlmodelc")
    }

    // MARK: - 6. Smoke-тест: PronunciationScorer_hissing реально инициализируется как MLModel

    func test_pronunciationScorerHissing_initializesWithoutThrow() throws {
        guard let url = MLBundle.compiledModelURL(name: "PronunciationScorer_hissing") else {
            XCTFail("PronunciationScorer_hissing.mlmodelc не найден в бандле")
            return
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        let model = try MLModel(contentsOf: url, configuration: config)
        XCTAssertNotNil(model, "MLModel должен инициализироваться из скомпилированного .mlmodelc")
    }
}
