import Foundation

// MARK: - TongueTwisterArenaModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum TongueTwisterArenaModels {

    struct Twister: Identifiable, Hashable {
        let id: String
        let text: String
        let targetSound: String
    }

    struct ViewState: Equatable {
        var twisters: [Twister]
        var selected: Twister?
        var isRecording: Bool

        static let initial = ViewState(
            twisters: [
                Twister(id: "t1", text: "Шла Саша по шоссе и сосала сушку.", targetSound: "С/Ш"),
                Twister(id: "t2", text: "На дворе трава, на траве дрова.", targetSound: "Р"),
                Twister(id: "t3", text: "Ехал Грека через реку, видит Грека — в реке рак.", targetSound: "Р/К"),
                Twister(id: "t4", text: "От топота копыт пыль по полю летит.", targetSound: "Т/П"),
                Twister(id: "t5", text: "Карл у Клары украл кораллы, Клара у Карла украла кларнет.", targetSound: "Р/Л"),
                Twister(id: "t6", text: "Жук жужжит, шмель шумит, шершень шуршит.", targetSound: "Ж/Ш"),
                Twister(id: "t7", text: "Цапля цветик целовала, цапле цветик подарили.", targetSound: "Ц"),
                Twister(id: "t8", text: "Щёткой чищу я щенка, щекочу ему бока.", targetSound: "Щ/Ч")
            ],
            selected: nil,
            isRecording: false
        )
    }
}
