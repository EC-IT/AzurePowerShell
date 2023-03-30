# MPE - 2019 2020 2021
# Usage Run : AzQualityInstall   and    AzQualityCheck
Import-Module Az.Accounts, Az.RecoveryServices, Az.Compute, Az.Websites, Az.Resources, Az.Automation, Az.OperationalInsights, Az.Network, Az.Sql  #, Az.ApplicationInsights


function AzQualityInstall()
{
    Install-Module Az.Accounts, Az.RecoveryServices, Az.Compute, Az.Websites, Az.Resources, Az.Automation, Az.OperationalInsights, Az.Network, Az.Sql  #, Az.ApplicationInsights
}

$global:backupdetails = @()
$global:vmbkp = @()

function Write-Title()
{
    Param($text)
    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue  $text
}

function Get-All-Backup-Details() {
    $ServicesVault = Get-AzRecoveryServicesVault -WarningAction SilentlyContinue

    ForEach ($vaultName in $ServicesVault)
    {
        Set-AzRecoveryServicesVaultContext -Vault $vaultName -WarningAction SilentlyContinue
        $BackupContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -WarningAction SilentlyContinue

        ForEach ($vm in $BackupContainer)
        {
            $global:backupdetails += @{ vm = $vm.FriendlyName; rg = $vm.ResourceGroupName; vault = $vaultName.Name }
            $global:vmbkp  += @{ vm = $vm.FriendlyName }
        }
    }
}

#
##### BACKUP VM #####
#
function checkBackupVM()
{
    
    Write-Title "VM without backup : "

    # recupere la liste des VM sauvegardee
    Get-All-Backup-Details

    # recupere la liste des VM
    $listvm = Get-AzVM

    # pour chaque VM...
    foreach ( $vm in $listvm.Name )
    {

    if ( $vm -notlike "*TEST*" )
    {
        # ...si elle n'est pas sauvegardee : affiche le nom
        if ( ! $global:vmbkp.vm.Contains($vm) )
        {
            Write-Host $vm -BackgroundColor Red
        }
    }
    }

}


function AppServiceNoBackup
{
    Param($ResourceGroupName, $Name)

    $backup = Get-AzWebAppBackupList -ResourceGroupName $ResourceGroupName -Name $Name
    
    if ( $backup.Count -eq 0 )
    {    
        Write-Host $app.Name  #-BackgroundColor Red
    }
}

#
##### BACKUP APP SVC #####
#
function checkAppServiceBackup
{    
    Write-Title "App Service without backup : "

    $asp= Get-AzAppServicePlan # -ResourceGroupName $ResourceGroupName
    foreach( $AppPlan in $asp )
    {

        if ( $AppPlan.Sku.Capacity -ne 0 )
        {
            $apps=Get-AzWebApp -AppServicePlan $AppPlan
            Foreach($app in $apps) 
            { 
                AppServiceNoBackup  -ResourceGroupName $app.ResourceGroup -Name $app.Name    
            }
        }
    }     
}


#
##### VM NON CHIFFRE #####
#

function checkVMcrypted()
{
    

    Write-Title "VM Data unencrypted :" 

    # pour chaque VM...
    foreach ( $vm in $listvm )
    {
        if ( $vm.StorageProfile.OsDisk.OsType -eq "Windows"  )
        {
            $encryptedstatus = Get-AzVmDiskEncryptionStatus -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
    
            if (  $encryptedstatus.DataVolumesEncrypted -eq "NotEncrypted"  )
            {
                   Write-Host $vm.Name #-BackgroundColor Red
        
            }
        }
    }
}

#
##### VM SANS VERROU #####
#

