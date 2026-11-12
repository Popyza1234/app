#!/usr/bin/env bash
# Prepare this project and push it to YOUR GitHub repository (no Mac needed).
# Usage: ./scripts/push-to-github.sh https://github.com/<user>/<repo>.git
#
# No token is handled by this script: authentication is delegated to Git
# Credential Manager / your normal git credentials at the push prompt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REMOTE="${1:?usage: push-to-github.sh https://github.com/<user>/<repo>.git}"

command -v git >/dev/null 2>&1 || { echo "error: git not found" >&2; exit 1; }

case "$REMOTE" in
  https://github.com/*|git@github.com:*|ssh://git@github.com/*) ;;
  *) echo "error: expected a GitHub repository URL, got: $REMOTE" >&2; exit 1 ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "==> Initializing git repository (branch: main)"
  if ! git init -b main >/dev/null 2>&1; then
    # Fallback for Git older than 2.28, which has no `git init -b`.
    git init >/dev/null
    git checkout -b main >/dev/null 2>&1 || git branch -M main
  fi
fi

BRANCH="$(git branch --show-current)"
if [ "$BRANCH" != "main" ]; then
  echo "==> Renaming branch to main"
  git branch -M main
fi

echo "==> Staging project files"
git add -A
# Keep shell scripts executable in the commit even on filesystems that do not
# preserve the +x bit (Git for Windows, FAT/exFAT, ZIP extraction).
for f in scripts/*.sh; do
  if [ -f "$f" ]; then
    git update-index --chmod=+x "$f"
  fi
done

# Safety: never commit or push signing material or local secrets.
if git diff --cached --name-only | grep -Eiq '\.(p12|cer|pem|key|mobileprovision)$|(^|/)\.env($|\.)'; then
  echo "error: signing material or .env is staged; remove it before pushing." >&2
  exit 1
fi
git ls-files --error-unmatch .github/workflows/build-unsigned-ipa.yml >/dev/null 2>&1 || {
  echo "error: CI workflow is not tracked (check .gitignore exceptions)." >&2
  exit 1
}
git ls-files --error-unmatch scripts/build-unsigned-ipa.sh >/dev/null 2>&1 || {
  echo "error: build script is not tracked." >&2
  exit 1
}

if ! git diff --cached --quiet; then
  echo "==> Committing project"
  # Local-only identity: does not touch your global git config.
  git -c user.name="3105 local" -c user.email="local@3105.invalid" \
    commit -q -m "Enable all iOS versions and add no-Mac IPA build tooling"
else
  echo "==> Nothing to commit (working tree is clean)"
fi

git rev-parse --verify HEAD >/dev/null 2>&1 || {
  echo "error: there is no commit to push." >&2
  exit 1
}

if git remote get-url origin >/dev/null 2>&1; then
  CURRENT="$(git remote get-url origin)"
  if [ "$CURRENT" != "$REMOTE" ]; then
    echo "==> Updating origin: $CURRENT -> $REMOTE"
    git remote set-url origin "$REMOTE"
  fi
else
  echo "==> Adding origin $REMOTE"
  git remote add origin "$REMOTE"
fi

echo "==> Pushing main (authenticate with Git Credential Manager / a PAT when prompted)"
if ! git push -u origin main; then
  echo "error: push rejected. If the remote already has commits, run:" >&2
  echo "       git pull --rebase origin main && git push -u origin main" >&2
  echo "       or recreate the GitHub repository completely empty (no README/license/.gitignore)." >&2
  exit 1
fi

echo
echo "==> Done. Next:"
echo "    1. Open your repository's Actions tab"
echo "    2. Actions > Build unsigned IPA > Run workflow (the push to main also triggers it)"
echo "    3. Download artifact '3105-unsigned-ipa' -> 3105-unsigned.ipa"
echo "    4. Sign it (ESign on-device, or scripts/resign-windows-zsign.ps1) before installing"
echo "    The artifact is UNSIGNED; it cannot be installed until it is signed with"
echo "    your own authorized enterprise certificate and matching provisioning profile."
