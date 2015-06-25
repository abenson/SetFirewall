
<#
.SYNOPSIS
    Set_Firewall
.DESCRIPTION
    Configure the Windows firewall on a permit-by-except basis.
.NOTES
    File Name      : Set_Firewall.ps1
    Author         : Andrew Benson (abenson@gmail.com)
    Prerequisites  : PowerShell 6.0; Windows 11
    Copyright      : (C) 2015 Andrew Benson
.EXAMPLE
    Set_Firewall -AllowAll
.EXAMPLE
    Set_Firewall -DenyAll
.LINK
    https://github.com/abenson/SetFirewall
#>

param([switch]$NoPing,[switch]$NoDHCP,[switch]$Auto,[string]$TCPPortsOut,[string]$UDPPortsOut,[string]$TCPPortsIn,[string]$UDPPortsIn,[string]$OutboundHosts,[string]$InboundHosts,[switch]$Simulate,[switch]$Quiet,[switch]$DenyAll,[switch]$AllowAll,[switch]$Show,[switch]$Help)

if($Simulate) {
    echo "Simulation is not supported at this time."
    exit
}

if($Auto) {
    if($OutboundHosts.Length -eq 0) {
        $OutboundHosts = "C:\Tools\Scripts\Set_Firewall\Target.Hosts"
    }

    if($InboundHosts.Length -eq 0) {
        $InboundHosts = "C:\Tools\Scripts\Set_Firewall\Trusted.Hosts"
    }
}

if($Help) {
    Get-Help $script:MyInvocation.MyCommand.Path
    exit
}

if($AllowAll -and $DenyAll) {
    Write-Host "Error: " -ForegroundColor Red -NoNewLine
    Write-Host "-AllowAll " -ForegroundColor Yellow -NoNewLine
    Write-Host "and " -NoNewline
    Write-Host "-DenyAll " -ForegroundColor Yellow -NoNewline
    Write-Host "are incompatible."
    exit
}


if(-not $Quiet) {
    Write-Host "Setting defaults for the firewall."
}

Set-NetFirewallProfile -All -AllowInboundRules True -DefaultInboundAction Block -DefaultOutboundAction Block -LogAllowed False
Remove-NetFirewallRule -All

if($AllowAll) {
    if(-not $Quiet) {
        Write-Host "Allowing all traffic." -ForegroundColor Green
    }
    New-NetFirewallRule -DisplayName "Allow All In" -Profile Any -Action Allow -Direction Inbound -Enabled True > $null
    New-NetFirewallRule -DisplayName "Allow All Out" -Profile Any  -Action Allow -Direction Outbound -Enabled True > $null
    exit
}

if($DenyAll) {
    if(-not $Quiet) {
        Write-Host "Denying all traffic." -ForegroundColor Red 
    }
    New-NetFirewallRule -DisplayName "Deny All In" -Profile Any  -Action Block -Direction Inbound -Enabled True > $null
    New-NetFirewallRule -DisplayName "Deny All Out" -Profile Any  -Action Block -Direction Outbound -Enabled True > $null
    exit
}

if(-not $NoDHCP) {
    if(-not $Quiet) {
        Write-Host "Allowing DHCP..."
    }
    New-NetFirewallRule -DisplayName "DHCP" -Profile Any  -Protocol UDP -LocalPort 67-68  -Direction Inbound -Enabled True > $null
    New-NetFirewallRule -DisplayName "DHCP" -Profile Any  -Protocol UDP -LocalPort 67-68  -Direction Outbound -Enabled True > $null
}

