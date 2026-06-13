import SwiftUI
import XCTest
@testable import HappySpeech

// MARK: - BackgroundRedesignSnapshotTests
//
// РЕДИЗАЙН Волна A (2026-06-13): `HSMeshGradientBackground` переведён с
// многоцветного mesh-градиента (коралл + лиловый + мятный смешивались в
// «радугу») на спокойный, практически ОДНОТОННЫЙ тёплый фон в стиле
// референсов open-design (light ≈ кремовый #FFF8F0, dark — тёмный
// нейтрально-тёплый).
//
// Эти smoke-тесты НЕ сравнивают с pixel-эталоном (фон по дизайну почти
// однотонный — pixel-вариация мала). Вместо этого они проверяют ИНВАРИАНТЫ
// нового фона:
//   1. кадр рендерится (не пустой, есть cgImage);
//   2. фон ТЁПЛЫЙ — красный канал ≥ синего (никакого зелёного/синего фона);
//   3. фон ПОЧТИ ОДНОТОННЫЙ — низкая яркостная вариация (нет радуги/полос).
@MainActor
final class BackgroundRedesignSnapshotTests: XCTestCase {

    private let size = CGSize(width: 375, height: 667)

    func testKidWarmLightIsWarmAndNearMonotone() {
        assertWarmMonotone(palette: .kidWarm, style: .light, label: "kidWarm-light")
    }

    func testKidWarmDarkRenders() {
        assertWarmMonotone(palette: .kidWarmDark, style: .dark, label: "kidWarmDark-dark", checkWarm: false)
    }

    func testKidCoolLightIsWarmNotCool() {
        // .kidCool раньше тянул в лилово-розовый mesh — теперь тёплый кремовый.
        assertWarmMonotone(palette: .kidCool, style: .light, label: "kidCool-light")
    }

    func testRewardsLightIsWarmAndNearMonotone() {
        assertWarmMonotone(palette: .rewards, style: .light, label: "rewards-light")
    }

    func testCalmLightIsWarmAndNearMonotone() {
        assertWarmMonotone(palette: .calm, style: .light, label: "calm-light")
    }

    func testKidWarmRendersInDark() {
        assertWarmMonotone(palette: .kidWarm, style: .dark, label: "kidWarm-dark", checkWarm: false)
    }

    // MARK: - Helper

    private func assertWarmMonotone(
        palette: HSMeshGradientBackground.Palette,
        style: UIUserInterfaceStyle,
        label: String,
        checkWarm: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let view = HSMeshGradientBackground(palette: palette)
        let image = SnapshotTestHelper.renderView(view, size: size, style: style)
        guard let cgImage = image.cgImage else {
            XCTFail("Фон не отрендерился: \(label)", file: file, line: line)
            return
        }

        let dim = 32
        let bytesPerPixel = 4
        let bytesPerRow = dim * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: dim * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer, width: dim, height: dim,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("CGContext не создан: \(label)", file: file, line: line)
            return
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: dim, height: dim))

        var sumR = 0, sumG = 0, sumB = 0
        var minLum = 255, maxLum = 0
        var count = 0
        for pixel in stride(from: 0, to: buffer.count, by: bytesPerPixel) {
            let r = Int(buffer[pixel])
            let g = Int(buffer[pixel + 1])
            let b = Int(buffer[pixel + 2])
            sumR += r; sumG += g; sumB += b
            let lum = (r + g + b) / 3
            if lum < minLum { minLum = lum }
            if lum > maxLum { maxLum = lum }
            count += 1
        }
        XCTAssertGreaterThan(count, 0, "Нет пикселей: \(label)", file: file, line: line)
        let avgR = sumR / count, avgB = sumB / count

        // Тёплый фон: красный канал не темнее синего (никакого синего/зелёного фона).
        if checkWarm {
            XCTAssertGreaterThanOrEqual(
                avgR, avgB,
                "Фон не тёплый (R<B) — возможен синий/зелёный оттенок: \(label) R=\(avgR) B=\(avgB)",
                file: file, line: line
            )
        }

        // Почти однотонный: яркостная вариация мала — нет «радуги»/резких полос.
        XCTAssertLessThan(
            maxLum - minLum, 60,
            "Фон не однотонный (большая яркостная вариация — возможно смешивание цветов): \(label) variance=\(maxLum - minLum)",
            file: file, line: line
        )
    }
}
