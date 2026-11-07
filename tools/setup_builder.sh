#!/usr/bin/env bash
# Build on GitHub:  bash tools/setup_builder.sh   (owner or Claude)
# First run: makes Kodok-Kejepit/ascendant-builder public with a builder description and
# stores the Android signing key as a secret. Every run: pushes a one-commit snapshot of the
# current branch as `main` (author = your GitHub noreply address, so your private email is
# never published; local history is untouched). GitHub Actions then builds the APK +
# Windows version and puts them on the "latest" release.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="Kodok-Kejepit/ascendant-builder"
DESC="Repo khusus builder/CI untuk game ASCENDANT: GitHub Actions membangun APK Android & versi Windows otomatis (lihat Releases → latest). Bukan repo pengembangan utama."

if ! gh repo view "$REPO" >/dev/null 2>&1; then
	gh repo create "$REPO" --public --description "$DESC"
fi
if [ "$(gh repo view "$REPO" --json visibility -q .visibility)" != "PUBLIC" ]; then
	gh repo edit "$REPO" --visibility public --accept-visibility-change-consequences
fi
gh repo edit "$REPO" --description "$DESC" >/dev/null
if [ -f "$HOME/.android/debug.keystore" ] && ! gh secret list -R "$REPO" | grep -q ANDROID_DEBUG_KEYSTORE_B64; then
	base64 -w0 "$HOME/.android/debug.keystore" | gh secret set ANDROID_DEBUG_KEYSTORE_B64 -R "$REPO"
fi
# Push over HTTPS with the gh token (works after a reboot without unlocking the SSH key).
URL="https://github.com/$REPO.git"
GITGH=(git -c credential.helper= -c 'credential.helper=!gh auth git-credential')

LOGIN="$(gh api user -q .login)"
NOREPLY="$(gh api user -q .id)+${LOGIN}@users.noreply.github.com"
BRANCH="$(git branch --show-current)"
SHA="$(git rev-parse --short HEAD)"
# The snapshot sits on top of the builder's current main: a plain fast-forward push.
PARENT_ARGS=()
if "${GITGH[@]}" fetch -q "$URL" main 2>/dev/null; then
	PARENT_ARGS=(-p "$(git rev-parse FETCH_HEAD)")
fi
SNAP="$(GIT_AUTHOR_EMAIL="$NOREPLY" GIT_COMMITTER_EMAIL="$NOREPLY" \
	git commit-tree "HEAD^{tree}" "${PARENT_ARGS[@]}" -m "build: snapshot ${BRANCH} @ ${SHA}")"
"${GITGH[@]}" push "$URL" "${SNAP}:refs/heads/main"

echo
echo "Selesai. Proses build: https://github.com/$REPO/actions"
echo "APK + Windows (±10-15 menit lagi): https://github.com/$REPO/releases/tag/latest"
