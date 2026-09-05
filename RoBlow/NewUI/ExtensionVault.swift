import CryptoKit
import Foundation
import WebKit

enum NewUIVault {
    private static var cached: Pack?

    struct Pack: Codable {
        var files: [Item]

        struct Item: Codable {
            var name: String
            var kind: String
            var text: String
        }
    }

    static func install(into config: WKWebViewConfiguration) {
        guard let pack = load() else { return }
        let controller = config.userContentController
        for file in pack.files {
            switch file.kind {
            case "css":
                controller.addUserScript(WKUserScript(
                    source: cssScript(file.text),
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                ))
            case "js":
                controller.addUserScript(WKUserScript(
                    source: file.text,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                ))
            default:
                continue
            }
        }
    }

    static func load() -> Pack? {
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: "Contents", withExtension: "idx"),
              let blob = try? Data(contentsOf: url),
              let plain = try? NewUILock.open(blob),
              let pack = try? JSONDecoder().decode(Pack.self, from: plain)
        else {
            return nil
        }
        cached = pack
        return pack
    }

    private static func cssScript(_ css: String) -> String {
        let encoded = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return """
        (() => {
            const style = document.createElement("style");
            style.textContent = `\(encoded)`;
            document.documentElement.appendChild(style);
        })();
        """
    }
}

enum NewUILock {
    static let magic = Data([0x52, 0x4B, 0x53, 0x31])

    static func material() -> Data {
        let a: [UInt8] = [0x4C, 0x91, 0x2A, 0x77, 0x0E, 0xD3, 0x5B, 0x18, 0xC4, 0x6F, 0xA1, 0x29, 0x83, 0xF0, 0x3C, 0x5E]
        let b: [UInt8] = [0xE7, 0x14, 0x9B, 0x42, 0x68, 0xAD, 0x01, 0xDF, 0x33, 0x7A, 0xC8, 0x55, 0x90, 0x2E, 0xB6, 0x0C]
        let id = Array("com.goldknow.RoBlow".utf8)
        return Data((0..<32).map { i in
            a[i % a.count] &+ b[i % b.count] ^ id[i % id.count]
        })
    }

    static func open(_ blob: Data) throws -> Data {
        guard blob.starts(with: magic), blob.count > magic.count + 12 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let combined = blob.dropFirst(magic.count)
        return try AES.GCM.open(try AES.GCM.SealedBox(combined: Data(combined)), using: SymmetricKey(data: material()))
    }
}
