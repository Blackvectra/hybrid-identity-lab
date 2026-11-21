# Defender for Servers trial (no Azure Arc)

Status: **Planned.** Facts below are from Microsoft's documentation as of
2026-11-21; recheck the trial terms and pricing before enabling anything.

## How it works without Arc

1. Each server is onboarded to **Defender for Endpoint** with the onboarding
   package from the Defender portal.
2. **Direct onboarding** in Defender for Cloud then associates those servers
   with an Azure subscription for Defender for Servers. The setting doesn't
   install the agent.

Source: [Use Direct onboarding for on-premises servers](https://learn.microsoft.com/azure/defender-for-cloud/onboard-machines-with-defender-for-endpoint).

## What you get, and what you don't

| Available without Arc | Needs Arc (not in this trial) |
|---|---|
| Plan 1: Defender for Endpoint protection, alerts and incidents in the Defender portal | OS baseline checks against the Microsoft Cloud Security Benchmark |
| From Plan 2, only the premium Defender Vulnerability Management features | File integrity monitoring on on-premises machines |
| | OS system updates assessment |
| | Azure Policy and Guest Configuration |

Source: [Defender for Servers plan features](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-servers-overview#plan-protection-features).

## Things to accept before starting

- **The 30-day trial starts when the plan is enabled** and can't be paused or
  extended.
- **The Direct onboarding setting is tenant-wide.** It applies to every
  eligible server onboarded to Defender for Endpoint in the tenant, now and
  later. You can't scope it to a pilot.
- **The Defender for Endpoint data location is fixed** the first time it is
  provisioned in a tenant.
- **Prerequisites:** an Azure subscription in the same tenant, **Owner** on it,
  and **Security Administrator** (or higher) in Entra ID. Servers can take up
  to 24 hours to appear under the subscription.
- **Agent version:** Windows Server 2019 and later need agent 10.8555 or newer
  for Defender for Cloud to correlate the server correctly.

## Steps

Order matters: servers need a licence before they can be onboarded to
Defender for Endpoint, and in this lab the Defender for Servers plan is what
provides it ([server onboarding prerequisites](https://learn.microsoft.com/defender-endpoint/onboard-server#server-plans)).
Enable the entitlement first, onboard second.

1. Create or choose the Azure subscription in the lab tenant, with **Owner**
   for your account. Set a budget alert.
2. In Defender for Cloud, enable **Defender for Servers** on that subscription
   and **record the trial end date** (the 30 days start now).
3. Defender for Cloud > **Environment settings** > **Direct onboarding** >
   **On**, choose the same subscription, **Save**.
4. Open the Defender portal and let the Defender for Endpoint tenant finish
   provisioning, if this is the tenant's first use of it.
5. Download the Windows Server onboarding package (local script method is
   fine for three VMs) and run it on `DC01` and `SYNC01`.
6. Check each server is healthy in the Defender device inventory.
7. Wait up to 24 hours, then confirm the servers appear under the subscription
   in Defender for Cloud with the intended plan, and no duplicate records.

`CLIENT01` is a workstation: it needs a client licence (the lab's M365
licensing may cover it) rather than the server plan, so treat onboarding it as
optional and separate.

## Tests and evidence

| Test | Evidence to capture |
|---|---|
| Onboarding health | Device inventory entry per server, sensor health, onboarding status |
| Detection pipeline | Run Microsoft's documented detection test on one server; capture the alert in the Defender portal and its incident |
| EICAR test file | Defender Antivirus blocking the EICAR test string, and the matching alert |
| Vulnerability management | Software inventory and vulnerabilities listed for `DC01` and `SYNC01`; note anything surprising on a fresh Server 2025 build |
| Cross-check with the validation script | Does Defender flag anything the script or earlier troubleshooting missed? |
| Sync scenario overlap | While running sync-error-scenarios.md, does Defender raise anything on `SYNC01` or `DC01`? Record either way |

Only harmless test artifacts. No real malware, no attack tools.

## Teardown (before the trial ends)

- [ ] Export the evidence (sanitized)
- [ ] Disable the Defender for Servers plan on the subscription
- [ ] Turn Direct onboarding off if nothing else should be billed
- [ ] Offboard the servers from Defender for Endpoint if the lab is being retired
- [ ] Confirm no remaining charges on the subscription
