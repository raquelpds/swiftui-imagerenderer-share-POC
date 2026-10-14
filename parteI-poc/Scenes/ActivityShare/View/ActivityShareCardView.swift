import SwiftUI

// MARK: - Template (Scenes/ActivityShare/View/ActivityShareCardView.swift)
struct ActivityShareCardView: View {
    let viewModel: ActivityCardViewModel

    private let size = ShareImageSpec.pointSize

    var body: some View {
        ZStack {
            background
                .frame(width: size.width, height: size.height)
                .clipped()

            Color.black.opacity(0.3)   // garante contraste do texto sobre qualquer foto

            VStack(spacing: 24) {
                Text(viewModel.title)
                    .font(.system(size: 22, weight: .bold)) // tamanho fixo: ignora Dynamic Type
                    .tracking(2)

                Text(viewModel.timeText)
                    .font(.system(size: 80, weight: .heavy, design: .rounded))

                VStack(spacing: 8) {
                    Text(viewModel.challengesText)
                    Text(viewModel.scoreText)
                }
                .font(.system(size: 24, weight: .semibold))

                Spacer().frame(height: 40)

                Text(viewModel.appName)
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .light) // fixa a aparência (independe do dark mode)
    }

    // Desenha o fundo conforme a origem (imagem padrão ou foto do usuário)
    @ViewBuilder
    private var background: some View {
        switch viewModel.background {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}
