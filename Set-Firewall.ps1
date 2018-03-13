
# Copyright (c) 2015 Andrew Benson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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

.PARAMETER Version
    Print version information.

.PARAMETER AllowAll

    Configures the firewall to allow all traffic.

.PARAMETER DenyAll

    Configures the firewall to deny all traffic.

.PARAMETER NoPing

    Disables ICMP echo and responses.

.PARAMETER NoDHCP

    Disables DHCP lease requests.

.PARAMETER Auto

    Configure firewall with exceptions automatically.
    Implies -OutboundHosts set to "C:\Tools\Scripts\Set_Firewall\Target.Hosts"
    Implies -InboundHosts  set to "C:\Tools\Scripts\Set_Firewall\Trusted.Hosts"

.PARAMETER TCPPortsOut

    Limit outbound TCP ports to these only. Specified as single ports or ranges, separated by commas.

.PARAMETER UDPPortsOut

    Limit outbound TCP ports to these only. Specified as single ports or ranges, separated by commas.

.PARAMETER TCPPortsIn

    Allow inbound TCP ports. Specified as single ports or ranges, separated by commas.

.PARAMETER UDPPortsIn

    Allow inbound UDP ports. Specified as single ports or ranges, separated by commas.

.PARAMETER OutboundHosts

    Limit outbound connections to hosts specified in file. One host or CIDR per line.

.PARAMETER InboundHosts

    Limit inbound connections to hosts specified in file. One host or CIDR per line.

.EXAMPLE

    Set_Firewall -TCPPortsIn 445 -NoPing

    Configure firewall to allow 445 inbound but not respond to ping.


.EXAMPLE

    Set_Firewall -AllowAll

    Clear all rules (useful for troubleshooting)

.EXAMPLE

    Set_Firewall -Auto

    Configure firewall automatically.
    Target.Hosts and Trusted.Hosts must be configured correctly in C:\Tools\Scripts\Set_Firewall

.LINK
    https://github.com/abenson/SetFirewall
#>

param([switch]$NoPing,[switch]$NoDHCP,[switch]$Auto,[string]$TCPPortsOut,[string]$UDPPortsOut,[string]$TCPPortsIn,[string]$UDPPortsIn,[string]$OutboundHosts,[string]$InboundHosts,[switch]$Simulate,[switch]$Quiet,[switch]$DenyAll,[switch]$AllowAll,[switch]$Show,[switch]$Help,[switch]$Version)

$VERSIONSTRING="0.4"

if($Version) {
    Write-Host "Set-Firewall v" -NoNewLine
    Write-Host $VERSIONSTRING
    exit
}

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
        $net = $net.Trim()
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
            New-NetFirewallRule -DisplayName "Outbound TCP $net" -Enabled True -Profile Any -Protocol TCP -Direction Outbound -Action Allow -RemoteAddress $net > $null
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
        $net = $net.Trim()
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
