import SwiftUI
import ARKit
import RealityKit

// MARK: - ARZoneView

/// AR Zone entry — hosts face tracking exercises.
struct ARZoneView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedScenario: ARScenario = .mirror

    var body: some View {
        NavigationStack {
            List(ARScenario.allCases, id: \.self) { scenario in
                NavigationLink(value: scenario) {
                    ARScenarioRow(scenario: scenario)
                }
            }
            .navigationTitle("AR-упражнения")
            .navigationDestination(for: ARScenario.self) { scenario in
                ARSessionView(scenario: scenario)
            }
        }
    }
}

// MARK: - ARScenario

enum ARScenario: String, CaseIterable, Hashable {
    case mirror          = "ar-mirror"
    case butterfly       = "butterfly"
    case holdPose        = "hold-pose"
    case copyFace        = "copy-face"
    case breathing       = "breathing"
    case warmup          = "warmup"
    case readinessCheck  = "readiness-check"
    case threePoses      = "three-poses"
    case bestScores      = "best-scores"
    case results         = "ar-results"

    var displayName: String {
        switch self {
        case .mirror:         return "Зеркало"
        case .butterfly:      return "Бабочка"
        case .holdPose:       return "Удержи позу"
        case .copyFace:       return "Повтори лицо"
        case .breathing:      return "Дыхание"
        case .warmup:         return "Разминка"
        case .readinessCheck: return "Готовность"
        case .threePoses:     return "3 позы"
        case .bestScores:     return "Рекорды"
        case .results:        return "Результаты"
        }
    }

    var icon: String {
        switch self {
        case .mirror:         return "face.smiling"
        case .butterfly:      return "bird"
        case .holdPose:       return "stopwatch"
        case .copyFace:       return "person.fill.viewfinder"
        case .breathing:      return "lungs"
        case .warmup:         return "flame"
        case .readinessCheck: return "checkmark.shield"
        case .threePoses:     return "list.number"
        case .bestScores:     return "trophy"
        case .results:        return "chart.bar"
        }
    }
}

// MARK: - ARScenarioRow

private struct ARScenarioRow: View {
    let scenario: ARScenario

    var body: some View {
        HStack(spacing: SpacingTokens.medium) {
            Image(systemName: scenario.icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading) {
                Text(scenario.displayName)
                    .font(TypographyTokens.body())
            }
        }
        .padding(.vertical, SpacingTokens.small)
    }
}

// MARK: - ARSessionView (stub — ARKit integrated per scenario)

struct ARSessionView: View {
    let scenario: ARScenario
    @State private var isARSupported: Bool = ARFaceTrackingConfiguration.isSupported

    var body: some View {
        Group {
            if isARSupported {
                ARViewRepresentable(scenario: scenario)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        AROverlayBar(scenario: scenario)
                    }
            } else {
                ContentUnavailableView(
                    "AR недоступен",
                    systemImage: "arkit",
                    description: Text("Для AR-упражнений нужна камера TrueDepth (Face ID)")
                )
            }
        }
        .navigationTitle(scenario.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ARViewRepresentable

struct ARViewRepresentable: UIViewRepresentable {
    let scenario: ARScenario

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.automaticallyUpdatesLighting = true
        arView.delegate = context.coordinator
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        uiView.session.run(config, options: [.resetTracking])
    }

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator(scenario: scenario)
    }
}

// MARK: - ARCoordinator

final class ARCoordinator: NSObject, ARSCNViewDelegate {
    let scenario: ARScenario
    init(scenario: ARScenario) { self.scenario = scenario }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else { return nil }
        return SCNNode()
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // Per-scenario face tracking logic goes here
        _ = faceAnchor.blendShapes
    }
}

// MARK: - AROverlayBar

private struct AROverlayBar: View {
    let scenario: ARScenario
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
            Spacer()
            Text(scenario.displayName)
                .font(TypographyTokens.headline())
                .foregroundStyle(.white)
            Spacer()
        }
        .background(.ultraThinMaterial)
    }
}
