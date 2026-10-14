import UIKit

// MARK: - Scene Models (Scenes/ActivityShare/ActivityShareModels.swift)
enum ActivityShare {

    // Caso de uso: carregar a atividade e montar o card
    enum LoadActivity {
        struct Request {}

        // Interactor -> Presenter (dados de negócio)
        struct Response {
            let activity: ActivitySummary
            let backgroundImageData: Data?   // foto da câmera, se existir
        }

        // Presenter -> View (dados prontos para exibir)
        struct ViewModel {
            let card: ActivityCardViewModel
        }
    }

    // Caso de uso: o usuário tirou a foto de fundo
    enum SelectBackground {
        struct Request {
            let imageData: Data
        }
    }
}

// De onde vem o fundo do card
enum BackgroundSource: Equatable {
    case asset(String)     // imagem padrão do Assets
    case loaded(UIImage)   // foto tirada pelo usuário
}

// Texto já formatado + fundo: é isso que o template SwiftUI consome
struct ActivityCardViewModel: Equatable {
    let title: String
    let timeText: String
    let scoreText: String
    let challengesText: String
    let appName: String
    let background: BackgroundSource
}
