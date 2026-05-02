---
date: 2026-05-02
topic: secure-fast-lean-dotfiles
focus: セキュリティ・速度・使いやすさ・パフォーマンス・ディスク容量効率の5軸を両立する dotfiles
mode: repo-grounded
---

# Ideation: セキュリティ × 速度 × 使いやすさ × パフォーマンス × ディスク容量を両立する dotfiles

## Codebase Context

- **形状**: Nix flake + home-manager (aarch64-darwin), treefmt 統一, CI は x86_64-linux eval のみ (build は 25min 超で諦め), launchd daily sync (09:00, clean tree only), weekly flake-update auto-merge PR
- **既存の強み**: SSH commit signing, gitleaks 二重防御 (global hook + zsh wrapper), AWS readonly + step-up MFA (ADR-0008), dotenvx, GHA SHA pin + persist-credentials:false, sccache + RUSTC_WRAPPER, TF_PLUGIN_CACHE_DIR, ghostty↔tmux bridge, treefmt-nix での format 集約
- **痛点候補**:
  - **ディスク**: postgresql_14 + redis + podman + lima + qemu + docker-buildx + ollama 同居 (常駐 VM/DB の正当性不明), nixpkgs.ripgrep と brew ripgrep の二重 (codex cask 依存), VS Code 拡張 40+ が Brewfile 滞留, sccache/CARGO_TARGET の容量ローテなし, Cica + PlemolJP 両方搭載
  - **速度**: cachix package は入っているが substituter 未設定, CI で完全 build 諦め, daily activation のホットパス未測定, mise activate が常時 eval, dotenvx は OPENAI_API_KEY 検知でスキップするが失効を見ない
  - **セキュリティ**: long-term AKIA 残存 (SSO 未移行), .env.keys のファイル権限検証なし, gitleaks の repo override フォールバックは zsh wrapper のみ (CI/別 shell では効かない), .npmrc トークンが env 展開
  - **使いやすさ**: zoxide/atuin/direnv 等モダン代替未採用, テーマ不一致 (bat=Dracula vs 他=TokyoNight), TPM なしで tmux 拡張困難, git wrapper の subcmd 検出が脆い (`git -c x=y commit` を取り損ねる), `c`/`claude`/`con` alias の重複, AGENTS.md 不在
  - **負債**: dotfiles-sync が untracked 未検知, `--no-warn-dirty` でサイレント失敗を制度化, ログローテートなし, `homeConfigurations.hikae` 単一で 2 台目への拡張未考慮

## Ranked Ideas

### 1. 計測駆動 Reproducibility パイプ — cachix substituter + determinism gate + drift snapshot
**Description:** flake.nix に `nixConfig.extra-substituters = [ cachix.org nix-community ]` と公開鍵を固定し、自分用 cachix を全マシンで信頼。CI に「同じ flake を 2 回 build → store path hash 一致」を検査する determinism gate を追加。さらに laptop activation の都度 `nix path-info --closure-size` を別 repo (`dotfiles-snapshots`) に commit、CI は eval + snapshot diff を gate にする。daily sync では `nix build --print-build-logs` の wall time + cache hit ratio を `~/.cache/dotfiles-sync/metrics.jsonl` に追記。
**Warrant:**
- `direct:` `modules/packages.nix` に `pkgs.cachix` は入っているが `flake.nix` の `nixConfig` セクションは空 (substituter 未設定)
- `direct:` `.github/workflows/ci.yml:30-37` のコメント「完全ビルドは crush 等の go テスト走行で 25min を超える…ここで止める」 = build は信頼源として捨てている
- `external:` Determinate Systems の magic-nix-cache, NixOS reproducible-builds.org の手法
- `reasoned:` 計測なしには「遅い」が事実か錯覚か判別不能。substituter 不在は home-manager activation が source build に落ちる確率を 100% 受け入れていることに等しい
**Rationale:** 速度・パフォーマンス・将来作業全てに複利が効く。一度入れれば weekly flake-update PR の CI が分→秒、新マシン bootstrap が build→fetch、回帰検出 (closure-size 増加) が初めて自動化される。
**Downsides:** cachix の信頼鍵を増やす = 攻撃面増加 (signed cache を使えば緩和)。snapshot 別 repo の運用コスト。
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

