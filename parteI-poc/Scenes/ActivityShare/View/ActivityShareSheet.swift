//
//  ActivityShareSheet.swift
//  parteI-poc
//
//  Created by Raquel Souza on 08/10/26.
//


import SwiftUI
import UIKit

// MARK: - Ponte SwiftUI <-> UIActivityViewController
// (Scenes/ActivityShare/View/ActivityShareSheet.swift)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: (Bool) -> Void = { _ in }   // true = concluiu, false = cancelou

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}