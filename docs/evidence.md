# Evidence

Original captures are kept privately because they contain real hostnames,
addresses, account names and tenant details. This page records what each
capture establishes, using three labels:

- **Observed**: a capture shows the state.
- **Operator-confirmed**: the test was run and the result reported, but the
  final output was not captured.
- **Deferred / not claimed**: not completed.

| Claim | Label | What establishes it |
|---|---|---|
| Connect active, not staged | Observed | Scheduler: `StagingModeEnabled False`, `SyncCycleEnabled True` |
| Group and membership in Entra | Observed | Group source Windows Server AD; test user as direct member |
| PHS | Operator-confirmed | New AD password accepted at a fresh cloud prompt |
| SSPR reset accepted | Observed | "Your password has been reset" confirmation |
| Writeback | Operator-confirmed | Credentialed query to the DC succeeded with the SSPR password |
| SSO GPO applied | Observed | `gpresult` shows the GPO applied; zone value `1` |
| Seamless SSO (Kerberos path) | Observed + operator-confirmed | Ticket and device state below; password-free browser result reported |
| Hybrid device join / Autopilot | Not claimed | Client is AD joined only |

## Seamless SSO capture (redacted transcription)

Identifiers replaced; technical states and encryption type preserved.

```text
Windows user:     AD\lab-user
DomainJoined:     YES
AzureAdJoined:    NO
AzureAdPrt:       NO
Service ticket:   HTTP/autologon.microsoftazuread-sso.com
Encryption:       AES-256-CTS-HMAC-SHA1-96
KDC:              DC01.ad.example.invalid
```

## Validation script runs

`scripts/Test-HybridLabState.ps1`, read-only. Identifiers replaced.

### DC01 (2026-11-21)

| Check | Status | Detail |
|---|---|---|
| AD locator SRV (default resolver) | Pass | `dc01.ad.example.invalid` |
| Secure channel | NotAssessed | Domain controller; member check does not apply |
| AZUREADSSOACC present | Pass | Enabled; Kerberos key 5 days old (rollover due within 30 days of creation) |
| Minimum password age | Recorded | `00:00:00`: the lab exception is in effect (previously not captured) |
| Time source (manual check) | Fixed | Was Local CMOS Clock; now external NTP, stratum 5, synced |

Device-state and SSO-ticket rows from this run came from the DC, not the
client, and are not used as evidence.

### SYNC01 (2026-11-21)

| Check | Status | Detail |
|---|---|---|
| AD locator SRV (default resolver) | Pass | `dc01.ad.example.invalid` |
| Connect scheduler | Pass | `Staging=False Scheduler=True` (now observed directly, not only from the earlier capture) |
| Time source (manual check) | Fixed | Was Local CMOS Clock; now `DC01`, stratum 2, synced |
| Secure channel | Fail, then Pass | Failed on first run; passed after the time service was joined to the domain hierarchy. See troubleshooting.md |

Pending: CLIENT01 (device state and SSO ticket after opening the test URL).

## Gaps that would strengthen this

- Entra sign-in authentication details for the PHS test
- `PasswordLastSet` before and after the SSPR reset
- Export history and Entra last-sync timestamps
- DC event 4769 for `AZUREADSSOACC$` correlated with the SSO test
