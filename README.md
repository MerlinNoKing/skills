# Claude Code Skills

A collection of Claude Code skills for data engineering, analytics, and AI workflows.

## Skills

### [`data-explore`](./data-explore/)
Structured data profiling and exploration before building dbt models or transformations. Covers schema discovery, column profiling, distribution analysis, relationship mapping, data quality flagging, and domain inference. Optimized for banking/insurance datasets on Snowflake, Redshift, BigQuery, and generic SQL.

## Usage

To install a skill, copy the skill folder into your Claude Code skills directory:

```bash
cp -r data-explore ~/.claude/skills/
```

Then invoke it in Claude Code with `/data-explore`.

## Structure

Each skill follows the standard Claude Code skill format:

```
skill-name/
├── SKILL.md          # Skill instructions and workflow
├── scripts/          # Reusable SQL/Python scripts
├── references/       # Reference documentation loaded on demand
└── assets/           # Output templates and assets
```