---

### 2. Package Ledger — Brewfile/home.packages を期限付き複式記帳化
**Description:** 「逃げ場」と化している Brewfile と home.packages を、`{ source: nixpkgs|brew|mas|cargo, purpose: edit|comm|observe|play|build, expires: YYYY-MM-DD, reason: "..." }` の閉じた科目体系で記帳する Nix wrapper を作る。launchd weekly で (a) `mdls -name kMDItemLastUsedDate` 30日未使用 → `gh issue create --label prune-candidate` (b) 90日未使用 → 削除 PR auto-open (c) 期限切れエントリ検出 → 延長か退場を強制 (d) `nix-store --query --references` で同名バイナリ重複 (ripgrep 等) を機械検出。`nix run .#ledger close --month` が単一エントリポイント。VS Code 拡張は `nix-vscode-extensions` overlay へ強制移行し、Brewfile に `vscode "..."` 行が現れたら CI fail。
**Warrant:**
- `direct:` `Brewfile:8-14` のコメント「逃げ場」「nixpkgs 化できたら追い出す」が運用の前提だが、棚卸しトリガーは手動
- `direct:` `Brewfile:48-89` に 40+ 個の `vscode "..."` 行が滞留、home-manager に未移行
- `direct:` `Brewfile:13` 「ripgrep を解放できない (codex を nix 化したら ripgrep は削除可)」が放置
- `direct:` `modules/packages.nix:43-48` の qemu/lima/podman/docker-buildx/ollama 同時インストール
- `external:` 倉庫の ABC 分析、複式簿記、Renovate の expiration policy
**Rationale:** ディスク (Cold 退避で GB オーダー削減)、再現性 (出所と用途で grep 可能)、セキュリティ (出所不明 package 0 件保証)。「インストール時の意思決定」と「実使用」の乖離を時間軸で構造的に止める。
**Downsides:** 既存 home.packages 記法への wrapper はメンテ対象が増える。purpose 分類の語彙設計が初期負担。
**Confidence:** 80%
**Complexity:** Medium
**Status:** Unexplored

---

### 3. Secret-file Eradication — user space に「鍵ファイル」を存在させない
**Description:** `~/.aws/credentials` の long-term AKIA、`~/.ssh/id_*` の private key、`~/.config/secrets/.env.keys` を全て廃止する完成形を目指す。具体的には: (a) AWS は IAM Identity Center + `aws sso login` に強制移行、`role_arn + source_profile + mfa_serial` を `sso_session` 一本化、laptop に `grep AKIA` で 1 件でも出たら activation で warn → 90 日後 fail。(b) SSH は 1Password SSH agent + Secure Enclave key、`programs.ssh` から identity files を削除。(c) API key 類は `op run --` または direnv (`.envrc.signed`) 経由で「`cd` した shell だけが load」モデルに転換、global zshrc から secret eval を完全削除。(d) 移行期間中は `.env.keys` の `stat -f '%A'` が 600 でなければ activation を fail。(e) gitleaks の自分鍵 HMAC fingerprint で精度を上げる。
**Warrant:**
- `direct:` `modules/programs/aws.nix:11-16` のコメント「The only long-lived AKIA…lives under [default]」 = 既知の弱点として ADR で明記済
- `direct:` `modules/programs/zsh.nix:103-114` の dotenvx ブロックは `OPENAI_API_KEY` 既存検知でスキップするが、ファイル権限・失効・取り消しを見ていない
- `direct:` `modules/home.nix:9-14` の `.npmrc` は env 展開で 4 つのトークンを参照
- `external:` AWS は 2024 以降 IAM Identity Center を first-class 推奨、1Password CLI と SSH agent は macOS で実用段階、GitHub OIDC で workload key は 0 化可能
- `reasoned:` 「scan で見つける」は事後対応、「存在させない」は事前設計。default-deny / opt-in は最小権限の原則
**Rationale:** セキュリティの根源的改善 (漏洩時の blast radius が「laptop 全権限」→「1 時間 token」) と使いやすさ (秘密を覚えない) と後続の gitleaks の存在意義の縮小が同時に進む。
**Downsides:** SSO 移行は AWS account 側の準備が要る (IAM Identity Center 設定)。1Password 依存への vendor lock-in。移行中の deprecation timer の閾値設定はチーム合意必須。
**Confidence:** 75%
**Complexity:** High (段階的に進める前提)
**Status:** Unexplored