function checkVMLock()
{    
    Write-Title "VM No Lock :" 
    
    if ( !$listvm ) { $global:listvm = Get-AzVM }

    # pour chaque VM
    foreach ( $vm in $listvm )
    {
        # recupere les verrous
        $locks = Get-AzResourceLock -ResourceName $vm.Name -ResourceGroupName $vm.ResourceGroupName -ResourceType 'Microsoft.Compute/virtualMachines'
        
        # recupere les verrous specifique a la VM
        $list_lock = @()    
        foreach ( $lock in $locks)
        {            
            # Si le verrou est sur la VM
            if ( $lock.ResourceType -like 'Microsoft.Compute/virtualMachines')
            {
                $list_lock += $lock
            }
        }
        
        # Si aucun verrou sur la VM
        if ( $list_lock.Count -eq 0 ) 
        {
            $vm.Name
        }        
    }
}

#
##### RG SANS VERROU #####
#

function checkRGLock()
{    
    Write-Title "RessourceGroup without Lock :" 

    $rg_list = Get-AzResourceGroup

    # pour chaque RG...
    foreach ( $ResourceGroup in $rg_list )
    {
        # ... recupere les verrous
        $locks = Get-AzResourceLock -ResourceGroupName $ResourceGroup.ResourceGroupName
        
        $list_lock = @()
        # recherche les verrous qui portent sur tout le RG
        foreach ( $lock in $locks )
        {
            # Si le verrou est sur le ressource group
            if ( $lock.ResourceType -like 'Microsoft.Authorization/locks')
            {
                $list_lock += $lock
            }
        }
        
        # Si aucun verrou ne porte sur tout le RG
        if ( $list_lock.Count -eq 0 )
        {
            if ( $ResourceGroup.ResourceGroupName -notlike "AzureBackupRG_*" )
            {
                Write-Host $ResourceGroup.ResourceGroupName -BackgroundColor Red            
            }
        }
    }
}
#
##### VM SANS AcceleratedNetwork #####
#

function checkVMAcceleratedNetwork()
{    
    Write-Title "VM without AcceleratedNetwork :" 

    # recupere la liste des modeles
    $listsize = Get-AzVMSize -Location 'West Europe'

    # pour chaque VM...
    foreach ( $vm in $listvm )
    {
            # ... recupere le verrou
        $nicname = $vm.NetworkProfile.NetworkInterfaces.Id.Split('/')[8]
        $rg = $vm.ResourceGroupName
        $nic=Get-AzNetworkInterface -Name $nicname 
        
        # nombre CPU 
        $size = $vm.HardwareProfile
        $vmsize = $listsize | ?{ $_.Name -eq $size.VmSize }
        $cpuCores = [int]$vmsize.NumberOfCores
    
        # si AcceleratedNetwork n'est pas
        if ( ($nic.EnableAcceleratedNetworking -ne "True" )  -and ($cpuCores -gt 2) )
        {
            Write-Host $vm.Name -BackgroundColor Red
        }
    }

}

    #
    ##### VM SANS MAJ AUTO #####
    #

function checkVMupdate()
{    
    Write-Title "VM no auto update :" 

    # Get All WorkSpace
    $all_workspace = Get-AzOperationalInsightsWorkspace

    # Get All AutomationAccount
    $AutomationAccountList = @()
    foreach ( $workspace in $all_workspace )
    {
        $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $workspace.ResourceGroupName
        $AutomationAccountList += $AutomationAccount
    }

    
    foreach ( $AutomationAccount in $AutomationAccountList)
    {
        # recupere les Update
        $ECupdate = Get-AzAutomationSoftwareUpdateMachineRun -ResourceGroupName $AutomationAccount.ResourceGroupName -AutomationAccountName $AutomationAccount.AutomationAccountName

        # pour chaque VM...
        foreach ( $vm in $listvm )
        { 
            # si la VM n'a pas recu de maj via ScheduledUpdate
            if ( $($ECupdate.TargetComputer -match $vm.Name).Count -lt 1  )
            {          
                if ( $vm.StorageProfile.OsDisk.OsType -eq "Windows"  )
                {
                    Write-Host $vm.Name -BackgroundColor Red
                }
            }
        }
    }
}

