# Shipbell 🔔

[![Release](https://img.shields.io/github/v/release/shanegriffiths/shipbell)](https://github.com/shanegriffiths/shipbell/releases) [![Licence](https://img.shields.io/github/license/shanegriffiths/shipbell)](LICENSE)

A ship's bell for when you ship. Native macOS Notification Centre alerts for your Vercel deployments, with custom icons, action buttons, and distinct sounds for success, failure, and cancellation.

![Shipbell notification demo](assets/demo.gif)

## Why this exists

Vercel can email you or ping Slack when a deploy fails. Neither cuts through when you're heads-down in an editor. I wanted the same native notification a Mac app gets: an icon, a sound I recognise without looking, and a button that takes me straight to the deployment. No Electron app, no menu bar clutter, nothing polling in the background eating battery. Shipbell is four small free pieces wired together, and the whole thing costs nothing to run.

## How it works

```
Vercel webhook → Cloudflare Worker → ntfy.sh → ntfy CLI (macOS) → alerter → native notification
```

| Component | Role | Cost |
|---|---|---|
| [Cloudflare Worker](https://workers.cloudflare.com/) | Verifies and parses Vercel's webhook into a formatted notification | Free |
| [ntfy.sh](https://ntfy.sh) | Cloud pub/sub broker that bridges the internet to your Mac | Free |
| [ntfy CLI](https://docs.ntfy.sh/subscribe/cli/) | Local subscriber that listens for messages and runs a command | Free |
| [alerter](https://github.com/vjeantet/alerter) | Renders native macOS notifications with custom icons and buttons | Free |

**Why four components?** Your Mac can't receive webhooks directly (it's behind a firewall). ntfy bridges cloud to local. The Cloudflare Worker verifies the webhook signature and turns Vercel's raw JSON into a clean message. alerter is the only CLI tool that supports custom notification icons on macOS.

## Notifications

| Event | Title | Sound |
|---|---|---|
| Deploy succeeded | ✅ project-name deployed | Glass |
| Deploy failed | 🔥 project-name deploy failed | Basso |
| Deploy cancelled | ⏹️ project-name deploy cancelled | Funk |

Each notification shows the branch name, target (preview/production), and first line of the commit message. Clicking "View Deploy" opens the deployment URL in your browser.

## Setup

Three routes in: the one-command script, doing the Mac side by hand, or handing the whole job to an AI assistant. They all end in the same place.

### Prerequisites

- macOS with Apple Silicon (M1+)
- [Homebrew](https://brew.sh)
- [Node.js](https://nodejs.org) (for the Wrangler CLI)
- A [Cloudflare account](https://dash.cloudflare.com) (free)
- A Vercel account (any plan)

### 1. Set up the Mac side

```bash
git clone https://github.com/shanegriffiths/shipbell.git
cd shipbell
chmod +x macos/setup.sh
./macos/setup.sh
```

This installs ntfy and alerter, downloads the Vercel icon, configures the subscriber, and starts the background agent. It outputs a random topic name. Save it, you'll need it in the next step.

<details>
<summary><strong>Prefer to do it by hand?</strong></summary>

1. Install the tools: `brew install ntfy` and `brew install vjeantet/tap/alerter`
2. Generate a secret topic and note it down: `echo "shipbell-$(openssl rand -hex 6)"`
3. Copy the files into place:

| File | Destination |
|---|---|
| `macos/notify-deploy.sh` | `~/.config/shipbell/notify-deploy.sh` |
| `macos/ntfy-wait-for-network.sh` | `~/.config/shipbell/ntfy-wait-for-network.sh` |
| `macos/client.example.yml` | `~/Library/Application Support/ntfy/client.yml` |
| `macos/com.shipbell.subscriber.plist` | `~/Library/LaunchAgents/com.shipbell.subscriber.plist` |

4. Make both scripts executable (`chmod +x`), put your topic in `client.yml`, and replace `/Users/YOUR_USERNAME` with your home directory in the plist
5. Drop any 180x180 PNG at `~/.config/shipbell/vercel-circle.png` for the notification icon
6. Start the agent: `launchctl load ~/Library/LaunchAgents/com.shipbell.subscriber.plist`

</details>

### 2. Deploy the Cloudflare Worker

```bash
npm install -g wrangler
wrangler login
```

Copy the example config and fill in your values:

```bash
cp wrangler.toml.example wrangler.toml
```

Edit `wrangler.toml`:
- Set `account_id` to your Cloudflare account ID (find it with `wrangler whoami`)
- Set `NTFY_TOPIC` to the topic name from step 1

`wrangler.toml` is gitignored, so your values stay local.

```bash
wrangler deploy
```

Note the deployed URL (e.g. `https://shipbell.your-account.workers.dev`).

### 3. Add the webhook in Vercel

1. Vercel dashboard → **Settings → Webhooks**
2. **Endpoint URL**: your Cloudflare Worker URL
3. **Events**: Deployment Succeeded, Deployment Error, Deployment Cancelled
4. Click **Create**
5. Vercel shows you a **secret** (once, so copy it now). Store it in the Worker:

```bash
wrangler secret put VERCEL_WEBHOOK_SECRET
```

The Worker refuses every request until this secret is set, and rejects anything that isn't signed by Vercel. The same Worker URL works for multiple Vercel accounts, as long as they share the webhook secret.

### 4. Test

```bash
# Send a test notification directly
ntfy publish --title "✅ my-app deployed" YOUR_TOPIC "🌱 main  →  production"
```

Or push a commit to any connected Vercel project and wait for the deploy.

### Or: hand it to an AI assistant

Working with Claude Code, Cursor, or similar? Paste this prompt and it will do the setup for you, pausing where your input is genuinely needed (browser logins and the webhook secret):

> **Set up Shipbell: native macOS notifications for Vercel deployments.**
>
> Use the reference implementation at https://github.com/shanegriffiths/shipbell. It contains the Cloudflare Worker code, macOS notification handler script, ntfy config, launchd plist, and a one-command setup script.
>
> I want native macOS Notification Centre alerts whenever a Vercel deployment succeeds, fails, or is cancelled. The notification should show a circular Vercel logo icon, the project name, branch, target (preview/production), and first line of the commit message. It should have a "View Deploy" button that opens the deployment URL in my browser and a "Dismiss" button. Different sounds for success (Glass), failure (Basso), and cancelled (Funk).
>
> **Architecture:** Vercel webhook → Cloudflare Worker (verifies signature, formats message) → ntfy.sh (free pub/sub broker) → ntfy CLI subscriber (macOS launchd agent) → alerter (native notification with custom icon and action buttons).
>
> **Setup steps:**
> 1. Clone the repo and run `macos/setup.sh` (installs ntfy and alerter via Homebrew, downloads the Vercel icon, configures the subscriber, starts the launchd agent). Note the random topic name it prints
> 2. Install Wrangler (`npm install -g wrangler`) and log in: `wrangler login` opens a browser, so I need to approve that myself. Then `cp wrangler.toml.example wrangler.toml`, set `account_id` (from `wrangler whoami`) and `NTFY_TOPIC` to the topic from step 1, and deploy with `wrangler deploy`
> 3. Add the Worker URL as a webhook in the Vercel dashboard (Settings → Webhooks) for deployment succeeded, error, and canceled events. Vercel shows the webhook secret exactly once at creation, so remind me to copy it right away. Store it with `wrangler secret put VERCEL_WEBHOOK_SECRET` (required: the Worker rejects unsigned requests)
> 4. Verify: `ntfy publish --title "Test" <topic> "Hello"` should pop a native notification. A real deploy tests the full chain
>
> **Gotchas the repo already handles:** webhook signature verification is mandatory (HMAC-SHA1, constant-time compare), ntfy topics are public (the random hex suffix is what keeps yours private), HTTP headers can't contain emoji (the Worker uses ntfy's JSON publishing API instead), alerter uses kebab-case flags (`--close-label` not `--closeLabel`), macOS Big Sur+ renders actions in an "Options" dropdown not inline buttons (system limitation), the launchd agent needs explicit PATH and HOME environment variables to find alerter, and the subscriber restarts every 10 minutes because macOS sleep/wake silently kills the HTTP stream.
>
> **Gotchas for you, the agent:** `wrangler login` and `wrangler secret put` are interactive and will hang a sandboxed shell. Ask me to run the login myself, and store the secret either by having me paste it into `wrangler secret put VERCEL_WEBHOOK_SECRET` in my own terminal, or non-interactively via `wrangler secret bulk` with a JSON file of `{"VERCEL_WEBHOOK_SECRET":"..."}` (delete the file afterwards). Run deploys with `CI=true` so Wrangler never blocks on a prompt. If no notification appears after setup, check System Settings → Notifications → Terminal is allowed with the "Persistent" alert style.

## Security

- **Webhook signatures are verified and required.** Every request must carry a valid `x-vercel-signature` (HMAC-SHA1 over the raw body, compared in constant time). Without the secret configured, the Worker returns an error rather than relaying anything. This stops anyone who finds your Worker URL from pushing fake notifications to your Mac.
- **The Worker's responses give nothing away.** No topic name, no upstream response bodies. Errors are logged to the Worker console (visible via `wrangler tail`), never echoed to the caller.
- **ntfy topics are public by design.** Anyone who guesses the name can read or write to a topic, which is why the setup script generates a random hex suffix. For stricter control, use [ntfy access tokens](https://docs.ntfy.sh/publish/#access-tokens): reserve the topic, then `wrangler secret put NTFY_TOKEN` so the Worker authenticates when publishing.
- **The click URL is validated on the Mac.** The notification handler only passes `https://` URLs to `open`, so a message with a `file://` or custom app scheme goes nowhere.
- **Secrets never live in the repo.** `wrangler.toml` is gitignored; the webhook secret and ntfy token are stored as Wrangler secrets, not vars.

## Customisation

### Notification sounds

Edit the `case` statement in `notify-deploy.sh`. Available macOS sounds:

```
Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
```

### Custom icon

Replace `~/.config/shipbell/vercel-circle.png` with any 180x180 PNG.

### Self-hosted ntfy

Set `NTFY_URL` in `wrangler.toml` and `default-host` in `client.yml` to your own ntfy server.

### Multiple projects

No extra setup needed. The Worker extracts the project name from Vercel's payload, so every project using the same webhook shows its own name in the notification title.

## Architecture notes

- **ntfy.sh free tier** allows around 250 messages a day, which is plenty for deploy notifications.
- **macOS Big Sur and later** render third-party notification actions in an "Options" dropdown, not as inline stacked buttons. That's a system-level decision, not something apps can change. [More context](https://support.apple.com/guide/mac-help/get-notifications-mchl2fb1258f/mac).
- **alerter's `--app-icon`** relies on a private macOS API. If a future macOS update breaks it, notifications still work, just with the default Terminal icon.
- **The launchd agent** auto-starts on login, restarts if the process dies, and restarts the subscriber every 10 minutes because macOS sleep/wake can silently kill the HTTP stream without ntfy noticing. Logs live at `~/Library/Logs/shipbell.log` and `~/Library/Logs/shipbell.err`.

## Troubleshooting

| Issue | Fix |
|---|---|
| No notifications | Check System Settings → Notifications → Terminal is enabled with "Persistent" alert style |
| Subscriber not running | `launchctl list \| grep shipbell`. If it's missing: `launchctl load ~/Library/LaunchAgents/com.shipbell.subscriber.plist` |
| Worker returns "Relay not configured" | Set the webhook secret: `wrangler secret put VERCEL_WEBHOOK_SECRET` |
| Worker returns "Invalid signature" | The secret doesn't match the webhook. Re-copy it from Vercel (Settings → Webhooks) and set it again |
| Rate limited by ntfy.sh | Free tier is ~250 msgs/day. Wait for the daily reset, use a [paid plan](https://ntfy.sh/#pricing), or set an `NTFY_TOKEN` |
| SSL error hitting Worker | New worker subdomains take 2-3 minutes to provision SSL. Wait and retry |
| No custom icon | Verify `~/.config/shipbell/vercel-circle.png` exists. alerter's icon support uses a private API |

## License

MIT
