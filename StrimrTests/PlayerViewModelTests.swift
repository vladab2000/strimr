import Foundation
import Testing
@testable import Strimr_macOS

@MainActor
struct PlayerViewModelTests {
    private func makeViewModel() -> PlayerViewModel {
        PlayerViewModel(streamURL: URL(string: "https://example.com/video.mp4")!, sessionId: "", title: "Test")
    }

    private func play(_ viewModel: PlayerViewModel, at position: Double, duration: Double = 3600) {
        viewModel.handlePropertyChange(property: .duration, data: duration, isScrubbing: false)
        viewModel.handlePropertyChange(property: .timePos, data: position, isScrubbing: false)
    }

    @Test func failuresRecoverThenFail() {
        let viewModel = makeViewModel()
        viewModel.handleMediaLoaded()

        for attempt in 1...PlayerViewModel.maxRecoveryAttempts {
            viewModel.handlePlaybackFailed("chyba")
            #expect(viewModel.status == .recovering(attempt: attempt))
        }
        viewModel.handlePlaybackFailed("chyba")
        #expect(viewModel.status == .failed(message: "chyba"))
    }

    @Test func retryReloadsFromLastPosition() {
        let viewModel = makeViewModel()
        var reloadedAt: Double??
        viewModel.onReload = { reloadedAt = $0 }

        viewModel.handleMediaLoaded()
        play(viewModel, at: 120)
        viewModel.retry()

        #expect(reloadedAt == .some(120))
        #expect(viewModel.resumePosition == 120)
    }

    @Test func liveStreamReloadsFromStart() {
        let viewModel = makeViewModel()
        viewModel.isLive = true
        var reloadedAt: Double?? = .none
        viewModel.onReload = { reloadedAt = $0 }

        viewModel.handleMediaLoaded()
        play(viewModel, at: 120)
        viewModel.retry()

        #expect(reloadedAt == .some(nil))
    }

    @Test func markedWatchedNearEndOnce() {
        let viewModel = makeViewModel()
        var marked = 0
        viewModel.onMarkWatched = { marked += 1 }

        play(viewModel, at: 3000)
        #expect(marked == 0)
        play(viewModel, at: 3500)
        play(viewModel, at: 3550)
        #expect(marked == 1)
    }

    @Test func titlesMarkerMarksWatched() {
        let viewModel = makeViewModel()
        viewModel.skipTitlesStart = 3000
        var marked = false
        viewModel.onMarkWatched = { marked = true }

        play(viewModel, at: 3001)
        #expect(marked)
    }

    @Test func playbackEndWithoutNextEpisodeCloses() {
        #expect(makeViewModel().handlePlaybackEnded() == false)
    }

    @Test func rememberTrackChoiceStoresLanguages() {
        let viewModel = makeViewModel()
        var saved: TrackChoice?
        viewModel.onTrackChoiceChanged = { saved = $0 }

        viewModel.rememberTrackChoice(audio: Fixtures.track(1, .audio, language: "eng"), subtitle: nil)
        #expect(saved == TrackChoice(audioLanguage: "en", subtitleLanguage: nil, subtitlesOff: true))
        #expect(viewModel.rememberedTracks == saved)
    }
}
