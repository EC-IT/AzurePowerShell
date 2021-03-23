# MPE - 2019 2020 2021
# Run : AzQualityInstall   and    AzQualityCheck
Import-Module Az.Accounts, Az.RecoveryServices, Az.Compute, Az.Websites, Az.Resources, Az.Automation, Az.OperationalInsights, Az.Network, Az.Sql


function AzQualityInstall()
{
    Install-Module Az.Accounts, Az.RecoveryServices, Az.Compute, Az.Websites, Az.Resources, Az.Automation, Az.OperationalInsights, Az.Network, Az.Sql
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
    
    Write-Title "VM sans sauvegardes : "

    # recupere la liste des VM sauvegardee
    Get-All-Backup-Details

    # recupere la liste des VM
    $listvm = Get-AzVM

    # pour chaque VM...
    foreach ( $vm in $listvm.Name )
    {
        # ...si elle n'est pas sauvegardee : affiche le nom
        if ( ! $global:vmbkp.vm.Contains($vm) )
        {
            Write-Host $vm -BackgroundColor Red
        }
    }

}


function AppServiceNoBackup
{
    Param($ResourceGroupName, $Name)

    $backup = Get-AzWebAppBackupList  -ResourceGroupName $ResourceGroupName -Name $Name
    
    if ( $backup.Count -eq 0 )
    {    
        Write-Host $app.Name  -BackgroundColor Red
    }
}

#
##### BACKUP APP SVC #####
#
function checkAppServiceBackup
{    
    Write-Title "App Service sans sauvegardes : "

    $asp= Get-AzAppServicePlan # -ResourceGroupName $ResourceGroupName
    foreach( $AppPlan in $asp )
    {
        $apps=Get-AzWebApp -AppServicePlan $AppPlan

        Foreach($app in $apps) 
        { 
            AppServiceNoBackup  -ResourceGroupName $app.ResourceGroup -Name $app.Name    
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

    # pour chaque VM...
    foreach ( $vm in $listvm )
    {
        # ... recupere le verrou
        $lockvm = Get-AzResourceLock -ResourceName $vm.Name -ResourceGroupName $vm.ResourceGroupName -ResourceType "Microsoft.Compute/virtualMachines"
    
        # si le verrou n'existe pas : afficher le nom de la VM
        if ( ! $lockvm  )
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
        # si la VM n'est pas presente dans les logs : afficher son nom
        if ( ! $($VMconnect -match $vm.Name)  )
        {
            Write-Host $vm.Name -BackgroundColor Red
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
    
        if( ($md.VirtualMachine -eq $null) -and ($md.IpConfigurations.Name -inotmatch "privateEndpoint" ) ) {
                    
                Write-Host  $($md.Name) -BackgroundColor Red
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
    Write-Title "VM sans l'agent Monitoring : "

    foreach ($vm in $listvm) {
        if ( $($vm.Extensions.id -match "MicrosoftMonitoringAgent").Count -eq 0 )
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
    Write-Title "VM sans l'agent de chiffrement : "
    foreach ($vm in $listvm) {
        if ( $($vm.Extensions.id -match "AzureDiskEncryption").Count -eq 0 )
        {
            Write-Host $vm.Name -BackgroundColor Red
        }
    }
}

 #
##### VM SANS ZONE #####
#
function checkVMzone()
{    
    Write-Title "VM sans Zone :"

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
    
    Write-Title "Listes des snapshots :"
    $sslist = Get-AzSnapshot

    $sslist.Name
}
#
##### LISTE DES CERTIFICAT AUOTMATION QUI EXPIRE #####
#

function checkAzureCert()
{
    Write-Title "Certificat Azure qui expire :"

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
    Write-Title "Azure SQL Database hors SQL elastic pool :"

    $SqlServerList = Get-AzSqlServer

    foreach ( $SqlServer in $SqlServerList)
    {
        # liste les base
        $dbppd = Get-AzSqlDatabase -ServerName $SqlServer.ServerName -ResourceGroupName $SqlServer.ResourceGroupName

        # pour chaque bases
        foreach ( $db in $dbppd )
        {
            # si aucun pool : afficher le nom
              if ( ! $db.ElasticPoolName )
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
    Write-Title "Certificat AppService qui expire :"

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
    $list_sa = Get-AzStorageAccount

    # Pour chaque SA recupe Firewall HTTPS TLS
    $liste_sa_param = @()
    foreach ($sa in $list_sa)
    {
        $sa_param = "" | select StorageAccountName,FWDefaultAction,FWIpRules,EnableHttpsTrafficOnly,MinimumTlsVersion
        $sa_param.StorageAccountName = $sa.StorageAccountName
        $sa_param.FWDefaultAction = $sa.NetworkRuleSet.DefaultAction
        $sa_param.FWIpRules = $sa.NetworkRuleSet.IpRules.Count
        $sa_param.EnableHttpsTrafficOnly = $sa.EnableHttpsTrafficOnly
        $sa_param.MinimumTlsVersion = $sa.MinimumTlsVersion
    
        $liste_sa_param+=$sa_param
    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "Compte de stockage sans parfeu :"
    foreach($sa in $liste_sa_param)
    {

        if ( $sa.FWDefaultAction -eq "Allow" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "Compte de stockage sans HTTPS :"
    foreach($sa in $liste_sa_param)
    {

        if ( $sa.EnableHttpsTrafficOnly -ne "True" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }

    Write-Host -ForegroundColor White  -BackgroundColor DarkBlue "Compte de stockage sans TLS 1.2 :"
    foreach($sa in $liste_sa_param)
    {

        if ( $sa.MinimumTlsVersion -ne "TLS1_2" )
        {        
                Write-Host $sa.StorageAccountName -BackgroundColor Red
        }
    }
}

function AzQualityCheck()
{          
    if ( ! $(Get-AzSubscription)[0].Id ) { echo "Not connected, run :"; echo "Connect-AzAccount -UseDeviceAuthentication"; return 1; } 
    
    $global:listvm = Get-AzVM

    if ( $global:listvm.Count -lt 1 ) { return 1; }

    checkAppServiceBackup
    checkBackupVM
    checkVMuncrypted
    checkVMcrypted
    checkVMLock
    checkVMupdate
    checkVMloganalytics
    checkVMmontiored
    checkVMzone
    checkDiskUnattached
    checkNICunattached
    checkIPdynamic
    checkIPunattached
    checkSnapshot
    checkAzureCert
    checkElasticPool
    checkAppServicesCert
    check-StorageAccount

}