---

### 4. 波及する Pre-commit Flake Module + treefmt 拡張 + AGENTS.md auto-gen
**Description:** dotfiles を「自分の全 repo に効く品質層」の供給源にする 3 点セット。(a) gitleaks + treefmt + shellcheck + ast-grep ルールを束ねた flake output `packages.pre-commit-bundle` を提供し、他 repo は `inputs.hooks.url = "github:HikaruEgashira/dotfiles"` 1 行で同じ hook を取得。(b) treefmt 対象を Python (ruff format) / TypeScript (biome) / Go (gofumpt) / Lua (stylua) に拡大し、`apps.lint` で ruff check / biome check / shellcheck / statix / deadnix を集約。`nix fmt` と `nix run .#lint` の 2 entry point に正規化。(c) 各 `modules/programs/<name>.nix` の冒頭コメント (purpose / 依存 / 二次効果) を `nix run .#docs` で抽出し AGENTS.md / README.md を deterministic 生成。CI で「生成結果と repo の差分なし」をゲート。
**Warrant:**
- `direct:` `flake.nix:52-65` の treefmt-nix 設定は nixfmt + prettier + shfmt のみ
- `direct:` `modules/programs/git.nix:11-22` の preCommit script は gitleaks のみで、他 repo に流用する仕組みは未提供
- `direct:` ルートに `AGENTS.md` 不在 (`CLAUDE.md` は 97 bytes でほぼ空)
- `external:` `nix-community/nix-vscode-extensions`, `cachix/pre-commit-hooks.nix`, `numtide/treefmt-nix` の確立パターン
- `reasoned:` 1 箇所更新で全 repo が weekly flake-update で自動追従するので、「あの repo の hook 古い」が原理的に消滅。これは三段以上の複利
**Rationale:** dotfiles 自体への投資が「他の自分の repo すべて」に伝播する複利が立ち上がる。新言語追加が treefmt 1 行で済むので polyglot 化の閾値が下がる。AGENTS.md 自動化は AI agent の修正提案品質を上げ、自動メンテに乗る。
**Downsides:** Python/TS/Go の formatter 選定に好みがある (ruff vs black, biome vs prettier)。AGENTS.md auto-gen は doc 生成パーサのメンテが要る。
**Confidence:** 85%
**Complexity:** Medium
**Status:** Unexplored

---

