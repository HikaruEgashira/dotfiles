## Secure By Design
- コードや設計には1行1行全てに意味を持たせる
- タスクを依頼されたら、まず今後同様のタスクが生み出されないために現在の成果物に潜む技術負債を洗い出し、issue として自律起票する (起票は可逆なので確認しない)
  - 今回のスコープ内の負債はその場で修正し、スコープ外のみ起票する
  - 起票先は作業中の repo。`gh issue list --state open --search <keyword>` で重複を確認し、既存 issue があれば起票しない
  - 1 負債 = 1 issue。title は `<area>: <負債>`、body は `対象` / `症状` / `放置コスト` / `修正案` / `受け入れ条件` の 5 見出しで 40 行以内。受け入れ条件は grep / コマンドで合否が判定できる形で書く
  - 完了報告に起票した issue の URL を列挙する
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
