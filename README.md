# ImageRendererPOC

POC em SwiftUI que transforma os dados de uma atividade concluída em uma imagem (`UIImage`) usando o `ImageRenderer`, e a compartilha pelo share sheet do iOS. O projeto segue a arquitetura **VIP** (View → Interactor → Presenter).

<!-- Adicione aqui um print do app: ![Card gerado](docs/card.png) -->

## O que o app faz

1. Mostra uma tela com os botões **Tirar foto** e **Gerar imagem**.
2. Gera um card de **1080×1920 px** (formato Stories) com título, tempo, pontos e desafios da atividade.
3. Usa como fundo a **foto tirada pela câmera**; sem foto, usa uma imagem padrão do Assets.
4. Com a imagem gerada, permite **Compartilhar** (share sheet do sistema) e **Salvar na galeria**.

Os dados da atividade são fictícios (`MockActivityWorker`).

## Requisitos

- Xcode com suporte a iOS 16 ou superior (`ImageRenderer` exige iOS 16+)
- iPhone real para testar a câmera (o simulador não tem câmera; nele o botão **Tirar foto** fica desativado)
- Uma imagem chamada `defaultBackground` no `Assets.xcassets`, usada quando não há foto

### Permissões (Info do target)

| Chave | Uso |
|---|---|
| `NSCameraUsageDescription` | Abrir a câmera |
| `NSPhotoLibraryAddUsageDescription` | Salvar a imagem na galeria |

O share sheet padrão não precisa de permissão.

## Como funciona

```
Toque em "Gerar imagem"
  → ActivityShareStore (View)
  → ActivityShareInteractor
  → ActivitySharePresenter (formata "25:43", "12 desafios", escolhe o fundo)
  → ActivityShareStore.displayActivity
  → ShareImageRenderer (ImageRenderer)
  → UIImage exibida na tela
```

O card é desenhado em 360×640 pt e renderizado com `scale = 3`, resultando em 1080×1920 px. A aparência é fixa (fontes com tamanho fixo e `colorScheme` claro), para a imagem sair igual em qualquer aparelho. O `print` no console mostra `size`, `scale` e os pixels finais.

## Estrutura de pastas

```
ImageRendererPOC/
├── App/                      Ponto de entrada (@main)
├── Scenes/
│   └── ActivityShare/        Cena VIP
│       ├── ActivityShareModels.swift
│       ├── ActivityShareInteractor.swift
│       ├── ActivitySharePresenter.swift
│       ├── ActivityShareConfigurator.swift
│       └── View/
│           ├── ActivityShareView.swift       Tela + Store
│           ├── ActivityShareCardView.swift   Template que vira imagem
│           ├── ActivityShareSheet.swift      Ponte com UIActivityViewController
│           └── CameraPicker.swift            Ponte com UIImagePickerController
├── Workers/                  ActivityWorker (dados fictícios)
├── Entities/                 ActivitySummary, ActivityShareDraft
└── Services/                 ShareImageRenderer, ShareService, PhotoLibrarySaver
```

## Para estudar

Este repositório nasceu de uma pesquisa (CBL) sobre:

- como gerar uma imagem dinamicamente a partir de uma View SwiftUI (`ImageRenderer`, `proposedSize`, `scale`);
- como compartilhar uma `UIImage` com outros apps (`UIActivityViewController`);
- como encaixar tudo na arquitetura VIP em SwiftUI.


