//
//  ParteIPocApp.swift
//  parteI-poc
//
//  Created by Raquel Souza on 07/10/26.
//

import SwiftUI

@main
struct ParteIPocApp: App {
    // Criado uma vez só, para o estado não ser recriado quando o SwiftUI reavalia o body
    private let draft: ActivityShareDraft

    init() {
        // Último mock que sobra: simula a atividade que acabou de terminar.
        // Quando existir a tela anterior, é ela que cria o Draft.
        draft = ActivityShareDraft(
            activity: MockActivityWorker().fetchLastActivity()
        )
    }

    var body: some Scene {
        WindowGroup {
            ActivityShareConfigurator.makeView(draft: draft)
        }
    }
}
