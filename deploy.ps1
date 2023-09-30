New-AzResourceGroup -Name eval-defaultOutbound -Location japaneast
New-AzResourceGroupDeployment -Name 0930 -TemplateFile .\testenv.bicep -ResourceGroupName eval-defaultOutbound

Remove-AzResourceGroup -Name eval-defaultOutbound