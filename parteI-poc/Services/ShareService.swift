//
//  ShareService.swift
//  parteI-poc
//
//  Created by Raquel Souza on 08/10/26.
//


import UIKit

// MARK: - Service (Services/ShareService.swift)
// Prepara a imagem para o share sheet. Não conhece SwiftUI nem a cena.
enum ShareService {

    // .image -> entrega a UIImage direto (o iOS decide o formato)
    // .file  -> entrega um PNG em arquivo temporário (formato e resolução garantidos)
    enum Mode {
        case image
        case file
    }

    enum ShareError: Error {
        case encodingFailed
    }

    static func activityItems(for image: UIImage, mode: Mode) throws -> [Any] {
        switch mode {
        case .image:
            return [image]
        case .file:
            return [try makeTemporaryPNG(from: image)]
        }
    }

    private static func makeTemporaryPNG(from image: UIImage, name: String = "atividade") throws -> URL {
        guard let data = image.pngData() else {
            throw ShareError.encodingFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")

        try data.write(to: url, options: .atomic)
        return url
    }
}
