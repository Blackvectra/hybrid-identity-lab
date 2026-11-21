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

## Secure channel check failed on the sync server

Found by the validation script on 2026-11-21, after the core lab was complete.

- **Observed.** On `SYNC01`, `Test-ComputerSecureChannel` returned False
  ("broken"), while `nltest /sc_query` reported `NERR_Success` against `DC01`.
  The System log held only NETLOGON **5719** events ("not able to set up a
  secure session"), clustered at server start-up times; no 3210 or 5722.
  `w32tm` showed the time source as **Local CMOS Clock**, never synced.
  Connect sync kept working throughout: the AD connector authenticates with
  its own account, not the machine's secure channel.
- **Hypotheses.** (1) Machine password out of sync, e.g. after a snapshot
  revert. (2) DC unreachable at start-up. (3) Time not synced to the domain.
- **What separated them.** No 3210/5722 and a successful `sc_query` made (1)
  unlikely. The 5719s lined up with boot times, so (2) explained the event
  log but not the current failure. The time service was not in the domain
  hierarchy at all, which is (3).
- **Change.**

```powershell
w32tm /config /syncfromflags:domhier /update
Restart-Service w32time
w32tm /resync
```

- **Result.** Source became `DC01` (stratum 2, synced), and
  `Test-ComputerSecureChannel` returned True. The fix and the recovery are
  correlated; it was not proven that the clock alone caused the False, and the
  clock offset before the change was not captured.
- **Lessons.**
  - A member server that never joined the domain time hierarchy will
    eventually break Kerberos (5-minute skew limit) even while sync looks fine.
  - "Sync is working" says nothing about the sync server's own domain health.
- **Follow-up on the time root.** `DC01` (the PDC emulator, so the domain's
  time root) was itself on **Local CMOS Clock** (stratum 1, `LOCL`): the whole
  domain was following an unsynced hardware clock. VMware Tools periodic time
  sync was already disabled. Pointed `DC01` at an external source:

```powershell
w32tm /config /manualpeerlist:"time.windows.com,0x8" /syncfromflags:manual /reliable:yes /update
Restart-Service w32time
w32tm /resync /rediscover
```

  Result: source `time.windows.com,0x8`, stratum 5, synced. Domain time now
  runs external NTP → `DC01` → members.

## Not the same failure

- Connect Health showing no registered AD DS service was a monitoring
  registration gap, not a missing sync engine.
- A Conditional Access report-only result did not enforce anything. Match the
  application, resource and time before linking a sign-in failure to a cause.
