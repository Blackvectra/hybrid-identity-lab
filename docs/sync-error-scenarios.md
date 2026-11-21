# Sync error scenarios

Status: **Planned.** Controlled failures to practise diagnosing Entra Connect
Sync. Run one at a time, in the lab only, and put everything back before the
next one. Record each run in troubleshooting.md with what was observed, the
hypothesis, the test, the fix, and the result.

Where to look, in order:
1. **Synchronization Service Manager** on `SYNC01`: Operations (run profile
   results and errors), then Connectors > Search Connector Space for the object.
2. **Entra admin center**: the user object and the provisioning-error state on it.
3. **Connect Health > Sync errors**: only if the Health agent is registered
   (it wasn't in the original build; see troubleshooting.md).

Use a dedicated test user (`sync-test1`, `sync-test2`) in `Lab-ConnectSync`,
not the main lab user.

## 1. Duplicate proxy address (AttributeValueMustBeUnique)

A duplicate **UPN** can't be used here: domain controllers since Windows
Server 2012 R2 reject a UPN that already exists in the forest
(`ERROR_DS_UPN_VALUE_NOT_UNIQUE_IN_FOREST`), so nothing would reach Entra.
See [SPN and UPN uniqueness](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/component-updates/spn-and-upn-uniqueness).
AD does not enforce uniqueness on `proxyAddresses`, so a duplicate SMTP
alias does reach Entra.

- **Break.** Give both synced test users the same secondary alias, then run a
  delta sync:

```powershell
Set-ADUser sync-test1 -Add @{proxyAddresses = "smtp:shared-alias@example.com"}
Set-ADUser sync-test2 -Add @{proxyAddresses = "smtp:shared-alias@example.com"}
Start-ADSyncSyncCycle -PolicyType Delta   # on SYNC01
```

- **Expect.** With duplicate attribute resiliency (on by default), Entra
  doesn't fail the export. It quarantines the conflicting proxy address on
  the second object and records it in that object's provisioning errors. The
  sync engine may report **no error** even though one cloud object is missing
  the alias.
- **Learn.** "Sync succeeded" and "the cloud object is correct" are different
  claims. Find the conflict on the cloud object, not in Run History.
- **Fix.** Remove the alias from one user on-premises and sync. Entra releases
  the quarantine (a background task runs hourly).

```powershell
Set-ADUser sync-test2 -Remove @{proxyAddresses = "smtp:shared-alias@example.com"}
```

## 2. Object moved out of scope (soft delete)

- **Break.** Move `sync-test1` from `Lab-ConnectSync` to an OU that isn't in
  scope, then sync.
- **Expect.** A pending delete in the connector space, then the cloud user in
  **Deleted users** (soft-deleted, restorable for 30 days).
- **Fix.** Move it back and sync. Confirm it's the **same** cloud object
  (same object ID), matched on the source anchor, not a new one.
- **Learn.** Changing OU filters is a deletion event.

## 3. Accidental-delete threshold

- **Break.** Lower the threshold, then push more deletes than it allows:

```powershell
Get-ADSyncExportDeletionThreshold -AADUserName "<hybrid admin UPN>"
Enable-ADSyncExportDeletionThreshold -DeletionThreshold 2 -AADUserName "<hybrid admin UPN>"
```

  Move three test users out of scope and sync.
- **Expect.** The export to Entra stops with a stopped-deletion-threshold
  status, and no deletes are applied.
- **Fix.** Move the users back, sync, and put the threshold back to its
  recorded value (default 500):

```powershell
Enable-ADSyncExportDeletionThreshold -DeletionThreshold 500 -AADUserName "<hybrid admin UPN>"
```

  Don't use `Disable-ADSyncExportDeletionThreshold` here; it would let the
  deletes through.

## 4. Unverified UPN suffix

- **Break.** Give `sync-test1` a UPN on a suffix that isn't verified in the
  tenant (for example the private AD namespace), then sync.
- **Expect.** The cloud user is created or updated with an
  `@<tenant>.onmicrosoft.com` UPN instead.
- **Fix.** Put back the verified suffix.
- **Learn.** Why the Connect wizard warns about **Not Added** suffixes.

## 5. Password hash sync not applying

- **Break.** Stop the sync service briefly (`Stop-Service ADSync` on `SYNC01`),
  then change `sync-test1`'s password.
- **Expect.** The old password still works in a fresh cloud sign-in.
- **Diagnose** using Synchronization Service Manager and the Application event
  log on `SYNC01` (PHS events), then start the service again and retest.
- **Learn.** PHS runs on its own schedule (about every 2 minutes) and depends
  on the sync service, not on the 30-minute object sync cycle.

## Reset checklist after every scenario

- [ ] Test users back in `Lab-ConnectSync` with their original UPNs and no
      leftover `shared-alias` proxy address
- [ ] Deletion threshold back at its recorded value
- [ ] `ADSync` service running; `Get-ADSyncScheduler` shows
      `StagingModeEnabled False`, `SyncCycleEnabled True`
- [ ] No objects left in Entra **Deleted users** that should be active
