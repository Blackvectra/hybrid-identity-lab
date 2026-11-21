# Test procedures

Never put passwords in scripts, history, screenshots, or notes. Use
`Get-Credential` prompts.

## 1. Sync

```powershell
Get-ADGroupMember -Identity "<lab group>"
```

In Entra, the group should show source **Windows Server AD**, `lab-user` as
a direct member, and membership controls disabled (AD is the source of
authority).

## 2. Password hash sync

1. Confirm staging is off (see build.md).
2. Change `lab-user`'s AD password.
3. Wait for PHS (it runs about every 2 minutes, separate from the object sync
   cycle). `Start-ADSyncSyncCycle` returning Success is not a PHS test.
4. In a **fresh** browser session, sign in as `lab-user@example.com` and
   explicitly enter the new password.
5. Stronger evidence: export the sign-in's authentication details from Entra.

## 3. SSPR with password writeback

Prerequisites: SSPR enabled for the user, recovery methods registered,
writeback enabled in both Connect and Entra (Password reset > On-premises
integration), and a licence that covers writeback.

```powershell
# Before
Get-ADUser lab-user -Properties PasswordLastSet | Select-Object SamAccountName, PasswordLastSet
```

1. In a fresh browser session, open `https://aka.ms/sspr` and use the
   forgotten-password flow for `lab-user@example.com`.
2. Set a new password that satisfies AD policy, including minimum age.
3. Prove writeback by authenticating to the DC with the new password:

```powershell
Get-ADUser lab-user -Server dc01.ad.example.invalid `
  -Credential (Get-Credential "AD\lab-user") -Properties PasswordLastSet |
  Select-Object SamAccountName, PasswordLastSet
```

## 4. Seamless SSO

1. Sign out of Windows and back in as `AD\lab-user`.
2. In a **regular** Edge window (not InPrivate), signed out of the browser
   profile with cookies cleared, open `https://myapps.microsoft.com/example.com`.
   Target: no password entry. A username prompt, MFA, or Conditional Access
   can still appear.
3. Capture the evidence:

```powershell
Get-Date
whoami
dsregcmd /status | Select-String 'AzureAdJoined|DomainJoined|AzureAdPrt'
klist
```

Expect `DomainJoined: YES`, `AzureAdJoined: NO`, `AzureAdPrt: NO`, and a
ticket for `HTTP/autologon.microsoftazuread-sso.com`.

4. Optional corroboration: with success auditing on, DC Security event 4769
   for `AZUREADSSOACC$` matching the user, client IP and time.
