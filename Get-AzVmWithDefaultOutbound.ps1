$ErrorActionPreference = "stop"

<#
https://jpaztech.github.io/blog/network/snat-options-for-azure-vm/

A. グローバル IP 宛の宛先が UDR で NVA (e.g. Azure Firewall) に向いていない。
B. Azure VM がデプロイされているサブネットに対し NAT Gateway が関連付けられていない。
C. Azure VM に パブリック IP アドレスが関連付けられていない。
D. 外部ロードバランサーのバックエンドプールに Azure VM が関連付けられていない。
#>

$vmList = Get-AzVM
$nicList = Get-AzNetworkInterface
$vnetList = Get-AzVirtualNetwork
$lbList = Get-AzLoadBalancer
$elbList = $lbList | Where-Object { $_.FrontendIpConfigurations.PublicIpAddress.Id -ne $null }
$routeTableList = Get-AzRouteTable

$vmWithDefaultSnat = New-Object System.Collections.ArrayList

# NIC に PIP が紐づいているか確認
function Confirm-HasPip {
    param (
        $nicId,
        $nicList
    )

    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        if ($null -eq $ipconfig.PublicIpAddress.Id) {
            return $false
        }
        else {
            return $true
        }
    }
}

# NIC の Subnet に NATGW が紐づいているか確認
function Confirm-UseNatGw {
    param (
        $nicId,
        $nicList,
        $vnetList,
        $natGwList
    )

    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        if ($null -eq ($vnetList.Subnets | Where-Object { $_.id -eq $ipconfig.Subnet.Id }).NatGateway.Id) {
            return $false
        }
        else {
            return $true
        }
    }
}

# NIC に ELB のバックエンドプールが紐づいているか確認
function Confirm-ElbBackend {
    param (
        $nicId,
        $nicList,
        $elbList 
    )
    
    # 1st check ILB と ELB のどちらでもない
    if ( $null -eq ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations.LoadBalancerBackendAddressPools) {
        return $false
    }

    # ELB か ILB か
    foreach ($LoadBalancerBackendAddressPool in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations.LoadBalancerBackendAddressPools) {
        $tmp = [regex]::Matches($LoadBalancerBackendAddressPool.id, "(.*)\/backendAddressPools\/")
        $lbId = $tmp.Groups[1].Value

        if ($null -eq ($elbList | Where-Object { $_.Id -eq $lbId })) {
            return $false
        }
        else {
            return $true
        }
    }
}

# NIC のサブネットに 0.0.0.0/0 -> VirtualAppliance な UDR があるか確認
function Confirm-useNVA {
    param (
        $nicId,
        $nicList,
        $vnetList,
        $routeTableList
    )

    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        $routeTableId = ($vnetList.Subnets | Where-Object { $_.id -eq $ipconfig.Subnet.Id }).RouteTable.Id
        foreach ($route in ($routeTableList | Where-Object { $_.id -eq $routeTableId }).Routes) {
            if ( $route.AddressPrefix -eq "0.0.0.0/0" -and $route.NextHopType -eq "VirtualAppliance") {
                return $true
            }
        }
    }
    return $false
}

foreach ($vm in $vmList) {
    foreach ($nic in $vm.NetworkProfile.NetworkInterfaces) {
        if ( (Confirm-HasPip $nic.Id $nicList) -eq $false) {
            if ( (Confirm-UseNatGw $nic.Id $nicList $vnetList) -eq $false) {
                if ( (Confirm-ElbBackend $nic.Id $nicList $elbList) -eq $false) {            
                    if ( (Confirm-useNVA $nic.Id $nicList $vnetList $routeTableList) -eq $false) {                
                        $vmWithDefaultSnat.Add($vm) > $null            
                    }
                }
            }            
        }
    }
}

$vmWithDefaultSnat