### 5. GitOps Activation + multi-host matrix — `git push` で全 Mac が収束
**Description:** 09:00 launchd daily sync を撤廃し、`fswatch ~/dotfiles` + `WatchPaths` 経由で「commit が増えた瞬間に push、`origin/main` 更新を `repository_dispatch` 経由で全 laptop に送って `nix run .#...activationPackage`」の event-driven 収束に置き換える。同時に `homeConfigurations.<user>@<host>` を matrix 化し、`hosts/<name>/` で host 固有 overlay (work proxy, 別 git identity, screenlock) を分離。`modules/common/` と `hosts/<name>/` の規約で 2 台目以降が `nix run .#homeConfigurations.hikae@work.activationPackage` 1 行で立ち上がる。CI matrix で全 host configuration の eval を並列検査。dotfiles-sync は踏み台として `--no-warn-dirty` 撤廃 + untracked 検知 + `~/Library/Logs/dotfiles-sync/` への日次ローテで堅牢化してから event-driven へ昇格。
**Warrant:**
- `direct:` `modules/programs/dotfiles-sync.nix:29-42` は `git diff --quiet HEAD --` のみ (untracked 未検知)、`--no-warn-dirty` 使用、ログローテなし
- `direct:` `flake.nix:68` は `homeConfigurations."hikae"` 単一で `extraSpecialArgs.dotfilesPath = self` のみ、host 固有オーバーレイなし
- `external:` ArgoCD/Flux の pull-based GitOps、NixOS の `system.autoUpgrade`
- `reasoned:` 09:00 polling は「commit してから別 Mac に届くまで最大 24h」の divergence window を制度化している。WatchPaths + dispatch は秒オーダーに圧縮可能
**Rationale:** multi-host 運用が first-class 化し、新 host 追加が 1 ファイル化。divergence window が秒単位に。`--no-warn-dirty` のサイレント失敗を構造的に止める。
**Downsides:** `repository_dispatch` 受信側の常駐 listener (tailscale 経由 ssh など) が必要。host 増加に伴う CI build 時間増加。
**Confidence:** 70%
**Complexity:** Medium-High
**Status:** Unexplored

---

### 6. MEL (Minimum Equipment List) + Sneakernet Recovery Bundle
**Description:** 航空機の MEL に倣い、`mel.nix` に「これさえ動けば仕事継続可能」な最小構成 (例: zsh + git + ssh + nvim + 1Password CLI + sops) を declarative に宣言。CI で `nix build .#mel` が落ちたら全 PR ブロック、それ以外の breakage は warning 格下げで「essential vs nice-to-have」を曖昧にしない。さらに四半期に 1 回、`nix copy --to file://...` で MEL closure と必須 dmg / cask を 1 つの USB イメージに固める CI ジョブを追加し、海外/障害/ネット遮断時の DR 手段にする。MEL は `homeConfigurations.hikae` の subset として定義し、平常時の build cone を直接重用する。
**Warrant:**
- `direct:` `home.nix` で 11 module が `imports` に並列して全部 essential 扱い、優先順位なし
- `direct:` `flake.nix:75-78` の checks も「全部 build」のみで essential subset の概念なし
- `external:` FAA Master MEL、SRE の SLI/SLO 階層化、Nix の closure export パターン
- `reasoned:` 「何が essential か」を曖昧にする限り、breakage 時の優先順位は毎回 ad-hoc になり、復旧時間が伸びる
**Rationale:** 使いやすさ (fail mode が予見可能)、セキュリティ (緊急時に何を残すか即決可)、速度 (essential CI gate が軽い)、可用性 (DR USB 化)。
**Downsides:** MEL の境界決定はチーム議論が要る。USB DR は四半期 op コスト。
**Confidence:** 70%
**Complexity:** Medium
**Status:** Unexplored

---

