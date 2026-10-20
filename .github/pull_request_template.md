## Changeset

<!-- One logical change per PR. Split unrelated work into separate PRs. -->

## Checklist

- [ ] This PR contains **one** logical changeset
- [ ] Every changed `*.json` and `pack.mcmeta` still parse (CI lints them)
- [ ] Change is documented; README updated if player-facing
- [ ] Species/scale tuning notes in `README.md` still match the files, if touched
- [ ] No logs or `crash-reports/` committed

## Breaking change

<!-- Tick only if this changes behavior other datapacks/packs depend on. CI uses this
     label to require that the next beta or stable version bump raises major or minor. -->

- [ ] This change is **breaking** — apply the `breaking` label before merge

## Version bump

<!-- Only complete this section if pack.mcmeta's version is changing. -->

- [ ] This PR bumps the `pack.mcmeta` version **and nothing else**
- [ ] New version is a clean bump (e.g. `1.0.0`) — releases as stable
- [ ] New version has a `-beta` suffix — releases as beta
- [ ] New version has an `-alpha` suffix — releases as alpha; other changes permitted

<!-- The version lives in pack.mcmeta's pack.description string as vX.Y.Z. -->
