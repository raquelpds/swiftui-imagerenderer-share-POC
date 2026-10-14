# Arquitetura — POC: ShareImageRenderer

Este documento descreve **como o código atual funciona**. 

---

## 1. Visão geral

O app é uma POC (prova de conceito) para iOS (deployment target 26.5) que **transforma uma View SwiftUI em imagem** e permite compartilhá-la ou salvá-la.

Hoje o app tem **uma única tela** (cena `ActivityShare`), que:

1. Exibe os botões **"Tirar foto"** e **"Gerar imagem"**.
2. **Tirar foto**: abre a câmera do iPhone (`UIImagePickerController`). A foto vira o fundo do card. Em dispositivos sem câmera (ex.: Simulador), o botão fica desabilitado e aparece um aviso.
3. **Gerar imagem**: monta um card com os dados de uma atividade *mockada* (título, tempo, pontos, desafios e nome do app) e renderiza esse card como `UIImage` de **1080 × 1920 px** (formato Stories).
4. Depois que a imagem é gerada, ela aparece na tela com dois botões:
   - **Compartilhar**: abre o share sheet do sistema (`UIActivityViewController`) com a imagem em um arquivo PNG temporário.
   - **Salvar na galeria**: pede permissão de "somente adicionar" fotos e salva a imagem no app Fotos.
5. Mensagens de feedback simples aparecem abaixo dos botões ("Imagem salva na galeria.", "Imagem compartilhada.", mensagens de erro).

Os dados da atividade vêm do `MockActivityWorker` (valores fixos: "Atividade X", 25:43, 850 pontos, 12 desafios).

---

## 2. Estrutura de pastas

```
parteI-poc/                                  (raiz do repositório)
├── ParteIPocApp.swift                       ← ponto de entrada (@main)
├── ARCHITECTURE.md
├── gitignore.txt
├── parteI-poc.xcodeproj
└── parteI-poc/
    ├── Info.plist                           ← LSApplicationQueriesSchemes (instagram-stories)
    ├── Assets.xcassets                      ← AppIcon, AccentColor, shareBackground
    ├── Scenes/
    │   └── ActivityShare/                   ← única cena do app (VIP)
    │       ├── Configurator/
    │       │   └── ActivityShareConfigurator.swift
    │       ├── Interactor/
    │       │   └── ActivityShareInteractor.swift
    │       ├── Presenter/
    │       │   └── ActivitySharePresenter.swift
    │       ├── Models/
    │       │   ├── ActivityShareModels.swift
    │       │   ├── ActivitySummary.swift
    │       │   └── ActivityShareDraft.swift
    │       ├── View/
    │       │   ├── ActivityShareView.swift
    │       │   ├── ActivityShareCardView.swift
    │       │   ├── ActivityShareSheet.swift
    │       │   └── CameraPicker.swift
    │       └── Workers/
    │           └── ActivityWorker.swift
    └── Services/                            ← serviços genéricos, fora da cena
        ├── ShareImageRenderer.swift
        ├── ShareService.swift
        └── PhotoLibrarySaver.swift
```

| Pasta | O que fica nela |
| --- | --- |
| `Scenes/<Cena>/` | Tudo que pertence a uma cena VIP. Hoje só existe `ActivityShare`. |
| `Configurator/` | Monta a cena: cria as peças e liga as referências entre elas. |
| `Interactor/` | Regra de negócio da cena e protocolo `ActivityShareBusinessLogic`. |
| `Presenter/` | Formatação dos dados para exibição e protocolo `ActivitySharePresentationLogic`. |
| `Models/` | Modelos da cena (`Request`/`Response`/`ViewModel`), a entidade `ActivitySummary` e o estado compartilhado `ActivityShareDraft`. |
| `View/` | Tela SwiftUI, o "store" que faz a ponte com o Presenter, o template do card e as pontes com UIKit (câmera e share sheet). |
| `Workers/` | Fonte de dados da atividade (hoje apenas um mock). |
| `Services/` | Utilitários sem conhecimento da cena: renderização View → imagem, preparo dos itens de compartilhamento e gravação na galeria. |

