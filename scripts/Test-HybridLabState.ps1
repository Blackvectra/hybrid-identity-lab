#Requires -Version 5.1
<#
.SYNOPSIS
Read-only checks for the hybrid identity lab. Run on the host named in each
check's Host column; checks that don't apply to the current machine are
reported as NotAssessed, not as failures.

.DESCRIPTION
Collects the states this lab's evidence depends on and returns one object per
check with Status Pass, Fail, NotAssessed, or Error. Makes no changes.

.EXAMPLE
.\Test-HybridLabState.ps1 -Domain ad.example.invalid -DcAddress 10.0.0.5 |
    Format-Table Check, Status, Detail -AutoSize
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Domain,
    [Parameter(Mandatory)][string]$DcAddress
)

function New-Result([string]$Check, [string]$TargetHost, [string]$Status, [string]$Detail) {
    [pscustomobject]@{ Check = $Check; Host = $TargetHost; Status = $Status; Detail = $Detail }
}

# 1. Any domain member: AD locator record resolves through the configured resolver.
try {
    $srv = Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$Domain" -ErrorAction Stop |
        Where-Object { $_.QueryType -eq 'SRV' }
    if ($srv) { New-Result 'AD locator SRV (default resolver)' 'member' 'Pass' ($srv.NameTarget -join ', ') }
    else { New-Result 'AD locator SRV (default resolver)' 'member' 'Fail' 'No SRV answer; check the client DNS server' }
} catch { New-Result 'AD locator SRV (default resolver)' 'member' 'Fail' $_.Exception.Message }

# 2. Any domain member: secure channel.
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    if (-not $cs.PartOfDomain) { New-Result 'Domain membership' 'member' 'NotAssessed' 'Not domain joined' }
    elseif ($cs.DomainRole -ge 4) { New-Result 'Secure channel' 'member' 'NotAssessed' 'Domain controller; member check does not apply' }
    else {
        $ok = Test-ComputerSecureChannel -ErrorAction Stop
        New-Result 'Secure channel' 'member' ($(if ($ok) { 'Pass' } else { 'Fail' })) "Domain $($cs.Domain)"
    }
} catch { New-Result 'Secure channel' 'member' 'Error' $_.Exception.Message }

# 3. SYNC01: Connect is active, not staged.
if (Get-Module -ListAvailable ADSync) {
    try {
        Import-Module ADSync -ErrorAction Stop
        $s = Get-ADSyncScheduler
        $status = if (-not $s.StagingModeEnabled -and $s.SyncCycleEnabled) { 'Pass' } else { 'Fail' }
        New-Result 'Connect scheduler' 'SYNC01' $status "Staging=$($s.StagingModeEnabled) Scheduler=$($s.SyncCycleEnabled)"
    } catch { New-Result 'Connect scheduler' 'SYNC01' 'Error' $_.Exception.Message }
} else { New-Result 'Connect scheduler' 'SYNC01' 'NotAssessed' 'ADSync module not present on this host' }

# 4. DC / RSAT: Seamless SSO computer account exists and is enabled.
if (Get-Module -ListAvailable ActiveDirectory) {
    try {
        $acct = Get-ADComputer AZUREADSSOACC -Server $DcAddress -Properties PasswordLastSet -ErrorAction Stop
        $age = if ($acct.PasswordLastSet) { [int]((Get-Date) - $acct.PasswordLastSet).TotalDays } else { $null }
        $status = if ($acct.Enabled) { 'Pass' } else { 'Fail' }
        New-Result 'AZUREADSSOACC present' 'DC/RSAT' $status "Enabled=$($acct.Enabled) KeyAgeDays=$age (roll over at least every 30 days)"
    } catch { New-Result 'AZUREADSSOACC present' 'DC/RSAT' 'Fail' $_.Exception.Message }

    try {
        $p = Get-ADDefaultDomainPasswordPolicy -Identity $Domain -Server $DcAddress -ErrorAction Stop
        New-Result 'Minimum password age' 'DC/RSAT' 'NotAssessed' "MinPasswordAge=$($p.MinPasswordAge) (lab exception if zero; record intent)"
    } catch { New-Result 'Minimum password age' 'DC/RSAT' 'Error' $_.Exception.Message }
} else {
    New-Result 'AZUREADSSOACC present' 'DC/RSAT' 'NotAssessed' 'ActiveDirectory module not present'
    New-Result 'Minimum password age' 'DC/RSAT' 'NotAssessed' 'ActiveDirectory module not present'
}

# 5. CLIENT01: device and PRT state, and the SSO Kerberos ticket.
$ds = & dsregcmd /status 2>$null
if ($LASTEXITCODE -eq 0 -and $ds) {
    $pick = { param($n) (($ds | Select-String "^\s*$n\s*:\s*(\S+)").Matches | Select-Object -First 1).Groups[1].Value }
    New-Result 'Device state' 'CLIENT01' 'NotAssessed' ("DomainJoined={0} AzureAdJoined={1} AzureAdPrt={2}" -f (& $pick 'DomainJoined'), (& $pick 'AzureAdJoined'), (& $pick 'AzureAdPrt'))
    $tickets = & klist 2>$null
    if ($tickets -match 'HTTP/autologon\.microsoftazuread-sso\.com') {
        New-Result 'Seamless SSO ticket' 'CLIENT01' 'Pass' 'Ticket present for HTTP/autologon.microsoftazuread-sso.com'
    } else {
        New-Result 'Seamless SSO ticket' 'CLIENT01' 'NotAssessed' 'No ticket cached; open the test URL first, then rerun'
    }
} else { New-Result 'Device state' 'CLIENT01' 'NotAssessed' 'dsregcmd unavailable' }
