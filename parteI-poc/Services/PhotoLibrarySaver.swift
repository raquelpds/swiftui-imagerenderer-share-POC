//
//  PhotoLibrarySaver.swift
//  parteI-poc
//
//  Created by Raquel Souza on 08/10/26.
//


import Photos
import UIKit

enum PhotoLibrarySaver {
    enum SaveError: Error { case permissionDenied }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}