# Roadmap

## Evidence and operations closeout

- [ ] Capture the gaps listed in docs/evidence.md
- [ ] Record Connect build, connector identities, final minimum password age
      and GPO alignment
- [ ] Seamless SSO Kerberos key rollover: Microsoft recommends rolling the
      `AZUREADSSOACC` key at least every 30 days; record the actual rotation
- [ ] Protect `AZUREADSSOACC` from accidental deletion and restrict who can
      administer it
- [ ] Run `scripts/Test-HybridLabState.ps1` and keep its output as the
      baseline

## Separate future projects

- [ ] Entra hybrid device join (SCP, device OU in sync scope) and PRT-based SSO,
      compared with the Kerberos path tested here
- [ ] Windows Autopilot hybrid join (current Intune connector for AD, domain
      join profile, ESP, OOBE)
- [ ] Entra Cloud Sync comparison on a separate OU, without overlapping Connect
      Sync ownership of the same objects
- [ ] Rebuild the lab from scripts so it can be recreated on demand
