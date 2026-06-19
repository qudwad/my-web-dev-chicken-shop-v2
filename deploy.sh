#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
ZELLIJ_VERSION="v0.44.3"
ZELLIJ_URL="https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz"
SSHX_URL="https://sshx.s3.amazonaws.com/sshx-x86_64-unknown-linux-musl.tar.gz"
SESSION_NAME="sshx-session"
WORKDIR="/tmp/zellij-sshx-setup"

# ─── Prep work directory ─────────────────────────────────────────────────────
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ─── Download & extract Zellij ───────────────────────────────────────────────
echo "[*] Downloading Zellij ${ZELLIJ_VERSION}..."
curl -fsSL "$ZELLIJ_URL" -o zellij.tar.gz
tar -xzf zellij.tar.gz
chmod +x zellij
echo "[*] Zellij binary ready at $WORKDIR/zellij"

# ─── Download & extract SSHX ─────────────────────────────────────────────────
echo "[*] Downloading SSHX..."
curl -fsSL "$SSHX_URL" -o sshx.tar.gz
tar -xzf sshx.tar.gz
chmod +x sshx
echo "[*] SSHX binary ready at $WORKDIR/sshx"

# ─── Add binaries to PATH for this script ────────────────────────────────────
export PATH="$WORKDIR:$PATH"

# ─── Create a headless (background) Zellij session ───────────────────────────
echo "[*] Creating headless Zellij session: $SESSION_NAME"
"$WORKDIR/zellij" attach --create-background "$SESSION_NAME"

# ─── Open a new pane inside that session running SSHX ────────────────────────
# new-pane returns the pane ID (e.g. "terminal_1") on stdout
echo "[*] Launching SSHX in a new Zellij pane..."
PANE_ID=$("$WORKDIR/zellij" --session "$SESSION_NAME" action new-pane \
    --name "sshx" \
    -- "$WORKDIR/sshx")

echo "[*] SSHX pane ID: $PANE_ID"

# ─── Wait for SSHX to start and print its URL ────────────────────────────────
echo "[*] Waiting for SSHX to start up..."
sleep 4

# ─── Dump the pane's output to capture the URL ───────────────────────────────
echo "[*] Capturing SSHX output..."
SSHX_OUTPUT=$("$WORKDIR/zellij" --session "$SESSION_NAME" action dump-screen \
    --pane-id "$PANE_ID" --full 2>/dev/null || true)

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  SSHX OUTPUT:"
echo ""
echo "$SSHX_OUTPUT"
echo ""
echo "═══════════════════════════════════════════════════════"

# ─── Try to extract a URL from the output ────────────────────────────────────
SSHX_URL=$(echo "$SSHX_OUTPUT" | grep -oE 'https?://[^[:space:]]+' | head -1)
if [ -n "$SSHX_URL" ]; then
    echo ""
    echo "  >>> SSHX URL: $SSHX_URL <<<"
else
    echo ""
    echo "  (No URL pattern found in output — see full output above)"
fi

echo ""
echo "  Session  : $SESSION_NAME"
echo "  To attach: $WORKDIR/zellij attach $SESSION_NAME"
echo "  Pane ID  : $PANE_ID"
echo "  Zellij   : $WORKDIR/zellij"
echo "  SSHX     : $WORKDIR/sshx"
