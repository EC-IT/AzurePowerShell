param (
    [Parameter(Mandatory=$true)][string]$nom,
    [Parameter(Mandatory=$true)][string]$valeur
)

# Source : https://docs.microsoft.com/fr-fr/azure/azure-monitor/platform/data-collector-api#powershell-sample

# Replace with your Workspace ID
$WorkspaceName = "LogAnalyticsWorkspace"
$WorkspaceResourceGroup = "RG"

# Replace with your Workspace ID
$InsightsWorkspace = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName -ResourceGroupName $WorkspaceResourceGroup
$CustomerId = $InsightsWorkspace.CustomerId.Guid

# Replace with your Primary Key
$InsightsWorkspaceSharedKeys = Get-AzOperationalInsightsWorkspaceSharedKeys -Name $WorkspaceName -ResourceGroupName $WorkspaceResourceGroup
$SharedKey = $InsightsWorkspaceSharedKeys.PrimarySharedKey

# Specify the name of the record type that you'll be creating
$LogType = "TEST2"

$Date =  (Get-Date).ToUniversalTime().ToString('o')

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = ""



# Create two records with the same set of properties to create
$json = @"
[{  "StringValue": "$Nom",
    "NumberValue": $valeur,
    "DateValue": "$Date"
}]
"@

# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

# Submit the data to the API endpoint
Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType