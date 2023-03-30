

function snapshot-to-blob()
{
    param($snapshotName, $storageAccountName, $storageContainerName, $StorageAccountresourceGroupName)

    $snapshot = Get-AzSnapshot -SnapshotName $snapshotName
    
    $storageAccountKey = Get-AzStorageAccountKey -resourceGroupName $StorageAccountresourceGroupName -AccountName $storageAccountName    
    $sas = Grant-AzSnapshotAccess -ResourceGroupName $snapshot.ResourceGroupName -SnapshotName $snapshotName -DurationInSecond 36000 -Access Read
    $destinationContext = New-AzStorageContext –storageAccountName $storageAccountName -StorageAccountKey ($storageAccountKey).Value[0]

    Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $snapshotName
}


$StorageAccountresourceGroupName = "RG-SA"
$storageAccountName = "SA"
$storageContainerName = "container"

$snapshotName="TEMP_DATA"
snapshot-to-blob -storageAccountName $storageAccountName -storageContainerName $storageContainerName -StorageAccountresourceGroupName $StorageAccountresourceGroupName -snapshotName $snapshotName