if($OutboundHosts.Length -eq 0) {
    if(-not $NoPing) {
        if(-not $Quiet) {
            Write-Host "Allowing ICMP..."
        }
        New-NetFirewallRule -DisplayName "ICMP Echo" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 8 -Direction Outbound > $null
        New-NetFirewallRule -DisplayName "ICMP Echo Reply" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 0 -Direction Outbound > $null
    }
    if($TCPPortsOut.Length -eq 0) {
        if(-not $Quiet) {
            Write-Host "Allowing Outbound TCP..."
        }
        New-NetFirewallRule -DisplayName "Allow Outbound TCP" -Profile Any  -Protocol TCP -Enabled True -Action Allow -Direction Outbound > $null
    } else {
        if(-not $Quiet) {
            Write-Host "Allowing Outbound TCP to Ports " -NoNewline
            Write-Host $TCPPortsOut -ForegroundColor Yellow
        }

        ForEach($port in $TCPPortsOut.Split(' ')) {
            New-NetFirewallRule -DisplayName "Allow Outbound TCP port $port" -Profile Any -Protocol TCP -Enabled True -Action Allow -RemotePort $port -Direction Outbound > $null
        }

    }
    if($UDPPortsOut.Length -eq 0) {
        if(-not $Quiet) {
            Write-Host "Allowing Outbound UDP..."
        }
        New-NetFirewallRule -DisplayName "Allow Outbound UDP" -Profile Any  -Enabled True -Protocol UDP -Action Allow -Direction Outbound > $null
    } else {
        if(-not $Quiet) {
            Write-Host "Allowing Outbound UDP to ports " -NoNewline
            Write-Host $UDPPortsOut -ForegroundColor Yellow
        }
        ForEach($port in $UDPPortsOut.Split(' ')) {
            New-NetFirewallRule -DisplayName "Allow Outbound UDP port $port" -Profile Any  -Enabled True -Protocol UDP -Action Allow -RemotePort $port -Direction Outbound > $null
        }
    }
} else {
    $outbound
    if($Auto) {
        $outbound = Get-Content $OutboundHosts, $InboundHosts
    } else {
        $outbound = Get-Content $OutboundHosts
    }

    ForEach($net in $outbound) {

        if(-not $NoPing) {
            if(-not $Quiet) {
                Write-Host "Allowing ICMP to " -NoNewline
                Write-Host "$net" -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "ICMP Echo" -Profile Any -Enabled True -Action Allow -Protocol "ICMPv4" -IcmpType 8 -Direction Outbound -RemoteAddress $net > $null
            New-NetFirewallRule -DisplayName "ICMP Echo Reply" -Profile Any -Enabled True -Action Allow -Protocol "ICMPv4" -IcmpType 0 -Direction Outbound -RemoteAddress $net > $null
        }
        
        if($TCPPortsOut.Length -eq 0) {
            if(-not $Quiet) {
                Write-Host "Allowing Outbound TCP to " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "Outbound TCP $net $port" -Enabled True -Profile Any -Protocol TCP -Direction Outbound -Action Allow -RemoteAddress $net > $null
        } else {
            if(-not $Quiet) {
                Write-Host "Allowing Outbound TCP to " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host " on port " -NoNewline
                Write-Host $TCPPortsOut -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            ForEach($port in $TCPPortsOut.Split(' ')) {
                New-NetFirewallRule -DisplayName "Outbound TCP $net $port" -Enabled True -Profile Any -Protocol TCP -Direction Outbound -Action Allow -RemoteAddress $net -RemotePort $port > $null
            }
        }

        if($UDPPortsOut.Length -eq 0) {
            if(-not $Quiet) {
                Write-Host "Allowing Outbound UDP to " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "Outbound UDP $net" -Enabled True -Profile Any -Protocol UDP -Direction Outbound -Action Allow -RemoteAddress $net > $null
        } else {
            if(-not $Quiet) {
                Write-Host "Allowing Outbound UDP to " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host " on port " -NoNewline
                Write-Host $UDPPortsOut -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            ForEach($port in $UDPPortsOut.Split(' ')) {
                New-NetFirewallRule -DisplayName "Outbound UDP $net $port " -Enabled True -Profile Any -Protocol UDP -Direction Outbound -Action Allow -RemoteAddress $net -RemotePort $port > $null
            }
        }
    }
}

if($InboundHosts.Length -eq 0) {
    if(-not $NoPing) {
        if(-not $Quiet) {
            Write-Host "Allowing ICMP..."
        }
        New-NetFirewallRule -DisplayName "ICMP Echo" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 8 -Direction Inbound > $null
        New-NetFirewallRule -DisplayName "ICMP Echo Reply" -Profile Any -Action Allow -Enabled True -Protocol "ICMPv4" -IcmpType 0 -Direction Inbound > $null
    }
    if($TCPPortsIn.Length -eq 0) {
        if(-not $Quiet) {
            Write-Host "Not Allowing Inbound TCP..."
        }
    } else {
        if(-not $Quiet) {
            Write-Host "Allowing Inbound TCP to Ports " -NoNewline
            Write-Host $TCPPortsIn -ForegroundColor Yellow
        }

        ForEach($port in $TCPPortsIn.Split(' ')) {
            New-NetFirewallRule -DisplayName "Allow Inbound TCP port $port" -Profile Any -Protocol TCP -Enabled True -Action Allow -RemotePort $port -Direction Inbound > $null
        }

    }
    if($UDPPortsIn.Length -eq 0) {
        if(-not $Quiet) {
            Write-Host "Not Allowing Inbound UDP..."
        }
    } else {
        if(-not $Quiet) {
            Write-Host "Allowing Inbound UDP to ports " -NoNewline
            Write-Host $UDPPortsIn -ForegroundColor Yellow
        }
        ForEach($port in $UDPPortsIn.Split(' ')) {
            New-NetFirewallRule -DisplayName "Allow Inbound UDP port $port" -Profile Any  -Enabled True -Protocol UDP -Action Allow -RemotePort $port -Direction Inbound > $null
        }
    }
} else {
    $inbound = Get-Content $InboundHosts

    ForEach($net in $inbound) {

        if(-not $NoPing) {
            if(-not $Quiet) {
                Write-Host "Allowing ICMP from " -NoNewline
                Write-Host "$net" -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "Allow ICMP Echo from $net" -Profile Any -Enabled True -Action Allow -Protocol "ICMPv4" -IcmpType 8 -Direction Inbound -RemoteAddress $net > $null
            New-NetFirewallRule -DisplayName "Allow ICMP Echo Reply from $net" -Profile Any -Enabled True -Action Allow -Protocol "ICMPv4" -IcmpType 0 -Direction Inbound -RemoteAddress $net > $null
        }
        
        if($TCPPortsIn.Length -eq 0) {
            if(-not $Quiet) {
                Write-Host "Allowing Inbound TCP from " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "Allow Inbound TCP from $net" -Enabled True -Profile Any -Protocol TCP -Direction Inbound -Action Allow -RemoteAddress $net > $null
        } else {
            if(-not $Quiet) {
                Write-Host "Allowing Inbound TCP from " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host " on port " -NoNewline
                Write-Host $TCPPortsIn -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            ForEach($port in $TCPPortsIn.Split(' ')) {
                New-NetFirewallRule -DisplayName "Allow Inbound TCP from $net port $port" -Enabled True -Profile Any -Protocol TCP -Direction Inbound -Action Allow -RemoteAddress $net -RemotePort $port > $null
            }
        }

        if($UDPPortsIn.Length -eq 0) {
            if(-not $Quiet) {
                Write-Host "Allowing Inbound UDP from " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            New-NetFirewallRule -DisplayName "Allow Inbound UDP from $net" -Enabled True -Profile Any -Protocol UDP -Direction Inbound -Action Allow -RemoteAddress $net > $null
        } else {
            if(-not $Quiet) {
                Write-Host "Allowing Inbound UDP from " -NoNewline
                Write-Host $net -ForegroundColor Yellow -NoNewline
                Write-Host " on port " -NoNewline
                Write-Host $UDPPortsIn -ForegroundColor Yellow -NoNewline
                Write-Host "..."
            }
            ForEach($port in $UDPPortsIn.Split(' ')) {
                New-NetFirewallRule -DisplayName "Allow Inbound UDP from $net port $port" -Enabled True -Profile Any -Protocol UDP -Direction Inbound -Action Allow -RemoteAddress $net -RemotePort $port > $null
            }
        }
    }
}

if($Show) {
    Write-Host ""
    Write-Host "Set the following Defaults"
    Get-NetFirewallProfile -Name Private | Select-Object DefaultInboundAction, DefaultOutboundAction, AllowInboundRules, LogAllowed
    Write-Host " "
    Write-Host "Applied the following rules..."
    ForEach ($rule in Get-NetFirewallRule -All | Select-Object -ExpandProperty DisplayName) {
        Write-Host "    " $rule
    }
}
