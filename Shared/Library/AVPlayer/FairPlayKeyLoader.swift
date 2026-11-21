import AVFoundation
import Foundation
import OSLog

/// FairPlay pro AVPlayer (OnePlay / Axinom): aplikační certifikát a licence přes náš server, který k licenčnímu
/// požadavku přidá autorizaci poskytovatele (X-AxDRM-Message). Klíč z playlistu: skd://{id klíče}.
/// Funguje jen na skutečném zařízení — simulátor FairPlay nepodporuje.
nonisolated final class FairPlayKeyLoader: NSObject, AVContentKeySessionDelegate, @unchecked Sendable {
    private let session = AVContentKeySession(keySystem: .fairPlayStreaming)
    private let queue = DispatchQueue(label: "cz.strimr.fairplay")
    private let certificateURL: URL
    private let licenseURL: URL
    private var certificate: Data?
    private let log = Logger(subsystem: "Strimr", category: "FairPlay")

    /// Chyba získání klíče (zobrazí přehrávač) — volá se na hlavním vlákně
    var onError: (@MainActor (String) -> Void)?

    init(certificateURL: URL, licenseURL: URL) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        super.init()
        session.setDelegate(self, queue: queue)
    }

    func attach(_ asset: AVURLAsset) {
        session.addContentKeyRecipient(asset)
    }

    func invalidate() {
        session.setDelegate(nil, queue: nil)
    }

    // MARK: - AVContentKeySessionDelegate

    func contentKeySession(_: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        handle(keyRequest)
    }

    func contentKeySession(_: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        handle(keyRequest)
    }

    func contentKeySession(_: AVContentKeySession, contentKeyRequest _: AVContentKeyRequest, didFailWithError error: Error) {
        log.error("FairPlay key request failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Klíč

    private func handle(_ keyRequest: AVContentKeyRequest) {
        // Axinom: identifikátor obsahu pro SPC = id klíče z skd:// adresy
        guard let identifier = keyRequest.identifier as? String,
              let contentId = identifier.replacingOccurrences(of: "skd://", with: "").data(using: .utf8)
        else {
            fail(keyRequest, "Neplatný klíč FairPlay v playlistu.")
            return
        }

        loadCertificate { [weak self] certificate in
            guard let self else { return }
            guard let certificate else {
                fail(keyRequest, "Certifikát FairPlay se nepodařilo stáhnout.")
                return
            }
            keyRequest.makeStreamingContentKeyRequestData(
                forApp: certificate,
                contentIdentifier: contentId,
                options: [AVContentKeyRequestProtocolVersionsKey: [1]],
            ) { [weak self] spc, error in
                guard let self else { return }
                guard let spc else {
                    fail(keyRequest, "Požadavek na licenci FairPlay se nepodařilo vytvořit (\(error?.localizedDescription ?? "?")).")
                    return
                }
                requestLicense(spc: spc, for: keyRequest)
            }
        }
    }

    private func requestLicense(spc: Data, for keyRequest: AVContentKeyRequest) {
        var request = URLRequest(url: licenseURL)
        request.httpMethod = "POST"
        request.httpBody = spc
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard error == nil, status == 200, let ckc = data, !ckc.isEmpty else {
                log.error("FairPlay license HTTP \(status, privacy: .public): \(error?.localizedDescription ?? "", privacy: .public)")
                fail(keyRequest, "Licenci k přehrání se nepodařilo získat (HTTP \(status)).")
                return
            }
            queue.async {
                keyRequest.processContentKeyResponse(AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckc))
            }
        }.resume()
    }

    private func loadCertificate(_ completion: @escaping (Data?) -> Void) {
        queue.async { [self] in
            if let certificate {
                completion(certificate)
                return
            }
            URLSession.shared.dataTask(with: certificateURL) { [weak self] data, response, _ in
                guard let self else { return }
                let ok = (response as? HTTPURLResponse)?.statusCode == 200 && !(data?.isEmpty ?? true)
                queue.async {
                    if ok { self.certificate = data }
                    completion(ok ? data : nil)
                }
            }.resume()
        }
    }

    private func fail(_ keyRequest: AVContentKeyRequest, _ message: String) {
        log.error("\(message, privacy: .public)")
        queue.async {
            keyRequest.processContentKeyResponseError(NSError(
                domain: "FairPlay", code: 1, userInfo: [NSLocalizedDescriptionKey: message],
            ))
        }
        let onError = onError
        Task { @MainActor in onError?(message) }
    }
}
