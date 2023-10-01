/*
- defaultOutVM01 shoud be detected because this VM uses default outbound.
- noIntUdrVM01 should be detected because this VM runs on the subnet which doesn't have 0.0.0.0/0 route.
- defaultSnatElbVM01 should be detected because this VM is the backend of the ELB which doesn't use outbound rule.

- pipVM01 should not be detected because this pip attaches to this VM.
- intUdrVM01 should not be detected because this VM runs on the subnet which udr(0.0.0.0/0 -> VirtualAppliance) related with.
- outboundElbVM01 should not be detected because this VM is the backend of the ELB which uses outbound rule.
- natGwVM91 shoud no be detected because this VM runs on the subnet which NAT Gw relates with.
*/

param location string = 'japaneast'
param suffix string = 'defaultoutbound-eval'
param adminUser string = 'AzureAadmin'
@secure()
param adminPassword string = '@P1${uniqueString(newGuid())}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${suffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'noudr'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'internetUdr'
        properties: {
          addressPrefix: '10.0.1.0/24'
          routeTable: {
            id: internetUdr.id
          }
        }
      }
      {
        name: 'noInternetUdr'
        properties: {
          addressPrefix: '10.0.2.0/24'
          routeTable: {
            id: nointernetUdr.id
          }
        }
      }
      {
        name: 'natGw'
        properties: {
          addressPrefix: '10.0.3.0/24'
          natGateway: {
            id: natGw.id
          }
        }
      }
    ]
  }
}

resource internetUdr 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'internetUdr'
  location: location
  properties: {
    routes: [
      {
        name: 'toInternet'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: '10.0.255.4'
        }
      }
      {
        name: 'dummy'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '192.168.0.0/16'
          nextHopIpAddress: '10.0.255.4'
        }
      }
    ]
  }
}

resource nointernetUdr 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'nointernetUdr'
  location: location
  properties: {
    routes: [
      {
        name: 'dummy'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '192.168.0.0/16'
          nextHopIpAddress: '10.0.255.4'
        }
      }
    ]
  }
}

resource nicDefaultOutVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicDefaultOutVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/noudr'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource defaultOutVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'defaultOutVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicDefaultOutVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'defaultOutVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource pipPipVm01 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pipPipVm01'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource nicPipVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicPipVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/noudr'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pipPipVm01.id
          }
        }
      }
    ]
  }
}

resource pipVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'pipVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicPipVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'pipVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nicInternetUdrVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicInternetUdrVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/internetudr'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource intUdrVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'intUdrVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicInternetUdrVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'intUdrVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nicNoInternetUdrVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicNoInternetUdrVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/nointernetudr'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource noIntUdrVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'noIntUdrVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicNoInternetUdrVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'noIntUdrVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nicOutboundElbVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicOutboundElbVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/noudr'
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElb', 'outboundRuleElbBackendPool')
            }
          ]
        }
      }
    ]
  }
}

resource outboundElbVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'outboundElbVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicOutboundElbVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'outboundElbVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nicdefaultSnatElbVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicdefaultSnatElbVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/noudr'
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'defaultSnatElb', 'outboundRuleElbBackendPool')
            }
          ]
        }
      }
    ]
  }
}

resource defaultSnatElbVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'defaultSnatElbVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicdefaultSnatElbVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'defaultSnatElbVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource nicNatGwVM01 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nicNatGwVM01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          primary: true
          subnet: {
            id: '${vnet.id}/subnets/natGw'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource natGwVM01 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'natGwVM01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ms'
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Linux'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicNatGwVM01.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUser
      adminPassword: adminPassword
      computerName: 'natGwVM01'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource outboundRuleElbPip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'outboundRuleElbPip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource outboundRuleElb 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: 'outboundRuleElb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: outboundRuleElbPip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'outboundRuleElbBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LoadbalanceRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'outboundRuleElb', 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElb', 'outboundRuleElbBackendPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'outboundRuleElb', 'probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: 'OutboundRule'
        properties: {
          allocatedOutboundPorts: 10000
          protocol: 'All'
          enableTcpReset: false
          idleTimeoutInMinutes: 15
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElb', 'outboundRuleElbBackendPool')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'outboundRuleElb', 'frontendIpConfig')
            }
          ]
        }
      }
    ]
  }
}

