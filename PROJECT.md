# Project: HowMuch Mockup Data Scanning

## Architecture
This project is a read-only codebase scanning task. The structure consists of:
- Flutter/Dart codebase located under `lib/features/`.
- Goal: Produce `mockup_report.md` detailing hardcoded mockup data.
- Constraints: No files in `lib/` or `test/` should be modified.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|-------------|--------|
| 1 | Plan & Scan Setup | Verify workspace, outline files to check | None | DONE |
| 2 | Codebase Scanning | Identify all hardcoded mockup occurrences in `lib/features` | M1 | DONE |
| 3 | Report Compilation | Write `mockup_report.md` with guidelines | M2 | DONE |
| 4 | Verification & Sign-off | Review report layout, verify code integrity, notify Sentinel | M3 | DONE |

## Interface Contracts
### scanning ↔ reporting
- Output of scanning: List of mockup files, lines, and target values.
- Input to reporting: Structured list formatted into markdown guidelines.
