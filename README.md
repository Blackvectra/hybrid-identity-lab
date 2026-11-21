# Hybrid identity lab: Active Directory to Microsoft Entra ID

A small VMware lab connecting on-premises Active Directory to Microsoft Entra
ID with Entra Connect Sync, built to test what each hybrid identity flow
actually does from the user's side and what evidence proves it.

**Status: core lab complete (November 2026).** Identifiers are anonymized:
hostnames, domain names, UPNs, addresses and tenant details are placeholders.

## What was tested

| Flow | Test | Result | Evidence strength |
|---|---|---|---|
| User and group sync | Scoped OU synchronized; AD-managed group and membership visible in Entra | Passed | Observed: screenshots of source and membership |
| Password hash sync (PHS) | Changed the AD password, then entered the new password in a fresh cloud sign-in | Passed | Operator-confirmed; authentication-log export not captured |
| SSPR | Forgotten-password reset at the cloud recovery page | Passed | Observed: reset confirmation |
| Password writeback | Authenticated a directory query directly against the DC with the new SSPR password | Passed | Operator-confirmed; `PasswordLastSet` output not captured |
| Seamless SSO (Kerberos) | Password-free browser sign-in on an AD-joined client, plus the matching service ticket and device state | Passed | Observed: ticket and device state; browser result operator-confirmed |
| Autopilot / Entra hybrid device join | Explored, then deferred | Not claimed | — |

**Observed** means a capture shows the state. **Operator-confirmed** means the
test was run and the result reported, without a final capture. The difference
is kept on purpose. See [docs/evidence.md](docs/evidence.md).

## Architecture

| Component | Role |
|---|---|
| `DC01` | AD DS and DNS (Windows Server 2025), private AD namespace |
| `SYNC01` | Separate member server running Entra Connect Sync |
| `CLIENT01` | Windows 11 client, AD domain joined (not Entra joined) |
| Entra tenant | Synchronized identities, cloud sign-in, SSPR, Conditional Access |

Design choices:
- **Dedicated sync OU.** Only one lab OU is in Connect scope, so the test
  objects are easy to inspect and nothing else in the forest syncs.
- **Sync on a member server, not the DC.** Keeps the sync engine, which holds
  sensitive replication rights for PHS, separate from the DC.
- **PHS + Seamless SSO.** No federation and no pass-through agent, so each
  flow can be tested on its own.
- **Source of authority kept straight.** The synced group stays AD-managed;
  its membership is edited on the DC, not in Entra.

## Three flows, three different tests

1. **PHS** (on-premises to cloud). An existing browser session proves nothing,
   because cloud tokens outlive the password change. The test is a fresh
   cloud sign-in that explicitly enters the new AD password.
2. **SSPR with writeback** (cloud to on-premises). The cloud success page shows
   the reset was accepted. The test of writeback is authenticating directly
   to the DC with the new password, not relying on a cached desktop session.
3. **Seamless SSO.** A password-free page alone doesn't say which SSO
   mechanism ran. The client showed `AzureAdJoined: NO` and `AzureAdPrt: NO`
   plus a Kerberos ticket for `HTTP/autologon.microsoftazuread-sso.com`,
   which rules out PRT-based SSO and points to the Kerberos path.

Procedures: [docs/tests.md](docs/tests.md). Build: [docs/build.md](docs/build.md).

## What went wrong and what it taught

Summarized from [docs/troubleshooting.md](docs/troubleshooting.md):

- **DNS before credentials.** Domain join failed because one server used the
  NAT gateway for DNS and the client had a mistyped resolver address. Default
  SRV lookups returned public answers; a direct query to the DC worked.
- **A Success label isn't an outcome.** The engine started in staging mode:
  import and sync succeeded and an Add was pending, but nothing exported.
  Follow an object through import, sync, export and destination.
- **The SSPR error was broader than length.** A combined policy error pointed
  at minimum password age (1 day) after a fresh change. Setting it to zero
  for the isolated lab let the reset succeed. That is consistent with the
  hypothesis but no writeback log isolated the cause.
- **Browser mode changes the SSO test.** Edge InPrivate doesn't allow ambient
  Windows authentication by default, so it prompted for a password. A regular
  window signed in silently.

## Limitations

- One forest, one synchronized test user, one small group. A learning lab,
  not a production migration, resilience test, or enterprise rollout.
- The client was AD joined only. Entra hybrid device join, Intune enrollment,
  and Autopilot provisioning are not claimed.
- Some results are operator-confirmed rather than captured (see the table).
- DC event 4769 for the SSO computer account would corroborate the SSO test;
  it was not collected.

Next steps: [ROADMAP.md](ROADMAP.md).

## References

- [Implement password hash synchronization](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-password-hash-synchronization)
- [Tutorial: Enable SSPR writeback](https://learn.microsoft.com/entra/identity/authentication/tutorial-enable-sspr-writeback)
- [Quickstart: Seamless single sign-on](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-sso-quick-start)
- [Troubleshoot Seamless SSO](https://learn.microsoft.com/entra/identity/hybrid/connect/tshoot-connect-sso)
- [Edge policy: AmbientAuthenticationInPrivateModesEnabled](https://learn.microsoft.com/deployedge/microsoft-edge-policies/ambientauthenticationinprivatemodesenabled)
- [Entra Connect staging server](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-staging-server)
