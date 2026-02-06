#Skills repo

##Structure

```
ava-skills/
├── skills/
│   ├── snowflake/
│       ├── SKILL.md
│       ├── references/
│       └── template/
│   └── <new-skill>/
│       ├── SKILL.md
│       ├── references/
│       └── template/
└── .github/workflows/         # CI/CD (auto tag + release)
```

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
# 1) Install
npx skills add oswaldonisango/skill

# 2) Install 
npx skills add oswaldonisango/skill --skill snowflake
## Add more skills as they become available:
## npx skill add oswaldonisango/skill --skill <skill-name>
```

### Verify installation (optional)

List your installed skills and confirm that `snowflake` appears:

```bash
npx skills list
```


## Available skills

| Skill | Install command |
|-------|-----------------|
| **snowflake** (v0.1.0) | `npx skills add oswaldonisango/skill --skill snowflake` |