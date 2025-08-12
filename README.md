# multirepos-to-monorepo

Merge multiple Git repositories into a single monorepo while preserving full history, tags, and Git LFS.  
This Bash script automates imports into subfolders using `git-filter-repo`, handles empty source repos, prefixes tags to avoid collisions, and can auto-create the destination GitHub repo.  
Ideal for teams migrating from many repos to one monorepo with clean history and minimal manual steps.

---

## ✨ Features
- **Full history preservation** for each imported repo under its own subfolder.
- **Optional tag prefixing** to avoid collisions across repos (e.g., `repoA-v1.0`).
- **Git LFS support** – fetches LFS objects, preserves `.gitattributes`.
- **Auto-create** destination GitHub repo (or use existing).
- Robust **default branch detection**.
- Skips empty source repos without breaking.
- Creates **initial empty commit** if monorepo branch has no commits.
- Removes old temporary remotes before each import.
- Pushes merged results and tags, sets default branch via GitHub API.

---

## 🛠 Requirements
- `bash`
- `git`
- [`git-filter-repo`](https://github.com/newren/git-filter-repo)
- `jq`
- `git-lfs` (if importing LFS repos)
- GitHub Personal Access Token with **`repo`** scope (if auto-creating repo)

---

## 🚀 Quick Start

1. **Clone this project**
```
git clone https://github.com/<your-username>/multirepos-to-monorepo.git
cd multirepos-to-monorepo
```

3. **Configure**
- Open `monorepo-import.sh`
- Set:
  - `MONOREPO_OWNER` — your GitHub username or org
  - `MONOREPO_NAME` — defaults to `multirepos-to-monorepo`
  - `REPOS_TO_IMPORT` — your repos in the format: `<git_url> <subdir>`

3. **Choose destination repo mode**
- **Existing:** set `MONOREPO_URL` to HTTPS/SSH clone URL
- **Auto-create:** export a GitHub token, leave `MONOREPO_URL` empty
  ```
  export GITHUB_TOKEN="ghp_yourtoken"
  ```

4. **Run**
  ```
  chmod +x monorepo-import.sh
  ./monorepo-import.sh
  ```

5. **Verify**
- Check your monorepo on GitHub — imported repos will appear as folders.
- Tags will be prefixed if enabled.

---

## ⚙ Configuration Reference

| Variable | Description |
|----------|-------------|
| `MONOREPO_NAME` | Destination repo name |
| `MONOREPO_OWNER` | GitHub username/organisation |
| `MONOREPO_VISIBILITY` | `private`, `public`, or `internal` |
| `MONOREPO_DEFAULT_BRANCH` | e.g., `main` |
| `MONOREPO_URL` | Use this existing repo instead of creating |
| `PREFIX_TAGS` | `true` to prefix tags with subdir name |
| `USE_GIT_LFS` | `true` to enable Git LFS setup |
| `REPOS_TO_IMPORT` | Array of `<git_url> <subdir>` entries |

---

## 🔍 How It Works
1. Clones each source repo into a temporary folder.
2. Detects and checks out the default branch.
3. Optionally renames tags to avoid conflicts.
4. Uses `git filter-repo --to-subdirectory-filter` to move all files/history into a subfolder.
5. Merges into the monorepo with `--allow-unrelated-histories`.
6. Pushes to GitHub and sets default branch.

---

## 🛡 Handling Special Cases

- **Empty monorepo branch** → script creates & pushes an initial commit automatically.
- **Existing temp remotes** → removed before reuse to avoid errors.
- **Empty source repo** → detected and skipped with a message.
- **Merge conflicts** → the script stops, prompts you to resolve, then re-run.

---

## 📦 Git LFS Notes
- Runs `git lfs fetch --all` in source repos.
- Runs `git lfs install --local` in the monorepo.
- Preserves `.gitattributes` patterns under each subdir.

---

## 🔍 SEO-friendly GitHub “About”
> Merge multiple Git repositories into a monorepo with history, tags, and LFS using git-filter-repo. Automates imports, tag prefixing, empty-repo handling, and GitHub pushes.

** Topics:**  
`monorepo` `git` `migration` `import` `merge` `git-filter-repo` `lfs` `tags` `history` `cli`

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](./LICENSE) file for details.
