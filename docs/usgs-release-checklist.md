# lucasCore USGS software release checklist

Follows "How to Publish a Software Release" (SM 502.11 reviews, IPDS routing). When the project exists on code.usgs.gov, copy this into an
issue there and attach each document that goes to IPDS, as the guidance recommends.

Target: `https://code.usgs.gov/LUCC/lucasCore`, version 1.1.0. Capitalization of the URL still to confirm: it is case-sensitive in `code.json`.

## Before the move

- [ ] Supervisor: what to do about the public GitHub repository and its v1.0.0 and v1.0.1 releases, made before any security review
- [ ] Keep or drop the git history (a kept history is all reviewed; recommended: one clean commit, full history kept elsewhere)
- [x] `dev/`: the cited parts ship (`tools/release-dev-files.txt`, 111 of 187 files), paths removed; the rest stays in the existing repository
- [ ] Decide where the online guide and blueprints are served (their links are relative now, so any host works; GitHub Pages still serves the old copy)
- [x] Internal notes ship (`docs/ui-improvements.md`, `docs/guide/walkthrough-notes.md`, the plan documents), with machine paths and private links removed
- [ ] Confirm the authors, and the wording of the README's citation and AI declaration
- [ ] Add related publications and data releases to the README
- [ ] Confirm LICENSE.md and DISCLAIMER.md against the official USGS content, whose links did not survive in the text copy of the guidance
- [ ] Confirm the terms of the CBM-CFS3 tables in `defaults/cbm` (Natural Resources Canada)
- [x] All 14 `tests/unit-*.R` pass with `LUCAS_DATA_HOME` set
- [x] Example `F:/` paths out of the User Guide: text and eight figures (fig-1.6, 1.15, 1.17, 4.4, B.1, B.6, B.7, B.10), in its source document and the snapshot
- [x] GitHub links changed to `https://code.usgs.gov/LUCC/lucasCore`
- [ ] Decide on the name and partial ORCID in fig-B.2, B.3, B.4
- [ ] `tools/release-snapshot.sh --scan-only` is clean

## Phase 1: repository

- [ ] Project in the LUCC group, private, empty
- [ ] First push (`tools/release-snapshot.sh <empty folder>`, then add the remote and push)
- [x] Versioned description of changes: `CHANGELOG.md`
- [x] Drafts: `README.md`, `code.json`, `LICENSE.md`, `DISCLAIMER.md` (provisional wording)
- [x] Test datasets documented: the repository holds none (README, Test)

## Phase 2: release candidate

- [ ] Branch `1.1.0`; set the version in `package.xml` to match
- [ ] `code.json`: version `1.1.0`, status `Release Candidate`, license, download and disclaimer URLs on the branch, `metadataLastUpdated`
- [ ] `DISCLAIMER.md`: official release wording

## Phase 3: IPDS and DOI

- [ ] IPDS record: authors, reviewers, bibliodata, note with the release URL
- [ ] Reserve the DOI (not through ScienceBase); landing page = the release candidate branch; IPDS number
- [ ] README citation uses the DOI URL; `code.json` tag `doi|https://doi.org/...`
- [ ] `defaults/metadata/record-defaults.csv` SoftwareCitation uses the DOI, so data releases cite it

## Phase 4: peer review

- [ ] Project visible to the reviewers, supervisor and Bureau Approving Official
- [ ] Original manuscript (zip of the repository) in IPDS; Request Peer Review; supervisor accepts
- [ ] Administrative Security Review
- [ ] Code Review
- [ ] Domain Review
- [ ] Comments addressed; review, reconciliation and updated manuscript in IPDS; Reconcile Peer Review

## Phase 5: supervisory review

- [ ] Review, comments addressed, documents and manuscript in IPDS; supervisor completes the routing step
- [ ] `code.json` status `Production`

## Phase 6: Bureau approval

- [ ] Center Director review, comments addressed, documents and manuscript in IPDS; Bureau Approval

## Phase 7: official release

- [ ] Optional check first with the software-management validator (Docker), `--type official`
- [ ] Request the official release in the Software Management repository
- [ ] Tag `1.1.0` from the branch; attach `lucasCore-1.1.0.ssimpkg`
- [ ] Visibility: only Repository, Forks and Releases open to "Everyone with access"; the rest "Only Project members"
- [ ] Update the DOI landing page to the tag if needed; Publish Approved Release to DataCite
- [ ] Check all IPDS tabs; Dissemination
