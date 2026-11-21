# Troubleshooting log

Each entry: what was observed, what it could mean, what separated the
explanations, and what changed.

## DNS: domain join fails before credentials matter

- **Observed.** `SYNC01` used the NAT gateway as its DNS server. Later
  `CLIENT01` had a mistyped resolver address; its join failed with
  `DNS_INFO_NO_RECORDS (0x0000251D)`.
- **Test.** Compare a default SRV query with one sent straight to the DC:

```powershell
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.ad.example.invalid
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.ad.example.invalid -Server <DC_IP>
```

  The default query returned public authority information; the direct one
  returned the DC.
- **Fix.**

```powershell
Set-DnsClientServerAddress -InterfaceIndex <IFINDEX> -ServerAddresses "<DC_IP>"
Clear-DnsClientCache
nltest /dsgetdc:ad.example.invalid /force
```

- **Lesson.** Separate routing, public resolution and AD service discovery
  before touching credentials or publishing DNS records. No public record for
  the AD namespace was needed.

## Staging mode: success without an outcome

- **Observed.** Import and sync runs succeeded and a user Add sat in the
  connector space, but nothing reached Entra.
- **Cause.** The engine was in staging mode, which suppresses normal exports,
  PHS and writeback.
- **Fix and check.** Disable staging; `Get-ADSyncScheduler` showed
  `StagingModeEnabled False`, `SyncCycleEnabled True`.
- **Lesson.** Follow an object through import, sync, export and destination.
  One Success label proves one step.

## SSPR rejected the new password

- **Observed.** A combined "length, complexity, age, or history" error. Policy
  showed minimum length 7, complexity on, history 24, **minimum age 1 day**,
  and the password had just changed.
- **Hypothesis.** Minimum age, since the proposed password met the visible
  length and complexity rules.
- **Change (lab only).** Minimum age set to zero, complexity and history kept:

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity "ad.example.invalid" -MinPasswordAge ([TimeSpan]::Zero)
Get-ADDefaultDomainPasswordPolicy -Identity "ad.example.invalid" | Select-Object MinPasswordAge
```

- **Result.** The next reset succeeded. Consistent with the hypothesis, but no
  writeback event log isolated the original cause. Align the domain password
  GPO so policy processing doesn't revert it, and check
  `Get-ADUserResultantPasswordPolicy` if a fine-grained policy applies.
- **Caution.** Zero minimum age allows rapid password cycling around history.
  A lab exception, not a production recommendation.

## Seamless SSO prompted for a password in InPrivate

- **Observed.** Edge InPrivate asked for a password.
- **Cause.** Edge allows ambient Windows authentication in regular sessions
  only by default (`AmbientAuthenticationInPrivateModesEnabled`).
- **Fix.** Regular window, browser profile signed out, cookies cleared: signed
  in without a password. Then confirmed with Kerberos evidence rather than the
  browser result alone.

## Not the same failure

- Connect Health showing no registered AD DS service was a monitoring
  registration gap, not a missing sync engine.
- A Conditional Access report-only result did not enforce anything. Match the
  application, resource and time before linking a sign-in failure to a cause.
