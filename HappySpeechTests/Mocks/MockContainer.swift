import Foundation
@testable import HappySpeech

// MARK: - Test Helpers

extension AppContainer {
    /// Returns a container configured for tests with all mock services.
    static func test() -> AppContainer {
        preview()
    }
}

// MARK: - Test Child Profile

extension ChildProfileDTO {
    static func testProfile(
        id: String = "test-child-\(Int.random(in: 1000...9999))",
        name: String = "Тест",
        age: Int = 6,
        sounds: [String] = ["Р"]
    ) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: age,
            targetSounds: sounds,
            parentId: "test-parent-1"
        )
    }
}
