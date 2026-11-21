import SwiftUI

struct HeroImageView: View {
    let imageURL: URL?

    @State private var image: UIImage?
    @State private var failed = false

    /// Menší obrázek se přes celou plochu neroztahuje (AntikTV má u pořadů jen 158×210 px)
    private static let minFillWidth: CGFloat = 640

    var body: some View {
        Group {
            if let image {
                if Self.fills(image) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    poster(image)
                }
            } else if failed || imageURL == nil {
                placeholder
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: imageURL) { await load() }
    }

    /// Obrázek na šířku v dostatečném rozlišení vyplní plochu, jinak se ukáže jako plakát
    private static func fills(_ image: UIImage) -> Bool {
        let pixelWidth = image.size.width * image.scale
        return image.size.width >= image.size.height && pixelWidth >= minFillWidth
    }

    /// Malý obrázek / na výšku: rozmazaný na pozadí, ostrý jako plakát vpravo přes celou výšku hero.
    /// Bez GeometryReader — uvnitř maskované plochy hero se jeho obsah nevykreslil.
    private func poster(_ image: UIImage) -> some View {
        // Color.clear má velikost plochy hero — rozmazané pozadí ji přesahuje (scaledToFill), plakát se proto
        // zarovná k ploše, ne k pozadí (jinak by byl mimo obrazovku)
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .opacity(0.6)
            }
            .clipped()
            .overlay(alignment: .trailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: .infinity)
                    .shadow(radius: 20)
                    .padding(.trailing, 150)
            }
    }

    private func load() async {
        image = nil
        failed = false
        guard let imageURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard !Task.isCancelled else { return }
            if let loaded = UIImage(data: data) {
                image = loaded
            } else {
                failed = true
            }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.black.opacity(0.35)

            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("media.placeholder.noArtwork")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HeroMaskView: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.25),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom,
        )
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.25),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .trailing,
                endPoint: .leading,
            ),
        )
    }
}