resource defaultSnatElbPip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'defaultSnatElbPip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource defaultSnatElb 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: 'defaultSnatElb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: defaultSnatElbPip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'outboundRuleElbBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LoadbalanceRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'defaultSnatElb', 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'defaultSnatElb', 'outboundRuleElbBackendPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: false
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'defaultSnatElb', 'probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: []
  }
}

resource pipNatGw 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pipNatGw'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGw 'Microsoft.Network/natGateways@2023-05-01' = {
  name: 'natGw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: pipNatGw.id
      }
    ]
  }
}

/*
- defaultOutVMSS01 shoud be detected because this VM uses default outbound.
- noIntUdrVMSS01 should be detected because this VM runs on the subnet which doesn't have 0.0.0.0/0 route.
- defaultSnatElbVMSS01 should be detected because this VM is the backend of the ELB which doesn't use outbound rule.

- intUdrVMSS01 should not be detected because this VM runs on the subnet which udr(0.0.0.0/0 -> VirtualAppliance) related with.
- outboundElbVMSS01 should not be detected because this VM is the backend of the ELB which uses outbound rule.
- natGwVMSS01 shoud no be detected because this VM runs on the subnet which NAT Gw relates with.
*/

resource defaultOutVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'defaultOutVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'defaultOutVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/noudr'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource noIntUdrVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'noIntUdrVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'noIntUdrVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/noInternetUdr'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource intUdrVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'intUdrVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'intUdrVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/internetUdr'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}



resource defaultSnatVmssElbPip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'defaultSnatVmssElbPip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource defaultSnatVmssElb 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: 'defaultSnatVmssElb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: defaultSnatVmssElbPip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'outboundRuleElbBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LoadbalanceRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'defaultSnatVmssElb', 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'defaultSnatVmssElb', 'outboundRuleElbBackendPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: false
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'defaultSnatVmssElb', 'probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: []
  }
}



resource defaultSnatElbVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'defaultSnatElbVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'defaultSnatElbVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/noudr'
                    }
                    loadBalancerBackendAddressPools: [
                       {
                         id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'defaultSnatVmssElb', 'outboundRuleElbBackendPool')
                       }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}



resource outboundRuleElbVmss01Pip 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: 'outboundRuleElbVmss01Pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource outboundRuleElbVmss01 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: 'outboundRuleElbVmss01'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: outboundRuleElbVmss01Pip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'outboundRuleElbBackendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LoadbalanceRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'outboundRuleElbVmss01', 'frontendIpConfig')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElbVmss01', 'outboundRuleElbBackendPool')
          }
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          protocol: 'Tcp'
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'outboundRuleElbVmss01', 'probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: 'OutboundRule'
        properties: {
          allocatedOutboundPorts: 10000
          protocol: 'All'
          enableTcpReset: false
          idleTimeoutInMinutes: 15
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElbVmss01', 'outboundRuleElbBackendPool')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'outboundRuleElbVmss01', 'frontendIpConfig')
            }
          ]
        }
      }
    ]
  }
}


resource outboundElbVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'outboundElbVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'outboundElbVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/noudr'
                    }
                    loadBalancerBackendAddressPools: [
                       {
                         id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'outboundRuleElbVmss01', 'outboundRuleElbBackendPool')
                       }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}


resource natGwVMSS01 'Microsoft.Compute/virtualMachineScaleSets@2023-07-01' = {
  name: 'natGwVMSS01'
  location: location
  sku: {
    capacity: 2
    name: 'Standard_B1ms'
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          osType: 'Linux'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        adminUsername: adminUser
        adminPassword: adminPassword
        computerNamePrefix: 'natGwVMSS01'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: '${vnet.id}/subnets/natGw'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}
