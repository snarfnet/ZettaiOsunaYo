# 絶対押すなよ App Store メモ

## 基本情報

- App name: 絶対押すなよ
- Bundle ID: `com.tokyonasu.zettaiosunayo`
- App Store Connect App ID: `6769247677`
- SKU: `zettaiosunayo`
- Primary language: Japanese
- Category: Games

## 説明文

押すなと言われるほど、押したくなる。

「絶対押すなよ」は、巨大な赤いボタンを前に、押さずに耐えるチャレンジゲームです。

ステージ制のチャレンジ任務、4つのモード、押さないための行動、冷静ポイント、緊張ゲージ、実績、称号、最近の挑戦履歴を収録しています。

起動した瞬間からタイマーが始まり、ランダムな煽り音声があなたの指先を試します。時間が経つほど音声の頻度は上がり、赤いボタンの存在感もじわじわ増していきます。

ちょっとした待ち時間、友だちとのネタ、謎の自制心チェックにどうぞ。

## キーワード

押すな,赤いボタン,ミニゲーム,暇つぶし,耐久,音声,ネタ,ドッキリ,反射神経,自制心

## プロモーションテキスト

押すな。絶対に押すな。あなたは何分耐えられる？

## レビュー用メモ

このアプリはAPI通信を行いません。音声はアプリBundle内のmp3をAVAudioPlayerで再生します。初回起動時にApp Tracking Transparencyの確認を表示し、その確認が終わってからGoogle Mobile Ads SDKを開始します。

Guideline 4.2対応として、単一ボタンだけの体験から、ステージ制チャレンジ任務、押さないための行動、冷静ポイント、任務の達成状況、称号、実績、最近の挑戦履歴を含むゲーム体験に拡張しました。

## GitHub Secrets

GitHub Actionsで本番ビルドする場合は、Repository Secretsに以下を入れます。

- `ASC_PRIVATE_KEY`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_ID`

AdMob Secretsが未設定の場合、提出用workflowは止まります。テスト広告ID入りのバイナリは提出しません。

## ASCで確認すること

App名が文字化けして見える場合は、App Store Connectの「App Information」で `絶対押すなよ` に直します。APIの通常UPDATEではApp名を変更できません。
