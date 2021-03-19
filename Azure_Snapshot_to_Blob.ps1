# MPE - MAR2021
# source : https://arlanblogs.alvarnet.com/export-an-azure-managed-snapshot-to-storage-account-powershell/

$resourceGroupName = 'test-rg'
$snapshotName = 'VM001_OsDisk_1_01FEV2021'
$destinationVHDFileName = 'VM001_OsDisk_1_01FEV2021.vhd'

$resourceGroupNameStorageAccount = 'Backup-rg'
$storageAccountName = 'archivesa'
$storageContainerName = 'azure'

#Get the Storage Account Key of the Destination Storage Account
$storageAccountKey = Get-AzStorageAccountKey -resourceGroupName $resourceGroupNameStorageAccount -AccountName $storageAccountName
#Generate the SAS for the snapshot
$sas = Grant-AzSnapshotAccess -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName  -DurationInSecond 7200 -Access Read
#Create the context of the destination storage account for the snapshot
$destinationContext = New-AzStorageContext –storageAccountName $storageAccountName -StorageAccountKey ($storageAccountKey).Value[0]


 #Copy the snapshot to the destination Storage Account
Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName

