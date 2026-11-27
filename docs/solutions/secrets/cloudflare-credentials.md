# Cloudflare の資格情報は host 専用にし、変更は IaC の CI だけが行う

## 決定

- Cloudflare のリソース変更は IaC の main push から CI で apply する。zone・Access・account member は `gh-intel/gh-intel.com`、Workers の deploy token は同 state の出力を `HikaruEgashira/iac-github` (`cloudflare-workers/`) が repo の Actions secret に配る。CI の API token は AWS Secrets Manager にあり、GitHub OIDC でだけ取り出す (`landing-zone` `bootstrap/cloudflare_ci.tf`)
- 端末には長期の API token を置かない。端末にある Cloudflare の資格情報は次の 2 種類で、どちらも host 専用にする
  - wrangler の OAuth (`~/.config/.wrangler/config/default.toml`)。access token は短命、refresh token は長命
  - cloudflared の Access session (`~/.cloudflared/<org>-org-token`) と app token (`~/.cloudflared/<app>-*-token`)。claude-otel の refresh agent が otel.gh-intel.com の app token を `~/.local/state/claude-otel/token` に書き、collector が送信に使う
- AI agent の sandbox は上記 3 path を read / write とも deny する (`modules/programs/harness/ai-sandbox.nix`)。collector と refresh agent は launchd で sandbox 外に動くので影響しない
- macbook-air は `dotfiles.cloudflare.enable = false`。activation が wrangler の login と otel 以外の Access token を消す。telemetry の送信は維持するため、otel の app token と org session だけ残す

## 根拠

1. **端末に API token が無い。** 2026-11-28 時点の調査で、端末にある Cloudflare の資格情報は wrangler の OAuth と cloudflared の Access token だけだった。変更系の token は CI 側にあり、AWS と同じく「端末は読む、書くのは CI」の形がすでにできている。
2. **broker を作らない。** AWS は sandbox から AWS API を呼ぶ需要があり、STS で短命の資格情報を渡せるので broker を置いた。Cloudflare には STS が無く、短命化の手段は「`/user/tokens` で期限付き token を発行できる親 token」だけになる。親 token は API token 作成権限を持ち、broker が持っても漏洩時の影響は現状の OAuth より大きい。sandbox からの変更需要も IaC の PR で満たせるので、sandbox では Cloudflare を使えないことを既定にする。
3. **既定は読み取り。** 書き込みは IaC の main push だけが行う。host で wrangler を使う場合も、読み取りで足りる作業は `wrangler login --scopes account:read user:read` で login する。書き込みが要る手作業は IaC に寄せる。
4. **macbook-air の Access session を残す理由。** Claude Code の telemetry は gh-intel.com の Access で保護された collector に送る。otel の app token の再発行には org session が要る。

## 運用

- login: host の terminal (sandbox 外) で `wrangler login` / `cloudflared access login <app>` を実行する
- 短命 token が要る自動化を足すときは、親 token を age secret に置かず AWS Secrets Manager に置き、CI か host の broker から `/user/tokens` で TTL 付きの token を発行する
- 固定: `tests/ai-sandbox-deny-lists.sh` が deny path、flake check `thin-client-no-cloudflare` が macbook-air の無効化を検査する
