# hybrid-identity-lab

Public write-up of a personal AD → Entra ID lab. Real identifiers never get committed.

- Redaction placeholders and evidence labels (Observed / Operator-confirmed / Not claimed): `docs/evidence.md`. Use `ad.example.invalid`, `example.com`, `lab-user`, `<DC_IP>`; example IPs come from `192.0.2.0/24`.
- CI (`.github/workflows/ci.yml`) fails on private IPs and on strings in the `REDACTION_DENYLIST` Actions secret, and runs PSScriptAnalyzer, a Windows PowerShell 5.1 parse check, and Pester.
- Lab machines run Windows PowerShell 5.1; keep `scripts/` 5.1-compatible.
- Each troubleshooting entry: observed, hypotheses, discriminating test, change, result. State correlation as correlation.
