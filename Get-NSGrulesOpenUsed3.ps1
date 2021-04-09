# MPE - juin 2020
# identifie les flux reseaux passant par des regles peu contraignante


function Get-AzWorkspaceID()
{
    $workspaces = Get-AzOperationalInsightsWorkspace
    foreach ( $workpace in $workspaces)
    {
        if ( $workpace.Name -notlike "*Default*" -and $workpace.Name -notlike "*Test*"  -and $workpace.Name -notlike "*dev*" )
        {
            return $workpace.CustomerId.Guid;
        }
    }
}
$WorkspaceID = Get-AzWorkspaceID


# test is le NSG est connecte
function NSGused()
{
    param( $nsg)

    $total = $nsg.NetworkInterfaces.Count + $nsg.Subnets.Count

    if ( $total -eq 0 )
    {
        return 0
    }
    else
    {
        return 1
    }

}

# test si la regle est ouverte
function RuleIsPermissive()
{
    param ( $rule )

    $Permissive = 0
    
    if ( $rules.Access.ToString() -like "*Allow*" )
    {
        if ( $rules.Direction.ToString() -like "*Inbound*" )
        {
            if (($rules.DestinationPortRange[0] -ne 80 ) -and ( $rules.DestinationPortRange[0] -ne 443))
            {
                if (( $rules.SourceAddressPrefix[0] -contains '*' ) -or ( $rules.DestinationPortRange[0]  -contains '*' ))
                {
                    $Permissive = 1
                }                        
            }
        } 
    }
    return $Permissive
}

# liste les regles tres ouverte des NSG utilise
function Get-NSGrulesOpen()
{
    $nsg_list = Get-AzNetworkSecurityGroup
        
    $nsg_rules_open = @()
    foreach ($nsg in $nsg_list)
    {

        if ( NSGused($nsg) -eq 1 )
        {
            foreach ( $rules in $nsg.SecurityRules)
            {
                if ( RuleIsPermissive($rules) -eq 1) 
                {

                    $regles  = "" | Select NSG,Name,Protocol,SourceAddressPrefix,DestinationAddressPrefix,DestinationPortRange
                    $regles.NSG =  $nsg.Name
                    $regles.Name = $rules.Name
                    $regles.Protocol = $rules.Protocol
                    $regles.SourceAddressPrefix = $rules.SourceAddressPrefix
                    $regles.DestinationAddressPrefix = $rules.DestinationAddressPrefix
                    $regles.DestinationPortRange = $rules.DestinationPortRange
                    $nsg_rules_open += , $regles
               
                }               
            }
        }
    }
    $nsg_rules_open
}

$rules_open = Get-NSGrulesOpen

# liste les flux reseau passant par des regle tres ouverte
$list_flux = @()
foreach( $rule in $rules_open)
{
    $name = $rule.Name
    $nsg = $rule.NSG

    echo "> NSG : $nsg - Rule : $name"
 
    $q = "AzureNetworkAnalytics_CL | where NSGRule_s == `"$name`" and TimeGenerated > ago(24h) | distinct SrcIP_s, DestIP_s, DestPort_d"
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId "$WorkspaceID" -Query $q
    $queryResults.Results
}