# MPE - Oct 2022
# DELAIS EXECUTION 1VM 4disk : 8 minutes
# https://thomasthornton.cloud/2020/03/27/azure-disk-snapshots/
# https://learn.microsoft.com/en-us/azure/virtual-machines/windows/create-vm-specialized

function Get-DiskNOTEncrypted()
{
    param($vm_name, $vm_rg)
    $encryptedstatus = Get-AzVmDiskEncryptionStatus -ResourceGroupName $vm_rg -VMName $vm_name

    if ( ($encryptedstatus.DataVolumesEncrypted -ne "Encrypted") -and ($encryptedstatus.OsVolumeEncrypted -ne "Encrypted") )
    {
        return $true
    }
    else {
        return $false
    }
}

function Snapshot-vm()
{
    param($vmname, $rgsnapshot)
    $vm = get-azvm -Name $vmname
    $rg = $rgsnapshot
    $location="westeurope"

    $snapshots = @()
    $snapshotConfig =  New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location  -CreateOption copy -SkuName Standard_LRS   
    $snapshotName = ($vm.Name+"_OsDisk")
 
    $snapshots +=  New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $rg

    foreach ( $disk in $vm.StorageProfile.DataDisks )
    {
        $snapshotConfig =  New-AzSnapshotConfig -SourceUri $disk.ManagedDisk.Id -Location $location -CreateOption copy -SkuName Standard_LRS
        $lun = $disk.Lun
        $snapshotName = ($disk.Name+"_LUN"+$lun)
        $snapshots += New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $rg
    }

    return $snapshots
}


function Create-DiskFromSnapshot()
{
    param($disksnapshot, $snapshot_rg, $vm_rg, $zone=1)

    $snapshotinfo = Get-AzSnapshot -ResourceGroupName $snapshot_rg -SnapshotName $disksnapshot

    $diskname = $disksnapshot + "_1"
    New-AzDisk -DiskName $diskname (New-AzDiskConfig  -Location westeurope -CreateOption Copy -SourceResourceId $snapshotinfo.Id -Zone $zone -SkuName Premium_LRS) -ResourceGroupName $vm_rg
}

#####

#####


$vm_name = "VM-NAME" 
$vm_rg = "VM-RG"
$snapshot_rg = "SNAPSHOT-RG"
$location = "westeurope"
$zone = 1

$DiskNOTEncrypted = Get-DiskNOTEncrypted -vm_name $vm_name -vm_rg $vm_rg
$locks = Get-AzResourceLock -ResourceName $vm_name -ResourceGroupName $vm_rg -ResourceType 'Microsoft.Compute/virtualMachines'

# Recuperer les info de la VM
$vm = Get-AzVM -ResourceGroupName $vm_rg -Name $vm_name

$VmSize = $vm.HardwareProfile.VmSize
$LicenseType = $vm.LicenseType
if (! $LicenseType ) { $LicenseType = "None"  }
$OsDiskSize = $vm.StorageProfile.OsDisk.DiskSizeGB
$DataDisks = $vm.StorageProfile.DataDisks
$vm_tags = $vm.Tags
if ( ! $vm_tags ) {  $vm_tags = @{'ENVIRONMENT' = "NPE" } }

$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces.Id
$ip = $nic.IpConfigurations[0].PrivateIpAddress
$subnet_id = $nic.IpConfigurations[0].Subnet.Id
$locks_net = Get-AzResourceLock -ResourceName $nic.Name -ResourceGroupName $nic.ResourceGroupName -ResourceType 'Microsoft.Network/networkInterfaces'
$locks_disk = Get-AzResourceLock -ResourceName $vm.StorageProfile.OsDisk.Name -ResourceGroupName $vm.ResourceGroupName -ResourceType 'Microsoft.Compute/disks'

