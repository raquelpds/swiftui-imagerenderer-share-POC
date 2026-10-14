//
//  ActivityShareDraft.swift
//  parteI-poc
//
//  Created by Raquel Souza on 14/10/26.
//


import Foundation

// MARK: - Estado compartilhado do fluxo
// (Entities/ActivityShareDraft.swift)
// Guarda o que o usuário foi gerando ao longo das telas:
// atividade concluída -> sentimento -> foto -> card.
// É uma classe (tipo referência) para que todas as cenas enxerguem o MESMO objeto.
@MainActor
final class ActivityShareDraft {
    var activity: ActivitySummary
    var feeling: String?       // ainda não usado no card; preenchido pela cena de sentimento
    var photoData: Data?       // preenchido pela foto da câmera

    init(activity: ActivitySummary, feeling: String? = nil, photoData: Data? = nil) {
        self.activity = activity
        self.feeling = feeling
        self.photoData = photoData
    }
}