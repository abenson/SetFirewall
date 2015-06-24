
<#
.SYNOPSIS
    Set_Firewall
.DESCRIPTION
    Configure the Windows firewall on a permit-by-except basis.
.NOTES
    File Name      : Set_Firewall.ps1
    Author         : Andrew Benson (abenson@gmail.com)
    Prerequisite   : PowerShell 5.0
    Copyright 2015 - Andrew Benson
.LINK
    https://github.com/abenson/psfirewall
#>

param([switch]$NoPing,[switch]$NoDHCP,[switch]$Auto,[string]$TCPPortsOut,[string]$UDPPortsOut,[string]$TCPPortsIn,[string]$UDPPortsIn,[string]$OutboundHosts="X:\target.hosts",[string]$InboundHosts="X:\trusted.hosts",[switch]$Simulate,[switch]$Quiet,[switch]$DenyAll,[switch]$AllowAll,[switch]$Show,[switch]$Help)

if($AllowAll -and $DenyAll) {
    Write-Host "Error: " -ForegroundColor Red -NoNewLine
    Write-Host "-AllowAll " -ForegroundColor Yellow -NoNewLine
    Write-Host "and " -NoNewline
    Write-Host "-DenyAll " -ForegroundColor Yellow -NoNewline
    Write-Host "are incompatible."
    exit
}

Remove-NetFirewallRule -All

if(-not $NoPing) {
    New-NetFirewallRule -DisplayName "ICMP" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 8 -Direction Inbound
}

New-NetFirewallRule -DisplayName "ICMP" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 8 -Direction Outbound


if(-not $NoDHCP) {
    New-NetFirewallRule -DisplayName "DHCP" 
}


if($Auto) {
    Write-Host "Automatically configuring firewall based on trusts."
    exit
}