if ( $DiskNOTEncrypted -and (!$locks) -and ( !$locks_net ) -and ( !$locks_disk ) )
{
try {
    ##### RECREATION DES DISQUES ####

    # Arret de la VM
    Write-Host "Arret de la VM"
    Stop-AzVM -Name $vm_name -ResourceGroupName $vm_rg -Force
    Start-Sleep 10

    # Creer les snapshots des disques
    Write-Host "Creation des snapshots"
    $snapshots = Snapshot-vm -vmname $vm_name -rgsnapshot $snapshot_rg
    Start-Sleep 60

    # Creer les disques à partir des snapshots
    Write-Host "Creation des disques"
    $newdisks = @()
    foreach ( $disksnapshot in $snapshots )
    {
        $snapshot_name = $($disksnapshot.Name)
        $newdisks += Create-DiskFromSnapshot -disksnapshot $snapshot_name -snapshot_rg $snapshot_rg -vm_rg $vm_rg -zone $zone
    }
    Start-Sleep 10

    #### SUPPRIMER LA VM et la carte reseau

    # Detacher les disques de la VM
    Write-Host "Detachement des disques de la VM"
    foreach ( $DataDisk in $DataDisks)
    {
        $VirtualMachine = Get-AzVM -ResourceGroupName $vm_rg -Name $vm_name
        Remove-AzVMDataDisk -VM $VirtualMachine -Name $DataDisk.Name
        Update-AzVM -ResourceGroupName $vm_rg -VM $VirtualMachine
        Start-Sleep 5
    }

    # Supprimer la VM pour reutiliser le nom
    Write-Host "Suppression de la VM"
    Remove-AzVM -ResourceGroupName $vm_rg -Name $vm_name -Force
    Start-Sleep 5

    # Supprimer la carte reseaux pour reutiliser l'ip
    Write-Host "Suppression de la carte reseau"
    Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $nic.ResourceGroupName -Force
    Start-Sleep 10


    #### CREATION DE LA VM #####


    # Creation de la carte réseau
    Write-Host "Creation de la carte reseau"
    $nic_name = $vm_name + "NIC01"
    $nic = New-AzNetworkInterface -Name $nic_name -ResourceGroupName $vm_rg -Location $location -SubnetId $subnet_id -PrivateIpAddress $ip -EnableAcceleratedNetworking 
    Start-Sleep 5

    # Creation de la config VM
    Write-Host "Creation de la config de la VM"
    $vmConfig = New-AzVMConfig -VMName $vm_name -VMSize $VmSize -LicenseType $LicenseType -Tags $vm_tags -Zone $zone

    # Attacher la config reseau
    $vmconfignet = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    # Attahcer le disque system
    $osDisk =$newdisks[0].Name
    $vm = Set-AzVMOSDisk -VM $vmconfignet -ManagedDiskId $newdisks[0].Id -StorageAccountType Premium_LRS -DiskSizeInGB $newdisks[0].DiskSizeGB  -CreateOption Attach -Windows

    # Attacher les disques Data
    foreach ( $ndisk in $newdisks)
    {
        if ($ndisk.Name -match "LUN") { 
            $disk_name = $($ndisk.Name) + "_1"
            $lun = [int]$($ndisk.Name).Substring($ndisk.Name.Length-3,1)
            $vm = Add-AzVMDataDisk -VM $vm -ManagedDiskId $ndisk.Id -StorageAccountType Premium_LRS -DiskSizeInGB $ndisk.DiskSizeGB  -CreateOption Attach -Caching ReadOnly -Lun $lun
        }
    }

    # Creation de la VM
    Write-Host "Creation de la VM"
    New-AzVM -ResourceGroupName $vm_rg -Location $location -VM $vm

} catch {
  Write-Host "An error occurred:"
  Write-Host $_.ScriptStackTrace
}

}
else
{
    $msg = "ERROR. Disk Decrypted : " + $DiskNOTEncrypted + ", VM without lock : " + (!$locks) + ", NIC without lock : " + ( !$locks_net ) + ", OsDisk without Lock : " + ( !$locks_disk )
    echo $msg
}