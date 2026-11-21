# Build

Placeholders: `ad.example.invalid` (AD domain), `AD` (NetBIOS),
`example.com` (verified cloud UPN suffix), `<DC_IP>`, `<GATEWAY_IP>`,
`<IFINDEX>`, `lab-user` (test user).

## Network

- One private VMware NAT subnet. Domain members use `DC01` (`<DC_IP>`) for
  DNS; the NAT gateway stays the router, not the resolver.
- No public DNS records for the AD namespace. The DC resolves external names.

## DC01

1. Install AD DS and DNS. Promote with **Add a new forest**, keeping DNS
   Server and Global Catalog.
2. Create domain-root OUs: `Lab-ConnectSync` (in sync scope), `Servers`.
3. Create `lab-user` in `Lab-ConnectSync` with UPN `lab-user@example.com`
   (the verified suffix), and an AD Global Security group with `lab-user` as
   a member.

## SYNC01

Join the domain, restart, then check:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
Test-ComputerSecureChannel -Verbose   # member-computer check, not DC health
Resolve-DnsName sync01.ad.example.invalid -Server <DC_IP>
```

## Entra Connect Sync (custom install on SYNC01)

| Choice | Value |
|---|---|
| Database / service account | Local database, default virtual service account |
| Sign-in method | Password Hash Synchronization, **Enable single sign on** |
| Sign-in attribute | `userPrincipalName` |
| OU filtering | `Lab-ConnectSync` only |
| Source anchor | Automatic (`ms-DS-ConsistencyGuid`) |
| Optional features | Password writeback; nothing else |
| Out of scope | Exchange hybrid, group/device writeback, directory extensions |

The wizard lists the private AD suffix as **Not Added**. That's expected: the
test user uses the verified cloud suffix.

**Privilege boundaries.** Configure Connect with a cloud-only account holding
Hybrid Identity Administrator. AD admin credentials are needed separately for
local setup and SSO. Treat `SYNC01` as tier-0: its AD connector account has
replication rights for PHS.

Confirm the engine is active, not staged:

```powershell
Import-Module ADSync
Get-ADSyncScheduler |
  Select-Object StagingModeEnabled, SyncCycleEnabled, NextSyncCyclePolicyType, NextSyncCycleStartTimeInUTC
# Expect StagingModeEnabled False, SyncCycleEnabled True
```

Keep the default 500-object deletion safeguard on. It doesn't stop smaller
accidental deletions.

## CLIENT01

1. Set DNS to `DC01` only, then join `ad.example.invalid`.
2. Sign in as `AD\lab-user`.

## Seamless SSO GPO

On `DC01`, create a GPO linked to `Lab-ConnectSync` (where the user is):

- User Configuration > Policies > Administrative Templates > Windows
  Components > Internet Explorer > Internet Control Panel > Security Page >
  **Site to Zone Assignment List**: `https://autologon.microsoftazuread-sso.com`
  = `1` (Local intranet). Trusted Sites (`2`) breaks sign-in.
- Same path > Intranet Zone > **Allow updates to status bar via script**:
  Enabled.

```powershell
gpupdate /target:user /force
gpresult /r /scope user
```
