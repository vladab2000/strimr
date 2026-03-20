//
//  Video.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

struct Video: MediaItem, MediaInfo, Hashable {
    let id: String
    let name: String
    let type: String //= "video"
    let description: String?
    let url: String?
    let art: Art?
    let mediaType: String?
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let originalTitle: String?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
}

extension Video {
    static let preview1 = Video(
        id: "1",
        name: "Los aitas - [B]CZ, ES, ES+tit[/B] (2025)",
        type: "video",
        description: "In the late 1980s, in a working-class neighborhood on the outskirts of Bilbao, Basque Country, Spain. A girls' rhythmic gymnastics team has the opportunity to compete in a tournament in Berlin; but since the girls' mothers cannot take time off work, it is the fathers who must accompany them on the trip.",
        url: "/Play/m_jUX4kCmN98hj",
        art: Art.preview1,
        mediaType: "video",
        year: 2025,
        rating: 5.7,
        duration: 5115,
        langs: ["CZ", "ES", "ES+tit"],
        genres: ["Komedie"],
        originalTitle: "Los aitas"
    )
    static let preview2 = Video(
        id: "2",
        name: "LEGO Frozen: Operation Puffins - [B]CZ[/B] (2025)",
        type: "video",
        description: "Po událostech ve filmu Ledové království chtějí Anna s Elsou začít v Arendellu nový život a udělat si hrad trochu útulnějším. Zatímco se snaží vypořádat s tradicemi, které jim v tom brání, vévoda z Kravákova se jim pokusí jejich milovaný hrad ukrást pomocí hejna papuchalků.",
        url: "/Play/m_cC7w48yu4Df5",
        art: Art.preview2,
        mediaType: "video",
        year: 2025,
        rating: 4.5,
        duration: 967,
        langs: ["CZ"],
        genres: ["Animovaný", "Komedie", "Rodinný", "Fantasy", "Krátkometrážní"],
        originalTitle: "LEGO Frozen: Operation Puffins"
    )
    static let preview3 = Video(
        id: "3",
        name: "Neporazitelní - [B]CZ[/B] (2025)",
        type: "video",
        description: "Tři zcela odlišní hrdinové a jejich rodiny vezmou diváky na emocionální a zábavnou jízdu, při které s nadhledem řeší nelehké životní situace a s humorem bojují s nepřízní osudu, předsudky společnosti a zkostnatělým systémem.",
        url: "/Play/m_Pd2m65GFXC7R",
        art: Art.preview3,
        mediaType: "video",
        year: 2025,
        rating: 8,
        duration: 7114,
        langs: ["CZ"],
        genres: ["Drama"],
        originalTitle: "Neporazitelní"
    )
    static let preview4 = Video(
        id: "4",
        name: "Predátor: Nebezpečné území - [B]CZ, JA[/B] (2025)",
        type: "video",
        description: "Film se odehrává v budoucnosti na vzdálené planetě, kde mladý Predátor, vyhnaný ze svého klanu, najde nečekanou spojenkyni v syntetické robotické dívce jménem Thia a vydá se na zrádnou cestu za hledáním svého největšího nepřítele.",
        url: "/Play/m_A3Q7YWXMIyjY",
        art: Art.preview4,
        mediaType: "video",
        year: 2025,
        rating: 7.8,
        duration: 6480,
        langs: ["CZ", "JA"],
        genres: ["Komedie"],
        originalTitle: "Predátor: Nebezpečné území"
    )
}

