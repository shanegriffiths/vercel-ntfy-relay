#!/bin/bash
# Shipbell — one-command macOS setup
# Run from the repo root: ./macos/setup.sh

set -e

echo "=== Shipbell — macOS Setup ==="
echo ""

# 1. Install dependencies
echo "Installing ntfy and alerter..."
command -v ntfy >/dev/null 2>&1 || brew install ntfy
command -v alerter >/dev/null 2>&1 || brew install vjeantet/tap/alerter

# 2. Generate topic name
TOPIC="shipbell-$(openssl rand -hex 6)"
echo ""
echo "Your ntfy topic: $TOPIC"
echo "Save this — you'll need it for the Cloudflare Worker config too."

# 3. Download Vercel icon and make it circular
echo ""
echo "Downloading Vercel icon..."
mkdir -p ~/.config/shipbell
curl -fsSL -o ~/.config/shipbell/vercel.png \
  "https://assets.vercel.com/image/upload/front/favicon/vercel/180x180.png"
echo "Saved vercel.png"

# Make circular if ImageMagick is available
if command -v magick &>/dev/null; then
  magick ~/.config/shipbell/vercel.png \
    -resize 180x180 \
    \( +clone -threshold -1 -negate -fill white -draw "circle 90,90 90,0" \) \
    -alpha off -compose copy_opacity -composite \
    ~/.config/shipbell/vercel-circle.png
  echo "Created circular icon"
else
  cp ~/.config/shipbell/vercel.png ~/.config/shipbell/vercel-circle.png
  echo "ImageMagick not found — using square icon (install with: brew install imagemagick)"
fi

# 4. Install handler script and network wrapper
echo ""
echo "Installing notification handler..."
cp macos/notify-deploy.sh ~/.config/shipbell/notify-deploy.sh
chmod +x ~/.config/shipbell/notify-deploy.sh
cp macos/ntfy-wait-for-network.sh ~/.config/shipbell/ntfy-wait-for-network.sh
chmod +x ~/.config/shipbell/ntfy-wait-for-network.sh

# 5. Configure ntfy subscriber
echo ""
echo "Configuring ntfy subscriber..."
mkdir -p ~/Library/Application\ Support/ntfy
cat > ~/Library/Application\ Support/ntfy/client.yml <<EOF
default-host: https://ntfy.sh

subscribe:
  - topic: $TOPIC
    command: '\$HOME/.config/shipbell/notify-deploy.sh &'
EOF

# 6. Install launchd agent
echo ""
echo "Installing launch agent..."
launchctl unload ~/Library/LaunchAgents/com.shipbell.subscriber.plist 2>/dev/null || true
sed "s|/Users/YOUR_USERNAME|$HOME|g" macos/com.shipbell.subscriber.plist \
  > ~/Library/LaunchAgents/com.shipbell.subscriber.plist
launchctl load ~/Library/LaunchAgents/com.shipbell.subscriber.plist

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. cp wrangler.toml.example wrangler.toml, then set your account_id and NTFY_TOPIC=$TOPIC"
echo "  2. Deploy the worker: wrangler deploy"
echo "  3. Add the worker URL as a webhook in Vercel (Settings → Webhooks)"
echo "     Events: deployment.succeeded, deployment.error, deployment.canceled"
echo "  4. Store the secret Vercel shows you when creating the webhook:"
echo "     wrangler secret put VERCEL_WEBHOOK_SECRET"
echo ""
echo "Test with: ntfy publish --title 'Test' $TOPIC 'Hello from Shipbell'"
