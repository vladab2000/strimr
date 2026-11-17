import SwiftUI

@MainActor
struct SettingsPlaybackMacView: View {
    @Environment(SettingsManager.self) private var settingsManager

    private var viewModel: SettingsViewModel {
        SettingsViewModel(settingsManager: settingsManager)
    }

    var body: some View {
        List {
            Section {
                Toggle("settings.playback.autoPlayNext", isOn: viewModel.autoPlayNextBinding)

                Picker("settings.playback.rewind", selection: viewModel.rewindBinding) {
                    ForEach(viewModel.seekOptions, id: \.self) { seconds in
                        Text("settings.playback.seconds \(seconds)").tag(seconds)
                    }
                }

                Picker("settings.playback.fastForward", selection: viewModel.fastForwardBinding) {
                    ForEach(viewModel.seekOptions, id: \.self) { seconds in
                        Text("settings.playback.seconds \(seconds)").tag(seconds)
                    }
                }

                Picker("settings.playback.player", selection: viewModel.playerBinding) {
                    ForEach(viewModel.playerOptions) { player in
                        Text(LocalizedStringKey(player.localizationKey)).tag(player)
                    }
                }

                Picker("settings.playback.audioLanguage", selection: viewModel.preferredAudioLanguageBinding) {
                    ForEach(viewModel.audioLanguageOptions, id: \.self) { code in
                        Text(TrackLanguage.displayName(code)).tag(code)
                    }
                }

                Picker("settings.playback.subtitleLanguage", selection: viewModel.preferredSubtitleLanguageBinding) {
                    ForEach(viewModel.subtitleLanguageOptions, id: \.self) { code in
                        Text(TrackLanguage.displayName(code)).tag(code)
                    }
                }

                Picker("settings.playback.subtitleScale", selection: viewModel.subtitleScaleBinding) {
                    ForEach(viewModel.subtitleScaleOptions, id: \.self) { scale in
                        Text("settings.playback.scale \(scale)").tag(scale)
                    }
                }
            }
        }
        .navigationTitle("settings.playback.title")
    }
}
