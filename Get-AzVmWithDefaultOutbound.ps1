$ErrorActionPreference = "stop"

<#
https://jpaztech.github.io/blog/network/snat-options-for-azure-vm/

A. グローバル IP 宛の宛先が UDR で NVA (e.g. Azure Firewall) に向いていない。
B. Azure VM がデプロイされているサブネットに対し NAT Gateway が関連付けられていない。
C. Azure VM に パブリック IP アドレスが関連付けられていない。
D. 外部ロードバランサーのバックエンドプールに Azure VM が関連付けられていない。
#>

$vmList = Get-AzVM
$vmssList = Get-AzVMss
$nicList = Get-AzNetworkInterface
$vnetList = Get-AzVirtualNetwork
$lbList = Get-AzLoadBalancer
$elbList = $lbList | Where-Object { $_.FrontendIpConfigurations.PublicIpAddress.Id -ne $null }
<#
$elbList = $lbList | Where-Object { 
    $_.FrontendIpConfigurations.PublicIpAddress.Id -ne $null -and `
        $_.LoadBalancingRules[0].DisableOutboundSNAT -eq $true
}
#>

$routeTableList = Get-AzRouteTable

$vmWithDefaultSnat = New-Object System.Collections.ArrayList
$vmssWithDefaultSnat = New-Object System.Collections.ArrayList

# NIC に PIP が紐づいているか確認
function Confirm-HasPip {
    param (
        $nicId,
        $nicList
    )

    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        if ($null -ne $ipconfig.PublicIpAddress.Id) {
            return $true
        }
    }
    return $false
}

# NIC の Subnet に NATGW が紐づいているか確認
function Confirm-UseNatGw {
    param (
        $nicId,
        $nicList,
        $vnetList
    )

    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        if ($null -ne ($vnetList.Subnets | Where-Object { $_.id -eq $ipconfig.Subnet.Id }).NatGateway.Id) {
            return $true
        }
    }

    return $false
}

function Confirm-UseNatGwForVmss {
    param (
        $nicConfig,
        $vnetList
    )

    foreach ($ipconfig in $nicConfig.IpConfigurations) {
        if ($null -ne ($vnetList.Subnets | Where-Object { $_.id -eq $ipconfig.Subnet.Id }).NatGateway.Id) {
            return $true
        }
    }
    return $false
}

# NIC に ELB のバックエンドプールが紐づいているか確認
function Confirm-ElbBackend {
    param (
        $nicId,
        $nicList,
        $elbList 
    )
    
    # 1st check ILB と ELB のどちらでもない
    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        if ( $null -eq $ipconfig.LoadBalancerBackendAddressPools.Id) {
            return $false
        }        
    }

    # 2nd Outbound Rule の ELB 配下ではない
    foreach ($ipconfig in ($nicList | Where-Object { $_.Id -eq $nicId }).IpConfigurations) {
        foreach ($LoadBalancerBackendAddressPool in $ipconfig.LoadBalancerBackendAddressPools) {
            $tmp = [regex]::Matches($LoadBalancerBackendAddressPool.id, "(.*)\/backendAddressPools\/")
            $lbId = $tmp.Groups[1].Value

            if ($null -ne ($elbList | Where-Object { $_.Id -eq $lbId })) {
                return $true
            }
        }
    }
    return $false
}

function Confirm-ElbBackendForVmss {
    param (
        $nicConfig,
        $elbList 
    )
    
    # 1st check ILB と ELB のどちらでもない
    foreach ($ipconfig in $nicConfig.IpConfigurations) {
        if ( $null -eq $ipconfig.LoadBalancerBackendAddressPools.Id) {
            return $false
        }        
    }

    # 2nd Outbound Rule の ELB 配下ではない
    foreach ($ipconfig in $nicConfig.IpConfigurations) {
        foreach ($LoadBalancerBackendAddressPool in $ipconfig.LoadBalancerBackendAddressPools) {
            $tmp = [regex]::Matches($LoadBalancerBackendAddressPool.id, "(.*)\/backendAddressPools\/")
            $lbId = $tmp.Groups[1].Value

            if ($null -ne ($elbList | Where-Object { $_.Id -eq $lbId })) {
                return $true
            }
        }
    }
    return $false
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

# NIC のサブネットに 0.0.0.0/0 -> VirtualAppliance な UDR があるか確認
function Confirm-useNVAForVmss {
    param (
        $nicConfig,
        $vnetList,
        $routeTableList
    )

    foreach ($ipconfig in $nicConfig.IpConfigurations) {
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
        if ( (Confirm-useNVA $nic.Id $nicList $vnetList $routeTableList) -eq $true) {
            continue
        }  

        if ( (Confirm-UseNatGw $nic.Id $nicList $vnetList) -eq $true) {
            continue
        }

        if ( (Confirm-HasPip $nic.Id $nicList) -eq $true) {
            continue
        }

        if ( (Confirm-ElbBackend $nic.Id $nicList $elbList) -eq $true) {
            continue
        }            
        
        $vmWithDefaultSnat.Add($vm) > $null            
        
    }
}


Write-Output "The following Vms uses a default outbound access"
$vmWithDefaultSnat

foreach ($vmss in $vmssList) {
    foreach ($nicConfig in $vmss.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations) {
        if ( (Confirm-UseNatGwForVmss $nicConfig $vnetList) -eq $true) {
            continue
        }
        if ( (Confirm-ElbBackendForVmss $nicConfig $elbList) -eq $true) {
            continue
        }         
        if ( (Confirm-useNVAForVmss $nicConfig $vnetList $routeTableList) -eq $true) {
            continue
        }                
        $vmssWithDefaultSnat.Add($vmss) > $null                                
                          
    }
}

Write-Output "The following Vms uses a default outbound access"
$vmssWithDefaultSnat | Select-Object ResourceGroupName, Name, Location, `
@{Label = "Sku"; Expression = { $_.sku.Name } }, @{Label = "Capacity"; Expression = { $_.sku.Capacity } }  | ft *