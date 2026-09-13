Accepted review findings about `CHANGELOG.md`.

### A release heading carries at most one `###` subsection per Keep-a-Changelog category
- **Holds because:** the file is Keep a Changelog, so a reader scans `## [version]` → `### Added` / `### Changed` / `### Fixed` and expects that subsection to be the whole list for that category in that release. A PR that opens its own `### Fixed` at the top of `## [Unreleased]` when one already exists further down splits the list in two, and the second half is read as belonging to an earlier release or missed entirely. A new entry is appended to the existing subsection, not given a new heading.
- **Where:** `CHANGELOG.md`
- **Safe direction:** find the existing subsection under the target release heading and add the bullet there; only create a `###` heading when that category has none. The same rule resolves a merge conflict in this file — union the bullets under one heading, never keep both sides' subheadings (`lode/workflow.md`, Conflicts).
- **Proven by:** no test. `ruby -e` over the file, grouping `###` lines by the preceding `##`, shows the duplicates.
- **Current state:** `## [Unreleased]` is the only release heading in the file — every version through 0.3.1 shipped without one — and it carries two `### Fixed` (lines 10 and 71) and two `### Changed` (59 and 137). The next changelog edit merges rather than adding a third.
- **Origin:** PR #23