#
##### VM sans log analytics #####
#

function checkVMloganalytics()
{    
    Write-Title "VM no LogAnalytics :"

    $all_workspace = Get-AzOperationalInsightsWorkspace

    $VMconnect = @()
    foreach($workspace in $all_workspace )
    {
        # recupere les VM dans log analytics
        $q = 'Perf | distinct Computer'
        $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $q
        $VMconnect += ($queryResults.Results)
    }

    # pour chaque VM...
    foreach ( $vm in $listvm )
    { 
    
        if ( $vm.StorageProfile.OsDisk.OsType -eq "Windows"  )
        {
            # si la VM n'est pas presente dans les logs : afficher son nom
            if ( ! $($VMconnect -match $vm.Name)  )
            {
                Write-Host $vm.Name -BackgroundColor Red
            }
        }
    }
}

#
##### DISQUE NON RELIE A UNE VM #####
#

function checkDiskUnattached()
{    
    Write-Title "unattached Managed Disk : "
    $managedDisks = Get-AzDisk

    foreach ($md in $managedDisks) 
	{
        if(($md.ManagedBy -eq $null) -and ($md.DiskState -notlike '*ActiveSAS*')){
                    
                Write-Host  $($md.Name) -BackgroundColor Red
        }
     } 
 }
 
#
##### INTERFACE RESEAU NON RELIE A UNE VM #####
#

function checkNICunattached()
{    
    Write-Title "unattached NetworkInterface : "

    $managedDisks = Get-AzNetworkInterface

    foreach ($md in $managedDisks) {
    
        if ( $md.Name -notlike "anf*") 
        {
            if(  ($md.VirtualMachine -eq $null) -and ($md.IpConfigurations.Name -inotmatch "privateEndpoint" )  ) {
                    
                    Write-Host  $($md.Name) -BackgroundColor Red
            }
        }
     } 
 }
 
#
##### IP non static #####
#
function checkIPdynamic()
{    
    Write-Title "Dynamic IP :  "

    $NetworkInterfaces = Get-AzNetworkInterface

    foreach ($md in $NetworkInterfaces) {
    
        if( ($md.IpConfigurations[0].PrivateIpAllocationMethod -contains "Dynamic") -and ( $md.VirtualMachine ) ){
                    
                Write-Host  $($md.Name) -BackgroundColor Red
        }
     } 
 }

#
##### IP PUBLIQUE NON ATTACHE #####
#
function checkIPunattached()
{    
    Write-Title "unattached Public IP : "

    $ippublic = Get-AzPublicIpAddress

    foreach ($md in $ippublic) {

         if($md.IpConfiguration -eq $null){
                   
                Write-Host "$($md.Name) $($md.IpAddress)" -BackgroundColor Red
        }
     } 
 }

 #
##### VM SANS MONITORINGAGENT #####
#

function checkVMmontiored()
{    
    Write-Title "VM without Monitoring Agent : "

    foreach ($vm in $listvm) {
        #if ( $($vm.Extensions.id -match "MicrosoftMonitoringAgent").Count -eq 0 )
        if ( $($vm.Extensions.id -like "*Agent*").Count -eq 0 )
        {
            Write-Host $vm.Name -BackgroundColor Red
        }
    }
}

 #
##### VM SANS ENCRYPTION AGENT #####
#
function checkVMuncrypted()
{    
    Write-Title "VM without Encryption Agent : "
    foreach ($vm in $listvm) {
        if ( $vm.StorageProfile.OsDisk.OsType -eq "Windows"  )
        {
            if ( $($vm.Extensions.id -match "AzureDiskEncryption").Count -eq 0 )
            {
                Write-Host $vm.Name -BackgroundColor Red
            }
        }
    }
}

 #
