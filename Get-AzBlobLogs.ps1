# MPE - MARS2021
# source : https://www.c-sharpcorner.com/article/how-to-download-azure-blob-storage-using-azure-powershell/


function Get-BlobLogsToday()
{
    param($connection_string, $destination_path)

    $storage_account = New-AzStorageContext -ConnectionString $connection_string

    $container_name = '$logs'  
    $date = Get-Date -Format "yyyy/MM/dd"
    $blobs = Get-AzStorageBlob -Container $container_name -Context $storage_account -Prefix "blob/$date"
 
    #New-Item -ItemType Directory -Force -Path $destination_path  

    #Download all logs of the day
    foreach ($blob in $blobs)  
    {  
       New-Item -ItemType Directory -Force -Path $destination_path 
       Get-AzStorageBlobContent -Container $container_name -Blob $blob.Name -Destination $destination_path -Context $storage_account
    }
}  

function Get-LogsIP()
{
    param($destination_path)
    $date = Get-Date -Format "yyyy/MM/dd"

    # get all logs of the day
    $log = Get-ChildItem "$destination_path/blob/$date" -recurse -file | foreach{Get-Content $_.FullName}

    # get all ip
    $ip =  ($log |  Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value | Sort-Object | Get-Unique
    $ip
}

function Get-ConnectionString()
{
    param($saName, $rgName)
    $saKey = (Get-AzStorageAccountKey -ResourceGroupName $rgName -Name $saName)[0].Value
    $connection_string= 'DefaultEndpointsProtocol=https;AccountName=' + $saName + ';AccountKey=' + $saKey + ';EndpointSuffix=core.windows.net'
    $connection_string
}

$saName="ectestsa"
$rgName="EC-TEST-rg"

$connection_string= Get-ConnectionString -saName $saName -rgName $rgName
$destination_path = "$env:temp\AppLogs\$saName.$(Get-Random)"

Get-BlobLogsToday -connection_string $connection_string -destination_path $destination_path
Get-LogsIP -destination_path $destination_path
