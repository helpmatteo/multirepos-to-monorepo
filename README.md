# multirepos-to-monorepo

Merge multiple Git repositories into a single monorepo **while preserving full commit history, tags, and Git LFS objects**.

This Bash script automates the process of:
- importing each repo into its own subfolder,
- auto-creating the target GitHub repo when needed,
- handling tag prefixing to avoid collisions,
- doing robust default branch detection,
- and cleaning up all temporary directories automatically to save disk space.

Perfect for teams migrating from many scattered repos to a single source of truth with a clean, auditable history.

***

## ✨ Features

- **Full history preservation** for each imported repository under its own subfolder.
- **Tag prefixing** (optional) → prevents tag name collisions across repos (e.g. `repoA-v1.0`).
- **Git LFS support** → fetches and preserves large files & LFS pointers.
- **Auto-create target repo** on GitHub (or use an existing one).
- **Robust default branch detection** (`symbolic-ref`, remote HEAD, fallback).
- **Skips empty source repos** gracefully without breaking the run.
- **Initial empty commit** in the monorepo if no commits exist yet.
- **Immediate per-repo cleanup** + final workspace cleanup (`trap cleanup EXIT`) — no leftover temp dirs.
- **Detailed merge commit messages** with source repo & branch info.
- **Safe subdir validation** to prevent path traversal risks.

***

## 🛠 Requirements

- `bash`
- `git`
- [`git-filter-repo`](https://github.com/newren/git-filter-repo) (must be in `$PATH`)
- `jq`
- `git-lfs` (required if `USE_GIT_LFS=true`)
- GitHub Personal Access Token with **`repo`** scope (needed only for auto-creation mode)

***

## 🚀 Quick Start

1. **Clone this repo**
   ```bash
   git clone https://github.com//multirepos-to-monorepo.git
   cd multirepos-to-monorepo
   ```

2. **Configure your migration**
   - Open `merge-repos.sh`
   - Update:
     - `MONOREPO_OWNER` → your GitHub username or organization.
     - `MONOREPO_NAME` → name of the destination monorepo.
     - `REPOS_TO_IMPORT` → list of repos in ` ` format.
   - Example:
     ```bash
     REPOS_TO_IMPORT=(
       "https://github.com/myorg/service-a.git service-a"
       "git@github.com:myorg/libB.git libB"
     )
     ```

3. **Choose target repo mode**
   - **Existing repo:** set `MONOREPO_URL` to HTTPS/SSH clone URL.
   - **Auto-create repo:** leave `MONOREPO_URL` blank and export a GitHub token:
     ```bash
     export GITHUB_TOKEN="ghp_yourtoken"
     ```

4. **Run the script**
   ```bash
   chmod +x merge-repos.sh
   ./merge-repos.sh
   ```

5. **Verify the results**
   - Inspect your monorepo on GitHub — each imported repo will be under its own folder.
   - Tags will appear with prefixes if `PREFIX_TAGS=true`.

***

## ⚙ Configuration Reference

| Variable | Description |
|----------|-------------|
| `MONOREPO_NAME` | Destination repo name |
| `MONOREPO_OWNER` | GitHub username/org |
| `MONOREPO_VISIBILITY` | `private`, `public`, or `internal` |
| `MONOREPO_DEFAULT_BRANCH` | e.g., `main` |
| `MONOREPO_URL` | Existing repo URL (leave blank to auto-create) |
| `PREFIX_TAGS` | `true` = prefix tags with subdir name |
| `USE_GIT_LFS` | `true` = enable Git LFS setup |
| `REPOS_TO_IMPORT` | Array of ` ` |

***

## 🔍 How It Works

1. Creates or reuses the target monorepo (auto-create via GitHub API if enabled).
2. Clones each source repo into a **temporary directory** inside a workspace.
3. Detects the default branch automatically:
   - Tries remote HEAD (`symbolic-ref`), then `git remote show origin`, then common names like `main` or `master`.
4. Optionally renames tags using `-` pattern to prevent collisions.
5. Runs `git filter-repo --to-subdirectory-filter` to move history into its subfolder.
6. Merges into the monorepo branch with `--allow-unrelated-histories`.
7. Pushes monorepo (and tags) to GitHub and sets default branch.
8. Deletes the individual temp clone **immediately** and cleans up the whole temp workspace on exit.

***

## 🛡 Special Cases Handled

- **Empty source repo** → detected & skipped with a warning.
- **Empty monorepo branch** → automatically starts with an empty commit.
- **Existing temp remotes** → removed before reuse to avoid Git conflicts.
- **Unsafe subdir names** (`..` or starting `/`) → skipped to prevent security issues.
- **Temp space cleanup**:
  - Per-repo clone deleted after merge.
  - Global temp workspace deleted on script exit — even on failure.

***

## 📦 Git LFS Usage Notes

- Script runs `git lfs fetch --all` in each source repo.
- Runs `git lfs install --local` in the monorepo after clone.
- Preserves `.gitattributes` patterns inside each imported subdir.
- Does **not** auto-convert large files into LFS — it preserves existing LFS usage.

***

## 🔍 Suggested GitHub “About” Field

> Merge multiple git repositories into one monorepo with full history, tags & LFS. Automates imports, tag prefixing, empty repo handling, and GitHub pushes.

**Topics:**  
`monorepo` `git` `migration` `import` `merge` `git-filter-repo` `lfs` `tags` `history` `cli`

***

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](./LICENSE) file for details.