---

## 3. Cena `ActivityShare`

### Ciclo VIP desta cena

```
ActivityShareView (SwiftUI)
        │  chama métodos
        ▼
ActivityShareStore ──(ActivityShareBusinessLogic)──► ActivityShareInteractor
        ▲                                                   │
        │ (ActivityShareDisplayLogic)                       │ (ActivitySharePresentationLogic)
        │                                                   ▼
        └─────────────────────────────────────── ActivitySharePresenter
```

Todas as peças são `@MainActor`.

### 3.1 View

A camada de View tem quatro arquivos.

**`ActivityShareView.swift`** contém três tipos:

- **`ActivityShareDisplayLogic`** (protocolo): o que o Presenter pode pedir à View — `displayActivity(viewModel:)`.
- **`ShareItem`**: struct `Identifiable` (com `UUID`) que embrulha `activityItems: [Any]`. Serve para disparar o `.sheet(item:)`.
- **`ActivityShareStore`**: `final class` que é `ObservableObject` e implementa `ActivityShareDisplayLogic`. É a "View" do ponto de vista do VIP (é ela que o Presenter enxerga) e o estado observável da tela SwiftUI. Propriedades `@Published`:
  - `card` — último `ActivityCardViewModel` recebido.
  - `generatedImage` — a `UIImage` renderizada.
  - `errorMessage`, `saveMessage`, `shareMessage` — textos de feedback.
  - `shareItem` — quando não é `nil`, o share sheet é apresentado (sem `private(set)` porque a View faz binding).

  Métodos:
  - `didTapGenerate()` — limpa mensagens e a imagem, e chama `interactor?.loadActivity(request:)`.
  - `displayActivity(viewModel:)` — chamado pelo Presenter; guarda o `card` e chama `renderImage(from:)`.
  - `renderImage(from:)` (privado) — cria `ActivityShareCardView` e chama `ShareImageRenderer.render`. Em caso de falha, define `errorMessage`. Em caso de sucesso, imprime no console o tamanho, a escala e os pixels (validação da POC) e guarda em `generatedImage`.
  - `didCapturePhoto(_:)` — limpa mensagens e chama `interactor?.selectBackground(request:)`.
  - `didTapSave()` — dentro de um `Task`, chama `PhotoLibrarySaver.save` e define `saveMessage` de sucesso ou erro.
  - `didTapShare()` — chama `ShareService.activityItems(for:mode: .file)` e cria um `ShareItem`; em caso de erro, define `errorMessage`.
  - `didFinishSharing(completed:)` — zera `shareItem` e define `shareMessage` ("Imagem compartilhada.") só se o usuário concluiu.

- **`ActivityShareView`**: a tela SwiftUI. Recebe o store no `init` e guarda como `@StateObject`. Tem um `@State showCamera`. O `body` é um `ScrollView` com:
  - Botão "Tirar foto" (desabilitado se `!CameraPicker.isAvailable`) e botão "Gerar imagem".
  - Aviso de câmera indisponível.
  - Mensagem de erro em vermelho.
  - Se `generatedImage` existir: a pré-visualização (`scaledToFit`, altura máx. 400), os botões "Compartilhar" e "Salvar na galeria" e as mensagens de salvar/compartilhar.
  - `.sheet(item: $store.shareItem)` → apresenta `ActivityShareSheet`.
  - `.fullScreenCover(isPresented: $showCamera)` → apresenta `CameraPicker`.

