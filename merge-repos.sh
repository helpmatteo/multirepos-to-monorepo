#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIGURATION
# =========================
MONOREPO_NAME="my-monorepo"
MONOREPO_OWNER="your-github-username-or-org"
MONOREPO_VISIBILITY="private"      # private|public|internal
MONOREPO_DEFAULT_BRANCH="main"

MONOREPO_URL=""  # leave blank to auto-create

WORKDIR="${PWD}/monorepo-work"
MONOREPO_LOCAL="${WORKDIR}/${MONOREPO_NAME}"

# export GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"
GITHUB_API="https://api.github.com"

PREFIX_TAGS=true
USE_GIT_LFS=true

# "<git_url> <subdir>"
REPOS_TO_IMPORT=(
  "https://github.com/owner/repoA.git repoA"
  "https://github.com/owner/repoB.git repoB"
)

# =========================
# PREREQUISITES
# =========================
command -v git >/dev/null || { echo "❌ Git is required"; exit 1; }
command -v git-filter-repo >/dev/null || { echo "❌ git-filter-repo is required"; exit 1; }
command -v jq >/dev/null || { echo "❌ jq is required"; exit 1; }
if [ "$USE_GIT_LFS" = true ]; then
  command -v git-lfs >/dev/null || { echo "❌ git-lfs is required"; exit 1; }
fi
mkdir -p "$WORKDIR"
git config --global --add safe.directory "$MONOREPO_LOCAL" || true

# =========================
# TEMP WORKSPACE & CLEANUP
# =========================
TMP_ROOT="$(mktemp -d "${WORKDIR}/src.XXXXXX")"

cleanup() {
  echo "🧹 Cleaning up temporary directories..."
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

# =========================
# FUNCTIONS
# =========================
create_github_repo_if_needed() {
  if [ -n "$MONOREPO_URL" ]; then
    echo "ℹ️  Using existing monorepo: $MONOREPO_URL"
    return
  fi
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "❌ Need GITHUB_TOKEN to auto-create repo"
    exit 1
  fi
  echo "📦 Creating repo $MONOREPO_OWNER/$MONOREPO_NAME..."
  endpoint="$GITHUB_API/user/repos"
  auth_user=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" "$GITHUB_API/user" | jq -r .login)
  if [[ "$MONOREPO_OWNER" != "$auth_user" ]]; then
    endpoint="$GITHUB_API/orgs/$MONOREPO_OWNER/repos"
  fi

  case "$MONOREPO_VISIBILITY" in
    public)   vis_payload='"private":false' ;;
    internal) vis_payload='"visibility":"internal"' ;; # Requires GHE or eligible plan
    *)        vis_payload='"private":true' ;;
  esac

  payload="{\"name\":\"$MONOREPO_NAME\",$vis_payload}"
  response=$(curl -sS -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$payload" "$endpoint")

  MONOREPO_URL=$(echo "$response" | jq -r .clone_url)
  [ "$MONOREPO_URL" != "null" ] || { echo "❌ Failed creating repo: $response"; exit 1; }
}

clone_monorepo() {
  if [ ! -d "$MONOREPO_LOCAL/.git" ]; then
    git clone "$MONOREPO_URL" "$MONOREPO_LOCAL"
  fi
  cd "$MONOREPO_LOCAL"
  git checkout -B "$MONOREPO_DEFAULT_BRANCH"
  if ! git rev-parse --verify --quiet HEAD >/dev/null; then
    git commit --allow-empty -m "chore: initial empty commit"
    git push -u origin "$MONOREPO_DEFAULT_BRANCH" || true
  fi
  if [ "$USE_GIT_LFS" = true ]; then
    git lfs install --local || true
  fi
}

import_repo() {
  local git_url="$1"
  local subdir="$2"

  # Ensure subdir is safe
  if [[ "$subdir" == /* || "$subdir" == *".."* ]]; then
    echo "❌ Unsafe subdir '$subdir'; skipping."
    return
  fi

  local repo_dir="${TMP_ROOT}/${subdir//\//_}"
  rm -rf "$repo_dir"

  echo "==> Importing $git_url into $subdir/"
  git clone --quiet "$git_url" "$repo_dir"
  cd "$repo_dir"

  if ! git rev-parse --verify --quiet HEAD >/dev/null; then
    echo "⚠️  Skipping $git_url — repository is empty."
    cd "$MONOREPO_LOCAL"
    rm -rf "$repo_dir"
    return
  fi

  if [ "$USE_GIT_LFS" = true ]; then
    git lfs fetch --all || true
  fi

  # Improved default branch detection
  git remote set-head origin -a || true
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  if [ -z "$default_branch" ]; then
    default_branch="$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')"
  fi
  if [ -z "$default_branch" ]; then
    for cand in main master; do
      if git rev-parse --verify --quiet "origin/$cand" >/dev/null; then
        default_branch="$cand"
        break
      fi
    done
  fi
  if [ -z "$default_branch" ]; then
    default_branch="$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed -n '1p' | sed 's#^origin/##')"
  fi
  [ -n "$default_branch" ] || { echo "❌ Could not detect default branch for $git_url"; rm -rf "$repo_dir"; return; }
  git checkout "$default_branch"

  # Prefix tags if needed
  if [ "$PREFIX_TAGS" = true ] && git tag | grep -q .; then
    tagmap="$(mktemp)"
    git tag | while read -r t; do
      [ -n "$t" ] && printf "%s %s-%s\n" "$t" "$subdir" "$t"
    done > "$tagmap"
    git filter-repo --force --tag-rename-file "$tagmap"
    rm -f "$tagmap"
  fi

  # Move repo content into subdir
  git filter-repo --force --to-subdirectory-filter "$subdir"

  cd "$MONOREPO_LOCAL"
  local remote_name="import_$subdir"
  git remote remove "$remote_name" 2>/dev/null || true
  git remote add "$remote_name" "$repo_dir"
  git fetch "$remote_name" --tags
  git merge --allow-unrelated-histories --no-ff \
    -m "Import $subdir from $git_url ($default_branch)" \
    "$remote_name/$default_branch"
  git remote remove "$remote_name"

  # Immediate cleanup of this repo clone
  rm -rf "$repo_dir"
}

# =========================
# MAIN
# =========================
create_github_repo_if_needed
clone_monorepo

for entry in "${REPOS_TO_IMPORT[@]}"; do
  git_url=$(echo "$entry" | awk '{print $1}')
  subdir=$(echo "$entry" | awk '{print $2}')
  if [ -z "$git_url" ] || [ -z "$subdir" ]; then
    echo "⚠️  Skipping malformed REPOS_TO_IMPORT entry: $entry"
    continue
  fi
  import_repo "$git_url" "$subdir"
done

cd "$MONOREPO_LOCAL"
if git tag | grep -q .; then
  git push -u origin "$MONOREPO_DEFAULT_BRANCH" --tags
else
  git push -u origin "$MONOREPO_DEFAULT_BRANCH"
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl -sS -X PATCH \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"default_branch\":\"$MONOREPO_DEFAULT_BRANCH\"}" \
    "$GITHUB_API/repos/$MONOREPO_OWNER/$MONOREPO_NAME" >/dev/null || true
fi

echo "✅ Done — all repos merged and pushed."
