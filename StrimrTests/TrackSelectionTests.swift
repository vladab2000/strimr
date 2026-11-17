import Testing
@testable import Strimr_macOS

@MainActor
struct TrackLanguageTests {
    @Test(arguments: [
        ("cze", "cs"), ("CES", "cs"), ("cz", "cs"), ("Čeština", "cs"),
        ("slk", "sk"), ("slo", "sk"), ("eng", "en"), ("English", "en"),
    ])
    func normalizesKnownCodes(raw: String, expected: String) {
        #expect(TrackLanguage.normalize(raw) == expected)
    }

    @Test func unknownCodeIsNil() {
        #expect(TrackLanguage.normalize("ger") == nil)
        #expect(TrackLanguage.normalize("") == nil)
        #expect(TrackLanguage.normalize(nil) == nil)
    }

    @Test func languageFromTitleWhenCodeMissing() {
        #expect(TrackLanguage.of(Fixtures.track(1, .subtitle, title: "CZ titulky")) == "cs")
        #expect(TrackLanguage.of(Fixtures.track(2, .subtitle, title: "English (SDH)")) == "en")
        #expect(TrackLanguage.of(Fixtures.track(3, .audio, language: "slk", title: "English")) == "sk")
        #expect(TrackLanguage.of(Fixtures.track(4, .audio, title: "Stereo")) == nil)
    }
}

@MainActor
struct TrackSelectionTests {
    let tracks = [
        Fixtures.track(1, .audio, language: "eng"),
        Fixtures.track(2, .audio, language: "cze"),
        Fixtures.track(3, .subtitle, language: "eng"),
        Fixtures.track(4, .subtitle, language: "cze"),
    ]

    @Test func preferredAudioFoundTurnsSubtitlesOff() {
        let selection = TrackSelection.resolve(tracks: tracks, remembered: nil, preferredAudio: "cs", preferredSubtitle: "cs")
        #expect(selection.audioID == 2)
        #expect(selection.subtitle == .off)
    }

    @Test func missingPreferredAudioSelectsPreferredSubtitles() {
        let englishOnly = tracks.filter { $0.id != 2 }
        let selection = TrackSelection.resolve(tracks: englishOnly, remembered: nil, preferredAudio: "cs", preferredSubtitle: "cs")
        #expect(selection.audioID == nil)
        #expect(selection.subtitle == .track(4))
    }

    @Test func emptyPreferencesKeepTracks() {
        let selection = TrackSelection.resolve(tracks: tracks, remembered: nil, preferredAudio: "", preferredSubtitle: "")
        #expect(selection == TrackSelection())
    }

    @Test func subtitlesOffPreference() {
        let selection = TrackSelection.resolve(tracks: tracks, remembered: nil, preferredAudio: "", preferredSubtitle: "off")
        #expect(selection.subtitle == .off)
    }

    @Test func rememberedChoiceWinsOverSettings() {
        let remembered = TrackChoice(audioLanguage: "en", subtitleLanguage: "cs")
        let selection = TrackSelection.resolve(tracks: tracks, remembered: remembered, preferredAudio: "cs", preferredSubtitle: "cs")
        #expect(selection.audioID == 1)
        #expect(selection.subtitle == .track(4))
    }

    @Test func rememberedSubtitlesOff() {
        let remembered = TrackChoice(audioLanguage: "en", subtitleLanguage: nil, subtitlesOff: true)
        let selection = TrackSelection.resolve(tracks: tracks, remembered: remembered, preferredAudio: "cs", preferredSubtitle: "cs")
        #expect(selection.subtitle == .off)
    }

    @Test func rememberedLanguageMissingKeepsTrack() {
        let remembered = TrackChoice(audioLanguage: "sk", subtitleLanguage: "sk")
        let selection = TrackSelection.resolve(tracks: tracks, remembered: remembered, preferredAudio: "cs", preferredSubtitle: "cs")
        #expect(selection.audioID == nil)
        #expect(selection.subtitle == .keep)
    }
}
