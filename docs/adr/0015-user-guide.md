# ADR 0015: The user guide

Status: Accepted (2026-09-19)

## Context

Every Apple app on the Mac comes with its user guide: Help ▸ *App* Help opens it in the Help Viewer, searchable, in the user's language, whether or not the Mac is online. A guide that lives only on a website, or drifts from the app it describes, is not that. iPhone and iPad apps have no Help Viewer, so their users need the same guide somewhere they can reach.

## Decision

1. The user guide MUST be written once, in Markdown, in `docs/guide/en` and `docs/guide/it`, with exactly the same pages in both languages. It is task-based: one task per page, numbered steps, interface elements named exactly as the app shows them, a "See also" at the end.
2. The Mac app MUST ship it as an Apple Help Book, `Help/ChitarraTune.help` (type 3, a table of contents, light and dark appearance, a Core Spotlight search index per language), built from the Markdown by `Scripts/build-help.py` and committed. The book MUST be exactly what the guide produces.
3. The book ships in the Mac app only (a platform filter), is declared by `CFBundleHelpBookFolder` and `CFBundleHelpBookName`, and opens from Help ▸ ChitarraTune Help and ⌘?.
4. The book MUST NOT load anything from the network: no remote images, fonts, scripts, links or knowledge-base URL (ADR 0003).
5. On iPhone and iPad, Settings ▸ About MUST link to the same guide, in the app's language.
6. A change to what the app shows or does MUST update the guide in the same commit, in both languages.

## Consequences

- The guide reads on GitHub and in the Help Viewer from one source; translating a page is editing one Markdown file.
- The Markdown stays within the subset the build script understands; anything else fails the build.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/UserGuideTests.swift` (the book matches the guide, both languages, offline, wiring in the project, the Info.plist and the Help menu).
- `Scripts/build-help.py` (`--check`) and `Scripts/release-check.sh` (the finished app ships the book in both languages, named in its Info.plist, offline).
