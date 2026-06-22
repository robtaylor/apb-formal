# Release process

<!--
This template is the lightweight release process companion to the four-document
discipline (Architecture Decision Records, plans, spikes, handoffs). Adjust
the <PROJECT> placeholders, then prune the sections that don't apply.
-->

Lightweight by design. <PROJECT> is a <single-binary | library | service> project; releases are <git tags + a CHANGELOG entry | crates.io / npm / PyPI publications | container images>. <Optionally: no pre-built binaries until/unless that demand surfaces.>

## When to release

Cut a release when:

- A user-visible feature or fix lands that you want consumers to be able to pin against.
- Schema or Command-Line Interface (CLI) changes happened and consumers need a stable reference point.
- A meaningful chunk of work in `docs/plans/` is closed (e.g. a phase exits all criteria).

There is no fixed cadence.

## Versioning

[Semantic Versioning (SemVer)](https://semver.org/), starting once the first numbered release ships. Pre-1.0 versions (`0.x.0`) carry the standard SemVer caveat: minor bumps may include breaking changes; specific stable contracts are documented in their own ADRs and follow stricter rules.

Stable contracts (additive-only; breaking changes require a major bump and a deprecation window):

- `<contract 1>` — `<file:line or doc reference>`, governed by ADR <NNNN>.
- `<contract 2>` — `<file:line or doc reference>`, governed by ADR <MMMM>.

CLI flags, log message formats, and human-readable text outputs are **not** stable parseable contracts; consumers that need to script against them should use the structured contracts above.

## Steps

For maintainers cutting a release:

1. **Verify CI is green** on `main` for all jobs. If a runner is offline, hold the release until it's restored.

2. **Roll the `[Unreleased]` section in [`CHANGELOG.md`](../CHANGELOG.md) into a numbered version block.** Format follows [Keep a Changelog](https://keepachangelog.com/). Update the link references at the bottom. Leave a fresh empty `[Unreleased]` section.

3. **Bump `version`** in your project manifest (`Cargo.toml` / `package.json` / `pyproject.toml` / etc.) and re-build to update the lockfile.

4. **Commit:** `chore: release v<X.Y.Z>` with whatever attribution conventions your project uses.

5. **Tag:** `git tag -a v<X.Y.Z> -m "v<X.Y.Z>"` then `git push --tags`.

6. **Create a release** on the platform of your choice from the tag. Body = the CHANGELOG section for that version.

## What does NOT need to change at release time

- Submodule pins (unless deliberately bumping a vendored dep).
- Long-lived design docs (unless the release changes the design they describe).
- `LICENSE` (unless re-licensing).

## Pre-release checklist (one-time, before the first numbered release)

These items block the first release. As they land, they're checked off in the same Pull Request (PR) that landed them.

- [ ] <First load-bearing release blocker>
- [ ] <Second load-bearing release blocker>
- [ ] All Continuous Integration (CI) jobs green on `main`.
- [ ] License posture confirmed; `NOTICE` file in place if vendoring third-party code.
- [ ] End-to-end test exercising the headline feature.
- [ ] User-facing docs cover the install path.

## Cross-references

- [`CHANGELOG.md`](../CHANGELOG.md) — release log.
- [`docs/adr/<NNNN>-…md`](adr/<NNNN>-…md) — stability contract for `<contract 1>`.
