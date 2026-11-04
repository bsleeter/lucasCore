# Contributing

Questions, bug reports and suggestions are welcome as issues on this repository. Please say which version you ran, the SyncroSim and
ST-Sim versions, and the stage and message where it went wrong (each stage writes its checks to the `lucasCore_OutputValidation` sheet).

## Making a change

1. Work on a branch and open a merge request. A USGS release changes only through the review steps in USGS SM 502.11.
2. Add a line to [CHANGELOG.md](CHANGELOG.md) under Unreleased.
3. Run the plain-R unit tests, which need no SyncroSim library:

   ```
   Rscript tests/unit-release.R
   ```

   Each `tests/unit-*.R` file runs the same way. Full-stage tests (`tests/phase*.R`) take minutes to an hour and need the national
   datasets; run those your change touches. The README's Test section describes both.
4. Every new input sheet gets a page in `ui/` with drop-downs and notes, and every sheet a page reads must be in its `dataFeed` in
   `package.xml` (`tests/unit-page-feeds.R` checks this).
5. Rebuild `lucasCoreUI.dll` with `tools/build_ui.ps1` after changing `ui/`. Close SyncroSim Studio first, and do not edit `src/` or
   `package.xml` during a run, because a registered package folder runs live.

## What not to commit

Machine paths, user names, keys or tokens, SyncroSim libraries and model outputs. Paths come from a script's own folder or an environment
variable (`LUCAS_DATA_HOME`). Check with `tools/release-snapshot.sh --scan-only` before pushing.

Contributions are released under the terms in [LICENSE.md](LICENSE.md).