### 7. Gitleaks 一重化 — server-side push protection に検知責務を委譲、zsh wrapper を撤去
**Description:** 現状 pre-commit hook (`xdg.configFile."git/hooks/pre-commit"`) と zsh の `git()` wrapper の 2 箇所で gitleaks を回している。後者を撤去し、(a) global pre-commit hook のみ残す (b) GitHub repository ruleset で push protection (secret scanning) を org/全 repo 単位で強制 (c) pre-commit が install されていない repo を `cd` した瞬間 direnv で warn する一重保証に置き換える。`zsh` の `git()` 関数は core.hooksPath override 検出ロジック自体が消えるので、subcmd parser の脆弱性 (`git -c x=y commit` を取り損ねる) も同時に解消。
**Warrant:**
- `direct:` `modules/programs/zsh.nix:58-79` の git wrapper は `subcmd` 検出が `case "$arg" in -c|-C|...) skip_next=1` の手書きで、`git -c gpg.program=sh` 等のパターンで誤検知する
- `direct:` `modules/programs/git.nix:11-22` で global hook が gitleaks を実行
- `external:` GitHub secret scanning push protection は public/private repo で free 化 (2024 以降)、TruffleHog/GitGuardian も同方向
- `reasoned:` 同じ責務を 2 箇所で持つと両方が中途半端になる (Secure By Design)。shell wrapper は `gh`/IDE/hook script から呼ばれた瞬間に bypass されるので control の信頼性が低い
**Rationale:** セキュリティ (漏れの検知が経路に依存しない)、使いやすさ (zsh の予測可能性が上がる、subcmd parser 撤去)。検知責務を server-side に集約することで「あるつもり」を排除。
**Downsides:** GitHub push protection は org / repo 設定が必要 (個人 repo は手動有効化)。pre-commit を bypass された時の最終防衛線が server-side のみになる ↔ 二重防御原則とは衝突。
**Confidence:** 80%
**Complexity:** Low
**Status:** Unexplored

---

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| R1 | mise activate を zsh-defer で lazy 化 | 効果は数十 ms × N、価値はあるが meeting-test 弱、survivor 5/6/7 内の改善で十分カバー可能 |
| R2 | Shell Session Flight Recorder (zsh ring buffer) | 興味深いが warrant が reasoned 偏重、5 軸との直接結びつき弱、atuin (survivor 内) で部分カバー |
| R3 | LOD prompt (タイピング中/Enter 後/Idle で解像度変更) | starship transient prompt 等で近い実装あり、効果は体感のみ → brainstorm 候補 |
| R4 | Anti-Windup bounded flake update | 既に weekly auto-merge 化、Renovate/Dependabot の grouping で代替可能 |
| R5 | git repo を Nix flake registry の TOFU 配信に置換 | history は debug に必須、pragmatism 低い radical 案 |
| R6 | Brew 完全削除 | grounding が brew 残存理由を明示 (codex/macfuse/fuse-t/arc)、survivor 2 (Package Ledger) で十分 |
| R7 | Situational dotfiles (SSID/location 自動切替) | 効果が分散、warrant reasoned のみ、survivor 8 (theme/danger 切替) で部分採用余地 |
| R8 | atuin shell history sync 単独 | 価値はあるが他 survivor と統合不能、独立 issue で進めれば十分 (brainstorm 候補) |
| R9 | Negative selection HMAC fingerprint | novelty 高いが GitHub push protection で実用解決済 → brainstorm 候補 |
| R10 | Remote Nix Store + FUSE lazy fetch | SSD 数百 GB ある現状で reverse の現実価値低、survivor 2/6 で部分カバー |
| R11 | Pre-warmed zsh/nvim daemon pool | mosh/zellij で同種解決済、scope 大きい割に効果は数百 ms |
| R12 | Qubes 風 macOS multi-user 分離 | TCC ダイアログ頻発で運用負荷が現実的に厳しい |
| R13 | Annual Frozen Release (年 1 update) | weekly auto-merge は CVE 早期取り込みに有効、philosophical |
| R14 | Dotfiles を 50 人 PR 駆動 | premature、CODEOWNERS overhead、AI 共同編集が定常化したら再考 |
| R15 | event-driven sync (3.4 弱体版) | survivor 5 (GitOps + multi-host) に統合 |
| R16 | Sneakernet bundle 単独 | survivor 6 (MEL) に統合 |
| R17 | dangerous-command theme switch / AI pane 紫枠 | scope 小さいが具体価値あり → brainstorm 候補として保留 |
| R18 | dotfiles を ephemeral 実行環境発射台へ (Codespaces 等) | 価値は高いが 5 軸 focus と直接結びつき弱、別 ideation トピック |
