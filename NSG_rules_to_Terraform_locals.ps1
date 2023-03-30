
$date = Get-Date -Format "ddMMyyyy"
$fichier = "C:\Temp\terraform_NSG_rules_$date.tf"

function Get-NSGrules-terraform()
{
    param($name)

    $nsg = Get-AzNetworkSecurityGroup -Name $name
    $nsg_rule = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg

    foreach ( $rule in $nsg_rule )
    {
        $rule_name = $rule.Name
        $Priority = $rule.Priority
        $Direction = $rule.Direction
        $Access = $rule.Access
        $Protocol = $rule.Protocol
        #$DestinationPortRange = $($rule.DestinationPortRange | ConvertTo-Json) -replace [Environment]::NewLine,"";
        $DestinationPortRange = $($($($rule.DestinationPortRange | ConvertTo-Json) -replace [Environment]::NewLine,"";).replace('[','')).replace(']','')
        $SourcePortRange = $($rule.SourcePortRange| ConvertTo-Json) -replace [Environment]::NewLine,"";
        #$SourceAddressPrefix = $($rule.SourceAddressPrefix | ConvertTo-Json) -replace [Environment]::NewLine,"";
        #$DestinationAddressPrefix = $($rule.DestinationAddressPrefix | ConvertTo-Json) -replace [Environment]::NewLine,"";
        $SourceAddressPrefix = $($($($rule.SourceAddressPrefix | ConvertTo-Json) -replace [Environment]::NewLine,"";).replace('[','')).replace(']','')
        $DestinationAddressPrefix = $($($($rule.DestinationAddressPrefix | ConvertTo-Json) -replace [Environment]::NewLine,"";).replace('[','')).replace(']','')


        #echo " { name = ${name}, priority = ${Priority}, direction = ${Direction}, access = ${Access}, protocol = ${Protocol}, dest_port = [${DestinationPortRange}], src_port = [${SourcePortRange}], src_ip = $SourceAddressPrefix, dest_ip = $DestinationAddressPrefix, description = `"`"  },"
        #$r = "        { name = `"${rule_name}`", priority = `"${Priority}`", direction = `"${Direction}`", access = ${Access}, protocol = ${Protocol}, dest_port = [${DestinationPortRange}], src_port = [${SourcePortRange}], src_ip = [${SourceAddressPrefix}], dest_ip = [${DestinationAddressPrefix}], description = `"`"  },"
        $r = "        { name = `"${rule_name}`", priority = `"${Priority}`", direction = `"${Direction}`", access = `"${Access}`", protocol = `"${Protocol}`", dest_port = [${DestinationPortRange}], src_port = [${SourcePortRange}], src_ip = [${SourceAddressPrefix}], dest_ip = [${DestinationAddressPrefix}], description = `"`"  },"
        $r.Replace('  ',' ').Replace('["*"]', '[]')
    }
}

$list_ngs = Get-AzNetworkSecurityGroup

$locals_file = "
locals {

  vnet_nsgs            = [ 
"
$locals_file | Out-File -FilePath $fichier 

foreach ( $nsg in $list_ngs.Name )
{
    $rules = Get-NSGrules-terraform -name $nsg
    #$rules | Out-File -FilePath "C:\Temp\terraform_rules_${nsg}_$date.tf" 

    $locals_file = "      {name =`"$nsg`", 
      security_rule = [ 
      "
    $locals_file | Out-File -FilePath $fichier -Append
    
    $rules | Out-File -FilePath $fichier -Append


    $locals_file = "
              ] },
"
    $locals_file | Out-File  -FilePath $fichier -Append
}


$locals_file = "
  ]
}
"

$locals_file  | Out-File  -FilePath $fichier -Append