##### VM SANS ZONE #####
#
function checkVMzone()
{    
    Write-Title "VM without Zone :"

    foreach ($vm in $listvm) {
        if ( $vm.Zones.Count -eq 0 )
        {
            Write-Host $vm.Name -BackgroundColor Red
        }
    }
}

 #
##### LISTE DES SNAPSHOT #####
#

function checkSnapshot()
{
    
    Write-Title "Snapshots :"
    $sslist = Get-AzSnapshot

    $sslist.Name
}
#
##### LISTE DES CERTIFICAT AUOTMATION QUI EXPIRE #####
#

function checkAzureCert()
{
    Write-Title "Azure Certificate expiring :"

    $listautomation = Get-AzAutomationAccount
    foreach ( $AutomationAccount in $listautomation)
    {        
        $listcert = Get-AzAutomationCertificate -AutomationAccountName $AutomationAccount.AutomationAccountName -ResourceGroupName $AutomationAccount.ResourceGroupName
        foreach ( $cert in $listcert)
        {
            if ( $(Get-Date).AddDays(60) -gt $cert.ExpiryTime.DateTime)
            {
                Write-Host "Expiration du certificat $($cert.Name) pour $($AutomationAccount.AutomationAccountName) le $($cert.ExpiryTime.DateTime)" -BackgroundColor Red
            }
        }
    }
}

#
##### LISTE LAS BASES SANS POOL #####
#
function checkElasticPool()
{    
    Write-Title "Azure SQL Database outside SQL elastic pool :"

    $SqlServerList = Get-AzSqlServer

    foreach ( $SqlServer in $SqlServerList)
    {
        # liste les base
        $dbppd = Get-AzSqlDatabase -ServerName $SqlServer.ServerName -ResourceGroupName $SqlServer.ResourceGroupName

        # pour chaque bases
        foreach ( $db in $dbppd )
        {
            # si aucun pool : afficher le nom
              if ( (! $db.ElasticPoolName ) -and ( $db.DatabaseName -ne "master"  )  )
              {
                Write-Host $db.DatabaseName  -BackgroundColor Red
              }
        }
    }
}

#
##### LISTE LES CERTIF APP SERVICE QUI EXPIRE BIENTOT #####
#
function checkAppServicesCert()
{
    Write-Title "AppService Certificat expiring :"

    # Liste les ceritifcats
    $AzWebAppCertificate = Get-AzWebAppCertificate

    $now = $(get-date)

    # pour chaque certificat
    foreach ( $Certificate in $AzWebAppCertificate )
    {
    
        # Si il expire dans moins de 30 jours
        if ( ($Certificate.ExpirationDate) -lt ($now.AddDays(30)) )
        {
            # Si il n'a pas deja expire
            if ( ($Certificate.ExpirationDate) -gt ($now) )
            {
                $exp = $Certificate.SubjectName + " " + $Certificate.ExpirationDate
                Write-Host $exp  -BackgroundColor Red
            }
        }
    }
}

