# ADR 0014: Disk image distribution outside the App Store

Status: Accepted (2026-09-19)

## Context

The Mac download outside the App Store was a zip of the notarized app. A zip is not a place a user installs from: it leaves the app sitting in `~/Downloads`, it cannot carry an `Applications` shortcut, it cannot be signed or notarized as an artifact in its own right, and it cannot carry a notarization ticket of its own, so Gatekeeper judges it only by the app inside. Apple's own packaging guide for software distributed outside the store asks for a disk image instead: populated with `ditto`, built with `hdiutil create -srcfolder`, in UDIF read-only zip-compressed format (`UDZO`), signed with the *Developer ID Application* certificate and notarized and stapled as the artifact a user actually opens.

## Decision

1. The Mac app distributed outside the App Store MUST be published as exactly one artifact, `ChitarraTune-X.Y.Z.dmg`, with `ChitarraTune-X.Y.Z.dmg.sha256` beside it. No other archive format is published.
2. The image MUST be built by `Scripts/make-dmg.sh` from a staging directory populated with `ditto` (which preserves symlinks and the app's stapled ticket; `cp` does not), holding exactly `ChitarraTune.app`, a symlink to `/Applications` and a volume icon, turned into an image with `hdiutil create -srcfolder`. There MUST be no Finder or AppleScript step: the layout is what the file system says it is, so it stays reproducible on a headless runner.
3. The image MUST be UDIF read-only, zip-compressed (`UDZO`).
4. The app inside MUST already be notarized and stapled before it is wrapped, so it keeps working once it has been dragged out of the image, on a Mac that has never been online.
5. The image itself MUST be signed with the *Developer ID Application* certificate and a secure timestamp, under a code-signing identifier prefixed by the app's bundle identifier and equal to no bundle identifier in the product (`com.chitarratune.app.dmg`), then notarized in a submission of its own and stapled. Two notarizations, one artifact.
6. Every push MUST build an ad-hoc image from the release build with the same script, and MUST run every check that needs no certificate: the format, the contents of the volume, the `Applications` symlink target, the image's own signature and its identifier.
7. The image MUST be built outside the working tree (the `SCRATCH` convention already used by `Scripts/release-check.sh`); any volume the script mounts MUST be attached `-nobrowse -readonly` at a private mount point and detached on every exit path.
8. The published bytes MUST be the stapled ones: the checksum and the build-provenance attestation are computed after `xcrun stapler staple`, never before, and re-signing the image after stapling is forbidden (it would strip the ticket).

## Consequences

- One file, one gesture: open, drag onto Applications. No third-party packaging tool and no UI automation runs in CI.
- Gatekeeper is satisfied offline, both on the image and on the app it contains.
- A packaging mistake — a dereferenced symlink, a read-write image, a signing identifier that collides with a bundle identifier, an app that was wrapped before being stapled — fails on the push that introduces it, not on release day.
- The zip asset is gone: anything that scripted the old asset name breaks, on purpose, and the changelog says so.
- Two notary submissions per release roughly double the notarization wall-clock of the Developer ID job.

## Enforcement

- `Scripts/make-dmg.sh`, run by the `release` job of `.github/workflows/ci.yml` on every push and by `.github/workflows/release.yml` on a tagged release.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/DiskImagePolicyTests.swift` (the recipe in the script, the signing identifier).
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` (both workflows build the image; the release notarizes, staples and publishes it; the zip is gone).
- `docs/CODE_SIGNING.md` (the disk image section).
