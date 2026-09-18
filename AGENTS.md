# Repository instructions

This repository contains an embedded astronomical clock for STM32MP157C-DK2,
built with Buildroot on a Debian development host and connected to GitHub.

## Buildroot

- Use a fixed, documented Buildroot version. Before the first build, record an
  exact release or commit and source checksum in the build documentation; no
  version has been selected yet. Never build from a floating branch or latest tag.
- Use out-of-tree builds with an explicit absolute `O=` output directory.
- Keep board-specific customizations inside `BR2_EXTERNAL` whenever possible.
- Do not modify vendored Buildroot sources unless there is no maintainable
  alternative; document the reason and keep any necessary patches reproducible.
- Prefer reproducible, upstream-friendly changes and pinned dependencies.

## Safety and scope

- Never run `dd`, `mkfs`, formatting, flashing, partitioning, or other destructive
  storage commands without explicit user approval.
- Never push, merge, rebase, force-push, or rewrite Git history without explicit
  user approval.
- Never commit Buildroot output directories, downloaded archives, generated
  images, credentials, private keys, or secrets. Inspect staged content before
  any authorized commit.
- Keep changes focused and do not modify unrelated files.

## Agent coordination

- Prefer read-only agents for exploration and review.
- Only one write-capable agent may modify a subsystem at a time. The parent
  assigns ownership before edits, including shared application package files.
- Use `buildroot_engineer` for Buildroot and platform integration,
  `app_developer` for application work, and `reviewer` for read-only review.
- The buildroot engineer must not flash devices, run `dd`, format storage, or
  modify disks; hand any such request back to the parent for user approval.
- The app developer needs parent-agent approval before modifying bootloader,
  kernel, or device-tree files.

## Verification

- Run appropriate checks after changes and report the exact commands and results.
- Keep astronomical domain logic separate from UI and platform-specific code.
- Add tests for astronomical calculations and time-zone-sensitive logic.
- Clearly distinguish static checks, host tests, build verification, and hardware
  verification. Never claim real hardware testing unless it was actually done
  on the STM32MP157C-DK2; report unverified behavior explicitly.
- During the initial agent-configuration task, do not compile, commit, or push.
