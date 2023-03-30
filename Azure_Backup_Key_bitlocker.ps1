

$dossier = "C:\Temp\key"
$vault = "KeyVaultName"


$secrets = Get-AzKeyVaultSecret -VaultName $vault | where { ($_.ContentType -match 'BEK')} 
foreach( $sec in $secrets )
{
    $vm = $sec.Tags.MachineName

    $name = $sec.Name
    $keyVaultSecret = Get-AzKeyVaultSecret -VaultName $vault -Name $name
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyVaultSecret.SecretValue)
    $bekSecretBase64 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    $bekFileBytes = [Convert]::FromBase64String($bekSecretbase64)
    $path =  $dossier +"\" + $vm + "_" + $name + ".bek"
    [System.IO.File]::WriteAllBytes($path,$bekFileBytes)
}