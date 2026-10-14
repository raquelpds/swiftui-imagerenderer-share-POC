import SwiftUI

// MARK: - Especificação da imagem
// Desenhamos em 360x640 pt e renderizamos com scale 3 => 1080x1920 px (Stories)
enum ShareImageSpec {
    static let pointSize = CGSize(width: 360, height: 640)
    static let scale: CGFloat = 3
}

// MARK: - Serviço de renderização (View -> UIImage)
@MainActor
enum ShareImageRenderer {
    static func render<Content: View>(
        _ content: Content,
        size: CGSize = ShareImageSpec.pointSize,
        scale: CGFloat = ShareImageSpec.scale
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: content.frame(width: size.width, height: size.height)
        )
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        return renderer.uiImage // nil se falhar
    }
}
