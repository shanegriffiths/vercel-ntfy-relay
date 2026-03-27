# Vercel Deploy Notifications for macOS

Native macOS Notification Centre alerts for Vercel deployments — with custom icons, action buttons, and distinct sounds for success, failure, and cancellation.

![notification-demo](https://github.com/user-attachments/assets/placeholder)

## How it works

```
Vercel webhook → Cloudflare Worker → ntfy.sh → ntfy CLI (macOS) → alerter → native notification
```

| Component | Role | Cost |
|---|---|---|
| [Cloudflare Worker](https://workers.cloudflare.com/) | Parses Vercel's webhook JSON into a formatted notification | Free |
| [ntfy.sh](https://ntfy.sh) | Cloud pub/sub message broker — bridges the internet to your Mac | Free |
| [ntfy CLI](https://docs.ntfy.sh/subscribe/cli/) | Local subscriber that listens for messages and runs a command | Free |
| [alerter](https://github.com/vjeantet/alerter) | Renders native macOS notifications with custom icons and buttons | Free |

**Why four components?** Your Mac can't receive webhooks directly (it's behind a firewall). ntfy.sh bridges cloud to local. The Cloudflare Worker transforms Vercel's raw JSON into a clean message. alerter is the only CLI tool that supports custom notification icons on macOS.

## Notifications

| Event | Title | Sound |
|---|---|---|
| Deploy succeeded | ✅ project-name deployed | Glass |
| Deploy failed | 🔥 project-name deploy failed | Basso |
| Deploy cancelled | ⏹️ project-name deploy cancelled | Funk |

Each notification shows the branch name, target (preview/production), and first line of the commit message. Clicking "View Deploy" opens the deployment URL in your browser.

## Quick setup

### Prerequisites

- macOS with Apple Silicon (M1+)
- [Homebrew](https://brew.sh)
- [Node.js](https://nodejs.org) (for icon download and Wrangler CLI)
- A [Cloudflare account](https://dash.cloudflare.com) (free)
- A Vercel account (any plan)

### 1. Clone and run the setup script

```bash
git clone https://github.com/studiobrio/vercel-ntfy-relay.git
cd vercel-ntfy-relay
chmod +x macos/setup.sh
./macos/setup.sh
```

This installs ntfy + alerter, downloads the Vercel icon, configures the subscriber, and starts the background agent. It outputs a random topic name — save it.

### 2. Deploy the Cloudflare Worker

```bash
npm install -g wrangler
wrangler login
```

Edit `wrangler.toml`:
- Set `account_id` to your Cloudflare account ID (find with `wrangler whoami`)
- Set `NTFY_TOPIC` to the topic name from step 1

```bash
wrangler deploy
```

Note the deployed URL (e.g. `https://vercel-ntfy-relay.your-account.workers.dev`).

### 3. Add the webhook in Vercel

1. Vercel dashboard → **Settings → Webhooks**
2. **Endpoint URL**: your Cloudflare Worker URL
3. **Events**: Deployment Succeeded, Deployment Error
4. Click **Create**

The same Worker URL works for multiple Vercel accounts.

### 4. Test

```bash
# Send a test notification directly
ntfy publish --title "✅ my-app deployed" YOUR_TOPIC "🌱 main  →  production"
```

Or push a commit to any connected Vercel project and wait for the deploy.

## Manual setup

If you prefer not to use the setup script, see the individual config files in the `macos/` directory:

| File | Destination |
|---|---|
| `macos/notify-deploy.sh` | `~/.config/ntfy-icons/notify-deploy.sh` |
| `macos/client.example.yml` | `~/Library/Application Support/ntfy/client.yml` |
| `macos/sh.ntfy.subscriber.plist` | `~/Library/LaunchAgents/sh.ntfy.subscriber.plist` |

## Customisation

### Notification sounds

Edit the `case` statement in `notify-deploy.sh`. Available macOS sounds:

```
Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
```

### Custom icon

Replace `~/.config/ntfy-icons/vercel-circle.png` with any 180x180 PNG.

### Multiple projects

No extra setup needed — the Worker extracts the project name from Vercel's payload. All projects using the same webhook show their name in the notification title.

## Architecture notes

- **ntfy topics are public** — anyone who guesses the name can read/write. The setup script generates a random hex suffix for privacy. For stricter security, use [ntfy access tokens](https://docs.ntfy.sh/publish/#access-tokens).
- **ntfy.sh free tier** allows ~250 messages/day — more than enough for deploy notifications.
- **macOS Big Sur+** renders third-party notification actions in an "Options" dropdown, not as inline stacked buttons. This is a system-level UI decision, not configurable by apps. [More context](https://support.apple.com/guide/mac-help/get-notifications-mchl2fb1258f/mac).
- **alerter's `--app-icon`** relies on a private macOS API. If a future macOS update breaks it, notifications will still work — just with the default Terminal icon.
- **The launchd agent** auto-starts on login and restarts if the process dies. Check logs at `/tmp/ntfy-subscriber.log` and `/tmp/ntfy-subscriber.err`.

## Troubleshooting

| Issue | Fix |
|---|---|
| No notifications | Check System Settings → Notifications → Terminal is enabled with "Persistent" alert style |
| Subscriber not running | `launchctl list \| grep ntfy` — if missing, `launchctl load ~/Library/LaunchAgents/sh.ntfy.subscriber.plist` |
| Rate limited by ntfy.sh | Free tier is ~250 msgs/day. Wait for daily reset, or use a [paid plan](https://ntfy.sh/#pricing) |
| SSL error hitting Worker | New worker subdomains take 2-3 minutes to provision SSL. Wait and retry |
| No custom icon | Verify `~/.config/ntfy-icons/vercel-circle.png` exists. alerter's icon support uses a private API |

## License

MIT