**`ActivityShareCardView.swift`** — o **template** que vira imagem. Recebe um `ActivityCardViewModel` e desenha, em tamanho fixo `ShareImageSpec.pointSize` (360 × 640 pt):
- O fundo (`Image(name)` para `.asset` ou `Image(uiImage:)` para `.loaded`), com `scaledToFill` e `clipped`.
- Uma camada preta com 30% de opacidade para dar contraste.
- Título (22 pt bold, com tracking), tempo (80 pt heavy rounded), desafios e pontos (24 pt semibold) e nome do app (16 pt, 80% de opacidade), tudo em branco.
- Fontes com tamanho fixo (ignoram Dynamic Type) e `colorScheme` forçado para `.light`, para que a imagem seja sempre igual.

**`ActivityShareSheet.swift`** e **`CameraPicker.swift`** — pontes com UIKit, explicadas na [seção 6](#6-conexão-swiftui--uikit).

### 3.2 Interactor — `ActivityShareInteractor`

- Protocolo **`ActivityShareBusinessLogic`**: `loadActivity(request:)` e `selectBackground(request:)`.
- Guarda uma referência ao `ActivityShareDraft` (recebido no `init`) e ao `presenter`.
- `loadActivity(request:)` — lê `draft.activity` e `draft.photoData` e chama `presenter?.presentActivity(response:)`.
- `selectBackground(request:)` — grava `request.imageData` em `draft.photoData` e chama `loadActivity` de novo, para reapresentar o card com a nova foto.

O Interactor **não usa Worker**: os dados vêm do Draft.

### 3.3 Presenter — `ActivitySharePresenter`

- Protocolo **`ActivitySharePresentationLogic`**: `presentActivity(response:)`.
- Guarda `weak var view: ActivityShareDisplayLogic?`.
- `presentActivity(response:)` converte o `Response` em `ActivityCardViewModel`:
  - `title` → em maiúsculas.
  - `timeText` → `mm:ss`, ou `h:mm:ss` se tiver horas (ex.: 1543 s → `25:43`).
  - `scoreText` → `"1 ponto"` ou `"N pontos"`.
  - `challengesText` → `"1 desafio"` ou `"N desafios"`.
  - `appName` → `CFBundleDisplayName`, senão `CFBundleName`, senão `""`.
  - `background` → `.loaded(UIImage)` se `backgroundImageData` gerar uma imagem válida; caso contrário, `.asset("defaultBackground")`.
- Chama `view?.displayActivity(viewModel:)`.

### 3.4 Router

**Não existe.** A apresentação da câmera (`fullScreenCover`) e do share sheet (`sheet`) é feita diretamente pela `ActivityShareView`.

### 3.5 Models

**`ActivityShareModels.swift`**
- `enum ActivityShare` (namespace da cena):
  - `LoadActivity.Request` — vazio.
  - `LoadActivity.Response` — `activity: ActivitySummary` e `backgroundImageData: Data?`.
  - `LoadActivity.ViewModel` — `card: ActivityCardViewModel`.
  - `SelectBackground.Request` — `imageData: Data`.
- `enum BackgroundSource: Equatable` — `.asset(String)` ou `.loaded(UIImage)`.
- `struct ActivityCardViewModel: Equatable` — textos já formatados + `background`. É o que o template consome.

**`ActivitySummary.swift`** — entidade de negócio: `title`, `durationInSeconds`, `score`, `completedChallenges`.

**`ActivityShareDraft.swift`** — `final class` `@MainActor` que guarda o estado do fluxo: `activity`, `feeling: String?` e `photoData: Data?`. É classe (tipo referência) para que todas as cenas enxerguem o mesmo objeto. Hoje só `activity` e `photoData` são usados; `feeling` não é lido nem escrito por nenhum código.

### 3.6 Worker — `ActivityWorker.swift`

- Protocolo `ActivityWorkerProtocol` com `fetchLastActivity() -> ActivitySummary`.
- `MockActivityWorker` devolve dados fixos ("Atividade X", 25 min 43 s, 850 pontos, 12 desafios).
- É usado **apenas** no `ParteIPocApp.init()` para criar o Draft. O Interactor não usa o Worker.

### 3.7 Configurator — `ActivityShareConfigurator`

`makeView(draft:)` (`@MainActor`):

1. Cria `ActivityShareStore`, `ActivityShareInteractor(draft:)` e `ActivitySharePresenter`.
2. Liga: `store.interactor = interactor`, `interactor.presenter = presenter`, `presenter.view = store` (referência `weak`, evitando ciclo de retenção).
3. Retorna `ActivityShareView(store: store)`.

Quem mantém tudo vivo: a View segura o store (`@StateObject`), o store segura o Interactor, o Interactor segura o Presenter, e o Presenter aponta de volta para o store de forma fraca.

### 3.8 Ponto de entrada — `ParteIPocApp`

O `@main` cria o `ActivityShareDraft` **uma única vez** no `init` (com `MockActivityWorker().fetchLastActivity()`), para o estado não ser recriado quando o SwiftUI reavalia o `body`. O `WindowGroup` exibe `ActivityShareConfigurator.makeView(draft:)`.

---

## 4. Fluxo principal, passo a passo

### 4.1 Do toque em "Gerar imagem" até a imagem aparecer

1. Usuário toca **"Gerar imagem"** em `ActivityShareView`.
2. A View chama `store.didTapGenerate()`.
3. O store limpa as mensagens, define `generatedImage = nil` e chama `interactor.loadActivity(request: .init())`.
4. O Interactor monta `LoadActivity.Response(activity: draft.activity, backgroundImageData: draft.photoData)` e chama `presenter.presentActivity(response:)`.
5. O Presenter formata os textos, decide o fundo (`.loaded` ou `.asset("defaultBackground")`), cria o `ActivityCardViewModel` e chama `view.displayActivity(viewModel:)` — `view` é o store.
6. O store guarda `card` e chama `renderImage(from:)`.
7. `renderImage` cria `ActivityShareCardView(viewModel:)` e chama `ShareImageRenderer.render(_:)`.
8. O renderer usa `ImageRenderer` com tamanho 360 × 640 pt e `scale = 3`, devolvendo uma `UIImage` de 1080 × 1920 px (ou `nil`).
9. Se der certo, o store imprime os valores de validação no console e define `generatedImage`. Por ser `@Published`, a View se redesenha e mostra a pré-visualização e os botões "Compartilhar" e "Salvar na galeria".

### 4.2 Do toque em "Compartilhar" até o share sheet abrir

10. Usuário toca **"Compartilhar"**.
11. A View chama `store.didTapShare()`.
12. O store confere se existe `generatedImage`, limpa `shareMessage` e chama `ShareService.activityItems(for: image, mode: .file)`.
13. O `ShareService` gera o PNG (`pngData()`), grava em `tmp/atividade.png` (escrita atômica) e retorna `[URL]`.
14. O store cria `ShareItem(activityItems: items)` e atribui a `shareItem`.
15. Como `shareItem` deixou de ser `nil`, o `.sheet(item: $store.shareItem)` da View é disparado.
16. O conteúdo do sheet é `ActivityShareSheet(items:)`, que no `makeUIViewController` cria um `UIActivityViewController` com a URL do PNG. **O share sheet do sistema abre.**
17. Quando o usuário conclui ou cancela, o `completionWithItemsHandler` chama `onFinish(completed)` → `store.didFinishSharing(completed:)`, que zera `shareItem` (fechando o sheet) e, se `completed == true`, mostra "Imagem compartilhada.".

### 4.3 Fluxos secundários

**Tirar foto**
1. "Tirar foto" → `showCamera = true` → `.fullScreenCover` apresenta `CameraPicker`.
2. Ao tirar a foto, o `Coordinator` reduz a imagem (lado maior ≤ 1920 px), converte para JPEG (qualidade 0,9) e chama `onFinish(data)`. Ao cancelar, chama `onFinish(nil)`.
3. A View define `showCamera = false` e, se houver dados, chama `store.didCapturePhoto(data)`.
4. O store chama `interactor.selectBackground`, que grava em `draft.photoData` e chama `loadActivity` → passos 4 a 9 acima. Ou seja, **tirar uma foto já regenera a imagem automaticamente**, sem precisar tocar em "Gerar imagem".

**Salvar na galeria**
1. "Salvar na galeria" → `store.didTapSave()`.
2. Em um `Task`, chama `PhotoLibrarySaver.save(image)`.
3. Sucesso → "Imagem salva na galeria."; erro → "Não foi possível salvar. Verifique a permissão de fotos.".

---

## 5. Services

### 5.1 `ShareImageRenderer` (+ `ShareImageSpec`)

**O que faz:** converte qualquer View SwiftUI em `UIImage`.

**Como funciona:**
- `ShareImageSpec` define a especificação da imagem: `pointSize = 360 × 640` e `scale = 3`, o que resulta em 1080 × 1920 px (proporção 9:16 de Stories).
- `ShareImageRenderer.render(_:size:scale:)` é `@MainActor` (exigência do `ImageRenderer`) e genérico em `Content: View`:
  1. Cria um `ImageRenderer` com o conteúdo envolvido em `.frame(width:height:)`.
  2. Define `proposedSize = ProposedViewSize(size)` e `scale`.
  3. Retorna `renderer.uiImage`, que é `nil` se a renderização falhar.
- Importa só SwiftUI e não conhece a cena.

### 5.2 `ShareService`

**O que faz:** prepara o array `activityItems` que o `UIActivityViewController` recebe.

**Como funciona:**
- `enum Mode`:
  - `.image` → retorna `[image]` (a `UIImage` direto; o iOS decide o formato).
  - `.file` → retorna `[URL]` de um PNG temporário (formato e resolução garantidos).
  - O comentário indica que os dois modos existem para comparação ("atividade 4 do CBL"). O app usa hoje apenas `.file`.
- `activityItems(for:mode:) throws -> [Any]` escolhe o caminho conforme o modo.
- `makeTemporaryPNG(from:name:)` (privado): gera `pngData()` (lança `ShareError.encodingFailed` se falhar), monta `FileManager.default.temporaryDirectory/atividade.png` e grava com `.atomic`.
- Importa só UIKit; não conhece SwiftUI nem a cena.

### 5.3 `PhotoLibrarySaver`

**O que faz:** salva uma `UIImage` no app Fotos.

**Como funciona:**
- `save(_:) async throws`:
  1. Pede autorização com `PHPhotoLibrary.requestAuthorization(for: .addOnly)` (somente adicionar, sem ler a biblioteca).
  2. Se o status não for `.authorized` nem `.limited`, lança `SaveError.permissionDenied`.
  3. Chama `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }`.
- O texto de permissão vem da build setting `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription`.

---

## 6. Conexão SwiftUI ↔ UIKit

O app é SwiftUI, mas três partes dependem de UIKit. Há dois mecanismos diferentes de ponte.

### 6.1 `UIViewControllerRepresentable` — colocar um UIViewController dentro do SwiftUI

O protocolo `UIViewControllerRepresentable` permite que um `UIViewController` seja usado como se fosse uma View SwiftUI. O SwiftUI:
- chama `makeUIViewController(context:)` **uma vez**, para criar o controller;
- chama `updateUIViewController(_:context:)` quando o estado SwiftUI muda (aqui os dois são vazios, porque nada precisa ser atualizado depois de criado);
- chama `makeCoordinator()` (se implementado) **antes** do `make`, para criar um objeto que vive enquanto a view existir e que pode servir de *delegate*.

O retorno do UIKit para o SwiftUI é feito com **closures** (`onFinish`) passadas pela View SwiftUI.

#### `ActivityShareSheet` → `UIActivityViewController`

- Recebe `items: [Any]` e `onFinish: (Bool) -> Void`.
- `makeUIViewController` cria o `UIActivityViewController(activityItems:applicationActivities: nil)`.
- Usa `completionWithItemsHandler` (uma closure, não um delegate), por isso **não precisa de Coordinator**. A closure repassa `completed` para `onFinish`.
- Na `ActivityShareView`, é apresentado com `.sheet(item: $store.shareItem)`. O padrão `item:` + `ShareItem: Identifiable` garante que o sheet só abre quando há itens prontos, e que cada compartilhamento recebe um `id` novo.

```
store.shareItem = ShareItem(...)            (SwiftUI state)
      ↓ .sheet(item:)
ActivityShareSheet.makeUIViewController     (cria o UIKit)
      ↓ usuário conclui/cancela
completionWithItemsHandler → onFinish       (UIKit → closure)
      ↓
store.didFinishSharing → shareItem = nil    (SwiftUI fecha o sheet)
```

#### `CameraPicker` → `UIImagePickerController`

- Recebe `onFinish: (Data?) -> Void`.
- `static var isAvailable` consulta `UIImagePickerController.isSourceTypeAvailable(.camera)`; a View usa isso para desabilitar o botão e mostrar o aviso.
- `makeUIViewController` cria o picker com `sourceType = .camera` e `delegate = context.coordinator`.
- O `UIImagePickerController` **exige um delegate** (`UIImagePickerControllerDelegate & UINavigationControllerDelegate`), que precisa ser um `NSObject`. Uma struct SwiftUI não pode ser isso, então o **`Coordinator`** (`final class Coordinator: NSObject`) cumpre esse papel:
  - `imagePickerController(_:didFinishPickingMediaWithInfo:)` → pega `.originalImage`, reduz com `downscaled(maxDimension: 1920)`, converte para JPEG 0,9 e chama `onFinish(data)`.
  - `imagePickerControllerDidCancel(_:)` → `onFinish(nil)`.
- Na View, é apresentado com `.fullScreenCover(isPresented: $showCamera)` e `.ignoresSafeArea()`. Quem fecha a câmera é a própria View (`showCamera = false` dentro da closure).
- A extensão `UIImage.downscaled(maxDimension:)` usa `UIGraphicsImageRenderer` com `format.scale = 1` para reduzir fotos de ~12 MP e poupar memória.

### 6.2 `ImageRenderer` — transformar SwiftUI em `UIImage`

No sentido contrário, `ShareImageRenderer` usa o `ImageRenderer` do SwiftUI para desenhar o `ActivityShareCardView` fora da tela e obter uma `UIImage` (tipo UIKit). Essa `UIImage` é então usada pelo UIKit (`UIActivityViewController`, via PNG) e pelo Photos (`PHAssetChangeRequest`).

### 6.3 `ObservableObject` — a ponte entre o VIP (classes) e o SwiftUI

O VIP é baseado em classes e protocolos; o SwiftUI é baseado em estado. O `ActivityShareStore` une os dois: implementa `ActivityShareDisplayLogic` (o Presenter chama `displayActivity`) e é `ObservableObject` com `@Published` (a View redesenha quando algo muda). Para isso o arquivo importa `Combine` (`public import Combine`).

### 6.4 Resumo

| Peça | Direção | Mecanismo | Volta para o SwiftUI via |
| --- | --- | --- | --- |
| `ActivityShareSheet` | SwiftUI → UIKit | `UIViewControllerRepresentable` | `completionWithItemsHandler` → `onFinish(Bool)` |
| `CameraPicker` | SwiftUI → UIKit | `UIViewControllerRepresentable` + `Coordinator` (delegate) | métodos do delegate → `onFinish(Data?)` |
| `ShareImageRenderer` | SwiftUI → `UIImage` | `ImageRenderer` | valor de retorno |
| `ActivityShareStore` | VIP → SwiftUI | `ObservableObject` / `@Published` | redesenho automático da View |

---

## 7. Pontos de atenção

1. **Imagem de fundo padrão não existe com esse nome.** O Presenter usa `.asset("defaultBackground")`, mas no `Assets.xcassets` só existe `shareBackground`. Sem foto da câmera, o fundo do card fica vazio (só a camada preta de 30%). Além disso, o arquivo do `shareBackground.imageset` se chama `" .jpg"` (nome começando com espaço).
2. **Texto de permissão da galeria é um placeholder.** `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` tem o valor literal `NSPhotoLibraryAddUsageDescription`, que é o texto que o usuário verá no alerta de permissão.
3. **Não existe Router.** A navegação (câmera e share sheet) é feita direto na `ActivityShareView`.
4. **A camada View faz trabalho que não passa pelo Interactor.** O `ActivityShareStore` chama diretamente `ShareImageRenderer`, `ShareService` e `PhotoLibrarySaver`. Salvar e compartilhar não têm `Request`/`Response`/`ViewModel` nem passam pelo ciclo VIP.
5. **Worker não é usado pela cena.** `MockActivityWorker` só é usado no `@main`. O comentário cita uso em "previews", mas não há nenhum `#Preview` no projeto.
6. **`ActivityShareDraft.feeling` não é usado** por nenhum código (o comentário menciona uma "cena de sentimento" que não existe).
7. **`ShareService.Mode.image` não é usado.** O app sempre chama `.file`.
8. **`LSApplicationQueriesSchemes` com `instagram-stories`** está no `Info.plist`, mas nenhum código usa esse esquema (`canOpenURL`/`open`).
9. **Caminhos nos comentários `// MARK:` não batem com as pastas reais.** Ex.: `Entities/ActivitySummary.swift` (está em `Models/`), `Workers/ActivityWorker.swift` (está em `Scenes/ActivityShare/Workers/`), `Scenes/ActivityShare/ActivityShareInteractor.swift` (está em `Interactor/`).
10. **`ParteIPocApp.swift` fica na raiz do repositório**, fora da pasta `parteI-poc/` onde estão os demais arquivos.
11. **Uso de Combine.** `ActivityShareView.swift` usa `ObservableObject`/`@Published` com `public import Combine` (o `public` não é necessário num target de app). O framework Observation (`@Observable`) seria a alternativa sem Combine.
12. **Arquivo temporário fixo.** O PNG é sempre `tmp/atividade.png`, sobrescrito a cada compartilhamento e nunca apagado. A escrita do arquivo é síncrona na main thread.
13. **Imagem antiga pode ficar visível após erro.** `didCapturePhoto` não zera `generatedImage` antes de renderizar; se a renderização falhar, a pré-visualização anterior continua na tela junto com a mensagem de erro. Já `didTapShare` em caso de erro define `errorMessage`, que só é limpo na próxima geração/foto.
14. **Tirar foto gera a imagem automaticamente**, mesmo que o usuário ainda não tenha tocado em "Gerar imagem" (efeito de `selectBackground` chamar `loadActivity`). Pode ser intencional, mas não está documentado na UI.
15. **`print` de validação** no `renderImage` fica ativo em qualquer build.
16. **APIs SwiftUI antigas:** `.foregroundColor` e `.cornerRadius` são soft-deprecated (alternativas: `.foregroundStyle` e `.clipShape(.rect(cornerRadius:))`).
17. **Orientação:** o iPhone permite paisagem (`UISupportedInterfaceOrientations_iPhone`), mas a tela e o card foram pensados em retrato.
18. **`.gitignore` não está ativo.** O arquivo se chama `gitignore.txt`, então o Git não o usa; por isso arquivos como `UserInterfaceState.xcuserstate` e `.DS_Store` aparecem no repositório.
19. **Sem testes.** O projeto tem apenas o target do app; não há target de testes unitários nem de UI.
