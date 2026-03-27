# GitHub Copilot Instructions for ke

For full project conventions, see AGENTS.md in the repository root.

## PR Review

- **Done plans are historical records**: Files in `docs/plans/done/` are completed plan documents preserved for reference. They may not match the final implementation. Do not flag discrepancies between done plan content and the actual codebase.
- **Prettier `printWidth: 10000` is intentional**: This project uses a high `printWidth` in `.prettierrc.json` to prevent Prettier from wrapping lines. Combined with `proseWrap: preserve` for Markdown, this preserves author line breaks. Do not suggest reducing printWidth to 80 or 120.
