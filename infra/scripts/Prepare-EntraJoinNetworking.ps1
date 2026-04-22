$ErrorActionPreference = 'Stop'

$azureDnsFallback = '168.63.129.16'

$dnsConfigs = Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -notlike 'Loopback*' -and
        @($_.ServerAddresses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
    }

foreach ($dnsConfig in $dnsConfigs) {
    $servers = @($dnsConfig.ServerAddresses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($servers -contains $azureDnsFallback) {
        continue
    }

    Set-DnsClientServerAddress -InterfaceIndex $dnsConfig.InterfaceIndex -ServerAddresses ($servers + $azureDnsFallback)
}

Clear-DnsClientCache