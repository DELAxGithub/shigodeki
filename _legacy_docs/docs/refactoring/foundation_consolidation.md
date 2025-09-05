



-----
作戦名：基盤整備 (Operation: Foundation Consolidation)
## 【厳守】プロジェクト画面 失敗しないリファクタリング指示書

### **目的**

`ProjectListView` および関連するViewを、巨大な `TaskAIAssistantView` から安全に分離し、将来的な改修が容易なクリーンな状態にする。同時に、巨大な `ProjectManager` への直接的な依存を段階的に解消する。

### **大原則**

  * 各ステップが完了するたびに、**必ずビルドし、アプリを実機で動かし、テストを実行すること**。
  * 動作がリファクタリング前と**寸分違わず同じであること**を確認する。
  * この指示書にない独自の変更や「ついでにこれも直しとこう」という考えは**一切禁止**する。

-----

### **フェーズ0：安全網の設置**

**目的：** リファクタリング中に何かを壊してしまっても、即座に検知できるようにする。

1.  **既存テストの全実行:**
      * 現在のテストスイート（`shigodekiTests/`）をすべて実行し、**オールグリーン**になることを確認する。一つでも失敗するテストがあれば、リファクタリングを始める前にそれを修正しろ。
2.  **プロジェクト画面UIテストの作成:**
      * `shigodekiTests/` 内に、`ProjectScreenRefactoringTests.swift` のような新しいテストファイルを作成する。
      * このテストは、以下の点を確認するだけで良い：
          * プロジェクト画面を開いた時に、プロジェクトのリストが表示されること。
          * リストのいずれかの行をタップすると、プロジェクト詳細画面に遷移すること。
      * これは我々がこれから行う作業の\*\*「命綱」\*\*だ。

-----

### **フェーズ1：Viewの物理的な分離（機械的作業）**

**目的：** コードを「移動」させるだけ。ロジックの変更は一切行わない。

1.  **新ファイルの作成:**
      * `Views/Project/` という新しいグループ（フォルダ）を作成する。
      * その中に `ProjectListView.swift` という名前で新しいSwiftUI Viewファイルを作成する。
2.  **コードの特定と移動:**
      * `TaskAIAssistantView.swift` の中から、**現在のプロジェクト一覧を表示しているViewの定義**（おそらく `struct ProjectListView: View` のような名前のはずだ）を見つけ出す。
      * その `struct` の開始 (`struct`) から終了 (`}`) までを**丸ごとカット**し、新しく作った `ProjectListView.swift` ファイルに**ペースト**する。
3.  **コンパイルエラーの機械的な修正:**
      * `ProjectListView.swift` で発生するコンパイルエラーを修正する。
          * `import` が足りなければ追加する。
          * もし`TaskAIAssistantView`内にあったヘルパーメソッドや`private extension`などを参照している場合は、それらも**そのままコピー**して`ProjectListView.swift`のファイル内に`private`として移動させろ。
4.  **呼び出し元の差し替え:**
      * `TaskAIAssistantView.swift` の、先ほどコードをカットした場所に、新しいViewへの呼び出し (`ProjectListView()`) を記述する。
5.  **検証:**
      * ビルドし、テストを実行する。**フェーズ0で作成したUIテストがパスすること**。
      * アプリを動かし、プロジェクト画面の表示と挙動が**以前と完全に同じであること**を確認する。

**このフェーズの完了条件：** `ProjectListView`が物理的に別のファイルに分離され、それでもアプリは以前と全く同じように動作すること。

-----

### **フェーズ2：ViewModelの導入（依存関係の注入）**

**目的：** Viewが`ProjectManager`を直接知っている状態を解消する。ロジックはまだ動かさない。

1.  **ViewModelの作成:**
      * `ViewModels/` フォルダに `ProjectViewModel.swift` という新しいファイルを作成する。
      * 以下の様な、中身が空のViewModelクラスを定義する。
        ```swift
        import Foundation
        import Combine

        class ProjectViewModel: ObservableObject {
            // ProjectManagerを内部に保持する
            private let projectManager: ProjectManager

            init(projectManager: ProjectManager) {
                self.projectManager = projectManager
            }

            // ここにこれからロジックを移していく
        }
        ```
2.  **Viewの修正:**
      * `ProjectListView.swift` を修正する。
      * `@EnvironmentObject` で `ProjectManager` を直接受け取っていた部分を削除する。
      * 代わりに `@StateObject` または `@ObservedObject` で `ProjectViewModel` を保持するように変更する。
        ```swift
        // 変更前
        // @EnvironmentObject var projectManager: ProjectManager

        // 変更後
        @StateObject private var viewModel: ProjectViewModel

        init(projectManager: ProjectManager) {
            _viewModel = StateObject(wrappedValue: ProjectViewModel(projectManager: projectManager))
        }
        ```
      * Viewの `body` 内で `projectManager.projects` のように参照していた部分は、すべて `viewModel.projects` のように、ViewModelを介してアクセスするように書き換える。（そのためにViewModelに`@Published var projects`などを追加し、`projectManager`からデータを受け取るようにする）
3.  **検証:**
      * ビルドし、テストを実行する。**挙動は以前と完全に同じはずだ**。

**このフェーズの完了条件：** `ProjectListView`が`ProjectManager`を直接参照せず、間に`ProjectViewModel`が挟まる構造になったこと。ただし、ロジックはまだ`ProjectManager`の中にある。

-----

### **指示**

まずは**フェーズ0とフェーズ1**を完了させろ。それが終わったら、寸分違わず動作することを確認した上で、再度報告に来い。次の指示はそれからだ。一歩ずつ、着実に行くぞ。今後、この作業に関するすべてのドキュメント、Gitのブランチ名、コミットメッセージ、プルリクエストには、必ず [Foundation Consolidation] というプレフィックスを付けることを義務付ける。

例：

ドキュメント名: Operation_Foundation_Consolidation_Plan.md

ブランチ名: feature/foundation-consolidation-phase1

コミットメッセージ: [Foundation Consolidation] Phase 1: ProjectListViewをTaskAIAssistantViewから分離