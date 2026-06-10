import XCTest
import SceneKit
import Metal
@testable import HappySpeech

/// Render-харнесс (НЕ строгий тест): рендерит реальную сцену `ArticulationScene3DView`
/// через offscreen `SCNRenderer` в PNG, чтобы оркестратор видел вид 3D-модели без
/// прохождения онбординга/навигации. Сохраняет кадры в /tmp/sim/ для каждого звука.
/// Запуск: `-only-testing:HappySpeechTests/Articulation3DRenderTest`.
@MainActor
final class Articulation3DRenderTest: XCTestCase {

    func testRenderArticulationPoses() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device (CI without GPU)")
        }
        let sounds: [(ArticulationSound, String)] = [
            (.r, "r"), (.sh, "sh"), (.s, "s"), (.soundL, "l")
        ]
        let outDir = "/tmp/sim"
        try? FileManager.default.createDirectory(
            atPath: outDir, withIntermediateDirectories: true
        )
        for (sound, slug) in sounds {
            let view = ArticulationScene3DView(sound: sound, reduceMotion: true)
            let coord = view.makeCoordinator()
            let scene = coord.makeScene()
            coord.apply(sound: sound, animated: false, reduceMotion: true)

            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene
            renderer.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: true)

            let image = renderer.snapshot(
                atTime: 0,
                with: CGSize(width: 760, height: 570),
                antialiasingMode: .multisampling4X
            )
            if let data = image.pngData() {
                let path = "\(outDir)/artic3d_\(slug).png"
                try data.write(to: URL(fileURLWithPath: path))
            }
            XCTAssertGreaterThan(image.size.width, 0)
        }
    }
}
