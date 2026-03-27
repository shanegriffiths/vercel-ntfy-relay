#!/bin/bash
# Quick setup script for macOS Vercel deploy notifications
# Run: chmod +x setup.sh && ./setup.sh

set -e

echo "=== Vercel Deploy Notifications - macOS Setup ==="
echo ""

# 1. Install dependencies
echo "Installing ntfy and alerter..."
brew install ntfy 2>/dev/null || echo "ntfy already installed"
brew install vjeantet/tap/alerter 2>/dev/null || echo "alerter already installed"

# 2. Generate topic name
TOPIC="vercel-deploy-$(openssl rand -hex 6)"
echo ""
echo "Your ntfy topic: $TOPIC"
echo "Save this — you'll need it for the Cloudflare Worker config too."

# 3. Download Vercel icon and make it circular
echo ""
echo "Downloading Vercel icon..."
mkdir -p ~/.config/ntfy-icons
node -e "
fetch('https://assets.vercel.com/image/upload/front/favicon/vercel/180x180.png')
  .then(r => r.arrayBuffer())
  .then(buf => {
    require('fs').writeFileSync(
      process.env.HOME + '/.config/ntfy-icons/vercel.png',
      Buffer.from(buf)
    );
    console.log('Saved vercel.png');
  });
"

# Make circular if ImageMagick is available
if command -v magick &>/dev/null; then
  magick ~/.config/ntfy-icons/vercel.png \
    -resize 180x180 \
    \( +clone -threshold -1 -negate -fill white -draw "circle 90,90 90,0" \) \
    -alpha off -compose copy_opacity -composite \
    ~/.config/ntfy-icons/vercel-circle.png
  echo "Created circular icon"
else
  cp ~/.config/ntfy-icons/vercel.png ~/.config/ntfy-icons/vercel-circle.png
  echo "ImageMagick not found — using square icon (install with: brew install imagemagick)"
fi

# 4. Install handler script
echo ""
echo "Installing notification handler..."
cp macos/notify-deploy.sh ~/.config/ntfy-icons/notify-deploy.sh
chmod +x ~/.config/ntfy-icons/notify-deploy.sh

# 5. Configure ntfy subscriber
echo ""
echo "Configuring ntfy subscriber..."
mkdir -p ~/Library/Application\ Support/ntfy
cat > ~/Library/Application\ Support/ntfy/client.yml <<EOF
default-host: https://ntfy.sh

subscribe:
  - topic: $TOPIC
    command: '\$HOME/.config/ntfy-icons/notify-deploy.sh &'
EOF

# 6. Install launchd agent
echo ""
echo "Installing launch agent..."
sed "s|/Users/YOUR_USERNAME|$HOME|g" macos/sh.ntfy.subscriber.plist \
  > ~/Library/LaunchAgents/sh.ntfy.subscriber.plist
launchctl load ~/Library/LaunchAgents/sh.ntfy.subscriber.plist

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Update wrangler.toml with your Cloudflare account_id and NTFY_TOPIC=$TOPIC"
echo "  2. Deploy the worker: wrangler deploy"
echo "  3. Add the worker URL as a webhook in Vercel (Settings → Webhooks)"
echo "     Events: deployment.succeeded, deployment.error"
echo ""
echo "Test with: ntfy publish --title 'Test' $TOPIC 'Hello from Vercel'"
