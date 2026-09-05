#!/usr/bin/env swift
import CryptoKit
import Foundation

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

    static func seal(_ plain: Data) throws -> Data {
        let box = try AES.GCM.seal(plain, using: SymmetricKey(data: material()))
        guard let combined = box.combined else {
            throw CocoaError(.fileWriteUnknown)
        }
        return magic + combined
    }
}

struct Pack: Codable {
    var files: [Item]

    struct Item: Codable {
        var name: String
        var kind: String
        var text: String
    }
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: seal-newui.swift <source-dir> <output-idx>\n".utf8))
    exit(2)
}

let source = URL(fileURLWithPath: args[1], isDirectory: true)
let output = URL(fileURLWithPath: args[2])
let fm = FileManager.default

guard let enumerator = fm.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
    FileHandle.standardError.write(Data("missing NewUI source\n".utf8))
    exit(1)
}

var items: [Pack.Item] = []
for case let file as URL in enumerator {
    guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
    let ext = file.pathExtension.lowercased()
    let kind: String
    switch ext {
    case "js": kind = "js"
    case "css": kind = "css"
    case "json", "txt", "html": kind = ext
    default: continue
    }
    let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    let name = file.path.replacingOccurrences(of: source.path + "/", with: "")
    items.append(Pack.Item(name: name, kind: kind, text: text))
}

items.sort { $0.name < $1.name }
let plain = try JSONEncoder().encode(Pack(files: items))
let sealed = try NewUILock.seal(plain)
try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try sealed.write(to: output, options: .atomic)
print("sealed \(items.count) files -> \(output.lastPathComponent)")
