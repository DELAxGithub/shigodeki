承知いたしました。
App Store公開経験があり、ID管理にも慣れている方向けに、**スケーラブルな開発環境**を意識した手順書を作成します。開発用と本番用環境を分けることを前提としています。

-----

### iOSアプリ『シゴデキ』開発キックオフ手順書

この手順書は、Firebaseをバックエンドとして採用し、効率的かつ安全に開発を進めるための初期設定を定義するものです。

-----

### フェーズ1：実装前の意思決定 (最重要)

コードを1行も書く前に、チーム（たとえ一人でも）で以下の項目を決定し、合意します。ここの設計がプロジェクトの成否を分けます。

| 項目 | 決定事項 | 理由・具体例 |
| :--- | :--- | :--- |
| **1. 環境分離** | 開発用(dev)と本番用(prod)の**Firebaseプロジェクトを2つ**作成する。 | 開発中のテストデータが本番ユーザーのデータに混入する事故を完全に防ぎます。安全な機能テストの場を確保するためです。\<br\>例: `shigodeki-dev`, `shigodeki-prod` |
| **2. バンドルID** | 環境ごとにバンドルIDを分ける。\<br\>例: `com.company.shigodeki` (本番用)\<br\>`com.company.shigodeki.dev` (開発用) | Apple Developerサイトで2つのApp IDを登録します。これにより、プッシュ通知などを環境ごとに分けてテストできます。 |
| **3. 認証方法** | ユーザーがログインする方法を全てリストアップする。 | **「Sign in with Apple」は必須**と考えましょう（他のソーシャルログインを提供する場合、Appleの規約で義務付けられています）。\<br\>その他候補: Email/Password, Google |
| **4. データ構造 (Firestore)** | 主要なデータの繋がり（親子関係）を設計する。\<br\>例: `users`, `families`, `taskLists` | **(例) 家族共有モデル**\<br\>・`families/{familyId}` (家族グループ)\<br\>・`families/{familyId}/taskLists/{listId}` (タスクリスト)\<br\>・`families/{familyId}/taskLists/{listId}/tasks/{taskId}` (個別タスク)\<br\>このような構造を事前に検討します。 |
| **5. セキュリティルール** | Firestoreの基本的なアクセス権限ルールを言語化する。 | **(例)**\<br\>・ユーザーは自分の `user`情報のみ読み書きできる。\<br\>・`families`コレクションのデータは、その家族のメンバーしか読み書きできない。\<br\>この方針を元に、Firestoreのルールを記述します。 |

-----

### フェーズ2：ターミナルでの高速セットアップ

ここからは手を動かします。**環境分離を前提とし、各コマンドをdev用とprod用に2回実行する**場面があります。

| 手順 | コマンド / 内容 | 補足 |
| :--- | :--- | :--- |
| **1. Firebase CLI準備** | `npm install -g firebase-tools`\<br\>`firebase login` | 未インストールの場合のみ実行。一度ログインすればOK。 |
| **2. Firebaseプロジェクト作成 (x2)** | `firebase projects:create shigodeki-dev --display-name "シゴデキ (Dev)"`\<br\>`firebase projects:create shigodeki-prod --display-name "シゴデキ (Prod)"` | フェーズ1で決めたIDでプロジェクトを2つ作成します。 |
| **3. iOSアプリ登録 (x2)** | `cd (Xcodeプロジェクトの場所)`\<br\>`firebase apps:create` | **対話形式のコマンドを2回実行します。**\<br\>1回目: `shigodeki-dev` プロジェクトに `com.company.shigodeki.dev` を登録。\<br\>2回目: `shigodeki-prod` プロジェクトに `com.company.shigodeki` を登録。 |
| **4. 設定ファイルの整理** | `mv GoogleService-Info.plist GoogleService-Info-Dev.plist`\<br\>`mv GoogleService-Info.plist GoogleService-Info-Prod.plist` | コマンド実行後、ダウンロードされたファイル名を変更します。これで**2つの環境設定ファイル**が手元に揃います。 |

**【このフェーズの成果物】**

  * `GoogleService-Info-Dev.plist`
  * `GoogleService-Info-Prod.plist`

-----

### フェーズ3：Xcodeでの最終設定

ターミナルで準備したものを、Xcodeプロジェクトに組み込みます。

| 手順 | 内容 | 補足・具体的方法 |
| :--- | :--- | :--- |
| **1. 設定ファイルの配置** | Xcodeプロジェクト内に`Firebase/Config`などのフォルダを作成し、2つの`.plist`ファイルをそこに配置する。 | **ターゲットには含めないでください** (チェックボックスを外す)。ビルド時にスクリプトでコピーするためです。 |
| **2. ビルド構成に応じたファイルコピー** | **Build Phases** に **Run Script** を追加し、ビルド構成(`Debug`/`Release`)に応じて適切な`.plist`ファイルをコピーするスクリプトを記述する。 | **【スクリプト例】**\<br\>`shell<br># Set the path to the plist<br>if [ "${CONFIGURATION}" = "Debug" ]; then<br>  cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Dev.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"<br>else<br>  cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Prod.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"<br>fi<br>` |
| **3. Firebase SDKの導入** | Xcodeの **File \> Add Packages...** からFirebase SDKを導入する。 | `https://github.com/firebase/firebase-ios-sdk` を検索。\<br\>必要なライブラリを選択します (例: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`)。 |
| **4. 初期化コードの実装** | `AppDelegate` または `(AppName)App.swift` に初期化コードを記述する。 | `swift<br>import FirebaseCore<br><br>// ...<br><br>FirebaseApp.configure()<br>`\<br\>このコードは1つでOK。ビルド時にコピーされた正しい`.plist`が自動で読み込まれます。 |
| **5. Firebaseコンソールの設定** | ブラウザでFirebaseコンソールを開き、2つのプロジェクトそれぞれで **Authentication** と **Firestore** を有効化する。 | 特にAuthenticationでは、フェーズ1で決めたログイン方法（Apple, Google等）を有効化します。 |

**【このフェーズのゴール】**

  * XcodeのSchemeを`Debug`でビルド→実行すると、開発用DB(dev)に接続される。
  * XcodeのSchemeを`Release`でビルド→実行すると、本番用DB(prod)に接続される。

-----

### 次のステップ

上記設定が完了したら、いよいよ実装開始です。
まずは**ユーザー登録・ログイン機能**から着手し、Firestoreの`users`コレクションにデータが書き込まれることを確認するのが定石です。これができれば、バックエンドとの連携は成功です。