function Get-DestinationPrefix {  
    param (  
        [Parameter(Mandatory = $true)]  
        [string]$IpAddress,  
  
        [Parameter(Mandatory = $true)]  
        [int]$PrefixLength  
    )  
  
    $ipAddressBinary = Convert-IpAddressToBinary -IpAddress $IpAddress  
  
    $prefixBinary = $ipAddressBinary.Substring(0, $PrefixLength).PadRight(32, '0')
  
    $destinationPrefix = Convert-BinaryToDottedDecimal -Binary $prefixBinary  
  
    return $destinationPrefix  
}  
  
function Convert-IpAddressToBinary {  
    param (  
        [Parameter(Mandatory = $true)]  
        [string]$IpAddress  
    )  
  
    $ipAddressOctets = $IpAddress.Split('.')  
    $binary = ''  
  
    foreach ($octet in $ipAddressOctets) {  
        $binary += Convert-DecimalToBinary -Decimal $octet  
    }  
  
    return $binary  
}  
  
function Convert-DecimalToBinary {  
    param (  
        [Parameter(Mandatory = $true)]  
        [int]$Decimal  
    )  
  
    if ($Decimal -eq 0) {
        return '00000000'
    }
    $binary = ''  
    while ($Decimal -gt 0) {  
        $remainder = $Decimal % 2
        $binary = $remainder.ToString() + $binary
        $Decimal = ($Decimal - $remainder) / 2
    }  
  
    return $binary.PadLeft(8, '0')  
}  
  
function Convert-BinaryToDottedDecimal {  
    param (  
        [Parameter(Mandatory = $true)]  
        [string]$Binary  
    )  
  
    $segments = @()  
    $segments += $Binary.Substring(0, 8)  
    $segments += $Binary.Substring(8, 8)  
    $segments += $Binary.Substring(16, 8)  
    $segments += $Binary.Substring(24, 8)  
  
    $dottedDecimal = ''  
    foreach ($segment in $segments) {
        $decimal = Convert-BinaryToDecimal -Binary $segment
        $dottedDecimal =  $dottedDecimal + $decimal + '.'  
    }  
  
    return $dottedDecimal.TrimEnd('.')  
}  
  
function Convert-BinaryToDecimal {  
    param (  
        [Parameter(Mandatory = $true)]  
        [string]$Binary  
    )  
  
    $decimal = 0  
    for ($i = 0; $i -lt $Binary.Length; $i++) {  
        if ($Binary[$i] -eq '1') {  
            $decimal += [Math]::Pow(2, $Binary.Length - 1 - $i)  
        }  
    }  
  
    return $decimal  
}

Get-NetIPConfiguration | 
    Where-Object { $_.IPv4DefaultGateway -ne $null } | 
        Select-Object IPv4Address,InterfaceIndex | 
            Format-Table -AutoSize

$ifIndex_inter = Read-Host "Input INTER-NET Gateway ifIndex"
Write-Host "Your Choice: $ifIndex_inter!"
$ifIndex_intra = Read-Host "Input INTRA-NET Gateway ifIndex"
Write-Host "Your Choice: $ifIndex_intra!"

$interGwIpAddr = (Get-NetIPConfiguration | Select-Object -ExpandProperty IPv4DefaultGateway | Where-Object { $_.ifIndex -eq $ifIndex_inter })
Write-Host $interGwIpAddr.NextHop

$intraGwIpAddr = (Get-NetIPConfiguration | Select-Object -ExpandProperty IPv4DefaultGateway | Where-Object { $_.ifIndex -eq $ifIndex_intra })
Write-Host $intraGwIpAddr.NextHop
$intraIpInfo = (Get-NetIPConfiguration | Select-Object -ExpandProperty IPv4Address | Where-Object { $_.ifIndex -eq $ifIndex_intra})
$prefixLength = $intraIpInfo.PrefixLength
$intraIpAddr = $intraIpInfo.IPv4Address
$intraDestinationPrefix = Get-DestinationPrefix -IpAddress $intraIpAddr -PrefixLength $prefixLength
Write-Host "$intraDestinationPrefix"


#route delete 0.0.0.0
#route add 0.0.0.0 mask 0.0.0.0 192.168.43.1 -p
#route add 192.168.0.0 mask 255.255.0.0 192.168.0.254 -p
#--------------------------------------------------------------
Remove-NetRoute -DestinationPrefix '0.0.0.0/0' -Confirm:$false
New-NetRoute -DestinationPrefix '0.0.0.0/0' -ifIndex $ifIndex -NextHop $interGwIpAddr.NextHop -RouteMetric 1 -Confirm:$false
New-NetRoute -DestinationPrefix $intraDestinationPrefix -NextHop '192.168.0.254' -Confirm:$false

$null = Read-Host "Press any key to exit ..."