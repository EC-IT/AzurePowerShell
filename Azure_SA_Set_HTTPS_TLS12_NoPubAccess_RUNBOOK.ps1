# MPE - JAN 2022
# Storage Account Set TLS 1.2
Import-Module Az.Storage

#Connection
$connectionName = "AzureRunAsConnection"
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName  
Add-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint


function Set-SecureStorageAccount()
{
    $sas = Get-AzStorageAccount

    foreach($sa in $sas)
    {
        if ( $sa.MinimumTlsVersion -ne "TLS1_2" )
        {        
                Set-AzStorageAccount -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -MinimumTlsVersion TLS1_2
        }
       # if ( $sa.AllowBlobPublicAccess )
       # {        
       #         Set-AzStorageAccount -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -AllowBlobPublicAccess $false
       # }
        if ( ! $sa.EnableHttpsTrafficOnly )
        {        
                Set-AzStorageAccount -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -EnableHttpsTrafficOnly $true
        }
    }
}

if ($servicePrincipalConnection)
{
    Set-SecureStorageAccount
}
