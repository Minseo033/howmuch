# SonarQube Cloud

- Dashboard: https://sonarcloud.io/dashboard?id=Minseo033_howmuch
- Organization: `minseo033`
- Project: `Minseo033_howmuch`
- GitHub repository secret: `SONAR_TOKEN` (never commit its value)

## Analysis

The separate SonarQube workflow builds Flutter 3.44.0 and the Java 21 backend, runs their tests, and uploads Dart LCOV and Java JaCoCo coverage. It scans authored code in `lib`, `web`, and `howmuch_backend/src/main/java`, with tests classified separately. Native platform scaffolding, data files, and maintenance scripts are outside this initial scope. Coverage is from Flutter VM tests and backend unit tests, not browser/device end-to-end coverage.

Cloud Automatic Analysis must be off because Dart requires CI-based analysis. The project uses the free Cloud plan. Main and PRs targeting main are analyzed. Fork PR analysis is intentionally skipped because GitHub does not share repository secrets with forks.

## Initial rollout

1. Merge the configuration into main to establish the first baseline. A PR analysis can require that baseline first.
2. Verify the SonarQube workflow and the dashboard, including imported coverage and the analyzed commit.
3. Review security findings and hotspots first, then reliability, duplication, and maintainability. A hotspot is a review request, not a confirmed vulnerability.

This workflow does not depend on, modify, or block the existing production deployment job. It does not make Sonar a required branch-protection check and does not fail merely because the quality gate is red. Those enforcement changes should be a separate team decision after reviewing the baseline.

## Token maintenance

The analysis token is stored only as an encrypted GitHub repository secret. To rotate it, create a replacement under SonarQube Cloud account security, replace `SONAR_TOKEN` in repository Actions secrets, test a run, and revoke the old token. No token is stored in this document.
