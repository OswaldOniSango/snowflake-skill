## Installation

### Prerequisites

- **Node.js** (includes **npm** and **npx**).
- Access to the **`skills`** command (invoked via `npx`).

You can verify everything is installed with:

```bash
node --version
npm --version
npx --version
```

If you don't have Node.js, install it from https://nodejs.org/ (LTS recommended).

### Install the skill

Run **one** of these options:

```bash
# 1) Install from the GitHub repo (recommended)
npx skills add oswaldonisango/snowflake-skill

# 2) Install from URL (raw.github.com)
npx skills add https://raw.github.com/oswaldonisango/snowflake-skill/main/SKILL.md

# 3) Install from URL (raw.githubusercontent.com)
npx skills add https://raw.githubusercontent.com/oswaldonisango/snowflake-skill/main/SKILL.md
```

### Verify installation (optional)

List your installed skills and confirm that `snowflake` appears:

```bash
npx skills list
```