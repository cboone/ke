# GitHub Copilot Instructions for ke

For full project conventions, see AGENTS.md in the repository root.

## PR Review

- **Done plans are historical records**: Files in `docs/plans/done/` are completed plan documents preserved for reference. They may not match the final implementation. Do not flag discrepancies between done plan content and the actual codebase.
- **Prettier `printWidth: 10000` is intentional**: This project uses a high `printWidth` in `.prettierrc.json` to prevent Prettier from wrapping lines. Combined with `proseWrap: preserve` for Markdown, this preserves author line breaks. Do not suggest reducing printWidth to 80 or 120.
- **README documents planned CLI interface**: This project uses README-driven development. The README usage examples describe the target CLI commands and may be written before the implementation exists. Do not flag planned commands as misleading.
- **Homebrew formula uses placeholder SHA256 values**: Before the first release, the formula contains placeholder SHA256 digests (e.g., `SHA256_FOR_DARWIN_AMD64`). These are intentional scaffolding that will be replaced when release artifacts are built. Do not flag placeholder checksums.
- **`paths-ignore: "*.md"` does not affect test files**: In GitHub Actions, the `*.md` glob matches only root-level Markdown files. It does not match files in subdirectories like `tests/scrut/*.md`. Do not flag this pattern as ignoring test files.
