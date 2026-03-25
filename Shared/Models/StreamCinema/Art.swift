//
//  Art.swift
//  BartTV
//
//  Created by Vladimír Bárta on 22.02.2026.
//

struct Art: Codable, Hashable {
    let banner: String?
    let fanart: String?
    let clearlogo: String?
    let poster: String?
    let thumb: String?
    let clearart: String?
    let icon: String?
}

extension Art {
    static let preview1 = Art(
        banner: nil,
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/nEuYv9Tihw8pZrZufyhzNE2jRB.jpg",
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/g7gNjaRCkwgd3d6OpC4cRpkolh7.jpg",
        thumb: nil,
        clearart: nil,
        icon: nil
    )
    static let preview2 = Art(
        banner: nil,
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/gbAcTyVtPfzCBs58xs6NYKHiPCp.jpg",
        clearlogo: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/gbAcTyVtPfzCBs58xs6NYKHiPCp.jpg",
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/6LjiXXepZPvnQmrgV1pUh4kRFw1.jpg",
        thumb: nil,
        clearart: nil,
        icon: nil
    )
    static let preview3 = Art(
        banner: nil,
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/uDPNsFzBeAjGve3xyo30V7FfqsL.jpg",
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/AkbvUWonOMP8vQhG9n46rVeEEFH.jpg",
        thumb: nil,
        clearart: nil,
        icon: nil
    )
    static let preview4 = Art(
        banner: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/assets.fanart.tv/fanart/predator-badlands-68cbfd6779067.jpg",
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/ebyxeBh56QNXxSJgTnmz7fXAlwk.jpg",
        clearlogo: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/assets.fanart.tv/fanart/predator-badlands-680e975871e59.png",
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/image.tmdb.org/t/p/original/ef2QSeBkrYhAdfsWGXmp0lvH0T1.jpg",
        thumb: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/assets.fanart.tv/fanart/predator-badlands-687f317019283.jpg",
        clearart: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/assets.fanart.tv/fanart/predator-badlands-684b4be98fc3b.png",
        icon: nil        
    )

    static let previewTvShow1 = Art(
        banner: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/460989/banners/69a38c036e508.jpg",
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/460989/backgrounds/697fc36d70aa2.jpg",
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/460989/posters/697fc55107596.jpg",
        thumb: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/episode/11002626/screencap/697bf9351579e.jpg",
        clearart: nil,
        icon: nil
    )
    static let previewTvShow2 = Art(
        banner: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/463433/banners/694a22be5ca55.jpg",
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/463433/backgrounds/699f37f105a61.jpg",
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/463433/posters/6951a85c3c422.jpg",
        thumb: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/episode/11253165/screencap/6997748931767.jpg",
        clearart: nil,
        icon: nil
    )
    static let previewTvShow3 = Art(
        banner: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/450633/banners/697d3f00d5613.jpg",
        fanart : "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/450633/backgrounds/694484223f38c.jpg",
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/450633/posters/698506419a288.jpg",
        thumb: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/episode/11514315/screencap/69a7e92166fec.jpg",
        clearart: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/assets.fanart.tv/fanart/young-sherlock-69950fe2cef00.png",
        icon: nil
    )
    static let previewTvShow4 = Art(
        banner: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/465305/banners/69a0b5ea03a68.jpg",
        fanart : nil,
        clearlogo: nil,
        poster: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/series/465305/posters/69a01da3a79b1.jpg",
        thumb: "https://img.stream-cinema.online/unsafe/fit-in/800x800/smart/filters:no_upscale():quality(40)/thetvdb.com/banners/v4/episode/11642793/screencap/69a1532d8cbce.jpg",
        clearart: nil,
        icon: nil
    )
    
}
