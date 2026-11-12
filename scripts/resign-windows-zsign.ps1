<#
.SYNOPSIS
Re-sign a dekpop IPA on Windows with zsign (no macOS or Xcode required).

.EXAMPLE
.\scripts\resign-windows-zsign.ps1 -Ipa .\dekpop-unsigned.ipa -P12 .\enterprise.p12 -P12Password 'YOUR_PASSWORD' -MobileProvision .\profile.mobileprovision

.NOTES
Get zsign from https://github.com/zhlynn/zsign (Windows build) and either put
zsign.exe on PATH or pass -ZSign <full-path-to-zsign.exe>.
The p12 password is passed on the command line: run only on a trusted machine.
#>
param(
    [Parameter(Mandatory = $true)][string]$Ipa,
    [Parameter(Mandatory = $true)][string]$P12,
    [Parameter(Mandatory = $true)][string]$P12Password,
    [Parameter(Mandatory = $true)][string]$MobileProvision,
    [string]$Output = "dekpop-signed.ipa",
    [string]$ZSign = "zsign"
)

$ErrorActionPreference = "Stop"

foreach ($f in @($Ipa, $P12, $MobileProvision)) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
        throw "File not found: $f"
    }
}

$exe = Get-Command $ZSign -ErrorAction SilentlyContinue
if ($null -eq $exe) {
    throw "zsign not found. Install zhlynn/zsign, then pass -ZSign <path-to-zsign.exe>."
}

Write-Host "==> Signing $Ipa with zsign (no macOS required)"
& $exe.Source -k $P12 -p $P12Password -m $MobileProvision -o $Output $Ipa
if ($LASTEXITCODE -ne 0) {
    throw "zsign failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) {
    throw "Output IPA was not created: $Output"
}

Write-Host "==> Wrote signed IPA: $Output"
Write-Host "    Copy it to the iPhone (Files / AirDrop) and install with ESign,"
Write-Host "    or host it over HTTPS with an itms-services manifest / push via MDM."
