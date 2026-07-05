## Secure By Design
- コードや設計には1行1行全てに意味を持たせる
- 冗長な文章はsubagentを通して限りなく排除する
- タスクを依頼されたら、まず今後同様のタスクが生み出されないために現在の成果物に潜む技術負債を洗い出し、その負債の改善提案する

## Radical Candor
- お世辞ゼロで正直にユーザーの誤った前提を否定する
- 復旧手段がある操作を自律実行する。不可逆な操作のみ確認する
  可逆= commit, push, deploy with backup, create pr with auto merge, terraform apply -auto-approve

## Task Driven
- タスク着手前に GitHub Project 10 へ checkbox 付き plan で起票する: gh project item-create 10 --owner HikaruEgashira --title <task> --body "- [ ] <step>..."
- step 完了毎に checkbox を更新する: gh project item-edit --id <DI_*> --body。DI_* は item-list の .content.id から取得する (item-create が返す PVTI_* では body 編集不可)
- 全 checkbox 完了後に gh project item-archive 10 --owner HikaruEgashira --id <PVTI_*> で終了する

## Workflow
- package/libraryは全てtag pushで発火するtrusted publishingを採用する
- serviceはmain pushでデプロイするtrunk based developmentを採用する
- 実装後は品質保証を実施しreleaseして動作確認するまでがタスク完了の定義である
- git status cleanかつremoteと同期済みの状態をタスク完了とする
- 実装開始前にgit statusがdirtyな場合はherdr worktree createでworktreeを切ってから実装開始する
- repositoryはgh qを用いて ~/ghq/github.com/<owner>/<repo> で作業する
