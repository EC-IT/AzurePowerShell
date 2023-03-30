# MPE - MARS 2022 - COPY CONTAINER
# source : https://stackoverflow.com/questions/69600496/copy-blobs-between-storage-containers-in-different-subscriptions-in-azure-using


function AzureCopyContainer()
{
    param($SrcSubscription, $SrcStorageAccountName, $SrcStorageAccountRG, $SrcStorageContainerName, $TgtSubscription, $TgtStorageAccountName, $TgtStorageAccountRG, $TgtStorageContainerName)
    # Get Source Storage Account Context

    Select-AzSubscription -SubscriptionId $SrcSubscription
    $SrcStorageAccountKey = $(Get-AzStorageAccountKey -ResourceGroupName  $SrcStorageAccountRG -Name $SrcStorageAccountName)[0].Value
    $StorageAccountContext = New-AzStorageContext -StorageAccountName $SrcStorageAccountName -StorageAccountKey $SrcStorageAccountKey 


    # Get Target Storage Account Context

    Select-AzSubscription -SubscriptionId $TgtSubscription 
    $TgtStorageAccountKey = $(Get-AzStorageAccountKey -ResourceGroupName  $TgtStorageAccountRG -Name $TgtStorageAccountName)[0].Value
    $TgtStorageAccountContext = New-AzStorageContext -StorageAccountName $TgtStorageAccountName -StorageAccountKey $TgtStorageAccountKey

    # Create container

    if(! $(Get-AzStorageContainer -Name $TgtStorageContainerName -Context $TgtStorageAccountContext -ErrorAction SilentlyContinue) ) 
    {
        New-AzStorageContainer -Name $TgtStorageContainerName -Context $TgtStorageAccountContext -Permission Container  
    }      

    Get-AzStorageBlob -Container $SrcStorageContainerName -Context $StorageAccountContext  |  Start-AzStorageBlobCopy -DestContainer $TgtStorageContainerName -DestContext $TgtStorageAccountContext -Force
}


$SrcSubscription = "XXXXX"
$SrcStorageAccountName = "SA-source"
$SrcStorageAccountRG = "SA-rg" 
$SrcStorageContainerName = "categorie-1"

    
$TgtSubscription = "ZZZZZ"
$TgtStorageAccountName = "SA-dest"
$TgtStorageAccountRG = "SA-rg"
$TgtStorageContainerName = "testimport"

#$TLS12Protocol = [System.Net.SecurityProtocolType] 'Ssl3 , Tls12'
#[System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol
AzureCopyContainer -SrcSubscription $SrcSubscription -SrcStorageAccountName $SrcStorageAccountName -SrcStorageAccountRG $SrcStorageAccountRG -SrcStorageContainerName $SrcStorageContainerName -TgtSubscription $TgtSubscription -TgtStorageAccountName $TgtStorageAccountName -TgtStorageAccountRG $TgtStorageAccountRG  -TgtStorageContainerName $TgtStorageContainerName
