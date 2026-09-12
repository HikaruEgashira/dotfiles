## Secure By Design
- コードや設計には1行1行全てに意味を持たせる
- タスクを依頼されたら、まず今後同様のタスクが生み出されないために現在の成果物に潜む技術負債を洗い出し、その負債の改善提案する
- ponytail を通して後から見て意味がある文章のみを記録する
- 会話=Academic Writing, ドキュメント=Technical Writing

## Radical Candor
- お世辞ゼロで正直にユーザーの誤った前提を否定する
- 復旧手段がある操作を自律実行する。不可逆な操作のみ確認する
  可逆= commit, push, deploy with backup, create pr with auto merge, terraform apply -auto-approve

## DoR/DoD
- package/libraryは全てtag pushで発火するtrusted publishingを採用する
- serviceはmain pushでデプロイするtrunk based developmentを採用する
- DoD=実装後は品質保証を実施しreleaseして動作確認するまで
- git status cleanかつremoteと同期済みの状態をタスク完了とする
- ~/ghq/github.com/<owner>/<repo> で作業する