function check-StorageAccount()
{
    # liste SA
    #$list_sa = Get-AzStorageAccount
    $sas = Get-AzStorageAccount

    # Pour chaque SA recupe Firewall HTTPS TLS
#    $liste_sa_param = @()
#    foreach ($sa in $list_sa)
#    {
#        $sa_param = "" | select StorageAccountName,FWDefaultAction,FWIpRules,EnableHttpsTrafficOnly,MinimumTlsVersion
#        $sa_param.StorageAccountName = $sa.StorageAccountName
#        $sa_param.FWDefaultAction = $sa.NetworkRuleSet.DefaultAction
#        $sa_param.FWIpRules = $sa.NetworkRuleSet.IpRules.Count
#        $sa_param.EnableHttpsTrafficOnly = $sa.EnableHttpsTrafficOnly
#        $sa_param.MinimumTlsVersion = $sa.MinimumTlsVersion
#    
#        $liste_sa_param+=$sa_param
#    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "StorageAccount without FireWall :"
    #foreach($sa in $liste_sa_param)
    foreach($sa in $sas)
    {
        #if ( $sa.FWDefaultAction -eq "Allow" )
        if ( $sa.NetworkRuleSet.DefaultAction -eq "Allow" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "StorageAccount without HTTPS only :"
    #foreach($sa in $liste_sa_param)
    foreach($sa in $sas)
    {
        if ( $sa.EnableHttpsTrafficOnly -ne "True" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "StorageAccount without minimum TLS 1.2 :"
    #foreach($sa in $liste_sa_param)
    foreach($sa in $sas)
    {
        if ( $sa.MinimumTlsVersion -ne "TLS1_2" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }
    
    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "SA with public BLOB Access :"
   # foreach ( $sa in $list_sa  )
    foreach ( $sa in $sas  )
    {
        if ( $sa.AllowBlobPublicAccess )
        {
            $sa.StorageAccountName
        }
    }
}


#
##### LISTE LES PRIVATE ENDPOINT EN ERR #####
#
function checkPrivateEndpoint()
{    
    Write-Title "Private Endpoint in error :"
    
    $pes = Get-AzPrivateEndpoint
    foreach($pe in $pes)
    {
        if ( $pe.ProvisioningState -notlike "Succeeded" )
        {
            Write-Host $pe.Name -BackgroundColor Red
        }
    }
}

#
##### LISTE RG VIDE #####
#
function Get-EmptyResourceGroup()
{
    $rg_list = Get-AzResourceGroup

    Write-Title "Empty ResourceGroup :"

    foreach ( $rg in $rg_list )
    {
        if ( $(Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count -eq 0 )
        {
            $rg.ResourceGroupName
        }
    }
}
#
##### LISTE APP PLAN VIDE #####
#
function Get-EmptyAppServicePlan()
{
    $plans = Get-AzAppServicePlan
    
    Write-Title "Empty AppPlan :"

    foreach ( $plan in $plans )
    {
        $apps = Get-AzWebApp -AppServicePlan $plan
        if ( $apps.Count -eq 0 )
        {
            $plan.Name

        }
    }
}

#
##### LISTE APP ARRETE #####
#
function Get-StoppedWebApp()
{
    $apps = Get-AzWebApp

    Write-Title "Stopped WebApps :"

    foreach ( $app in $apps )
    {
        if ( $app.State -ne "Running" )
        {
            echo "$($app.Name)`t$($app.ResourceGroup)"
        }
    }
}

#
##### PRIVATE ENDPOINT DISCONNECTED #####
#
function Get-PrivateEndpointError()
{
    $pe_list = Get-AzPrivateEndpoint

    Write-Title "PrivateEndpoint disconnected : "

    foreach ( $pe in $pe_list )
    {
        if ( $pe.PrivateLinkServiceConnections[0].PrivateLinkServiceConnectionState.Status -ne "Approved" )
        {
            $pe.Name 
        }
    }
}




function AzQualityCheck()
{          
    if ( ! $(Get-AzSubscription)[0].Id ) { echo "Not connected, run :"; echo "Connect-AzAccount -UseDeviceAuthentication"; return 1; } 
    
    $global:listvm = Get-AzVM

    if ( $global:listvm.Count -lt 1 ) { return 1; }

    #checkAppServiceBackup
    checkBackupVM
    checkVMuncrypted
    checkVMcrypted
    checkVMLock
    checkVMupdate
    checkVMloganalytics
    checkVMmontiored
    checkVMAcceleratedNetwork
    checkVMzone
    checkDiskUnattached
    checkNICunattached
    checkIPdynamic
    checkIPunattached
    checkSnapshot
    checkRGLock
    checkAzureCert
    checkElasticPool
    checkAppServicesCert
    check-StorageAccount
    checkPrivateEndpoint
    Get-EmptyResourceGroup
    Get-EmptyAppServicePlan
    Get-StoppedWebApp
    Get-PrivateEndpointError
}
