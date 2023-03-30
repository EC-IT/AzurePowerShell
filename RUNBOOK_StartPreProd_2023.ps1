
# Connect with manage identity automation-infra-umi
Connect-AzAccount -Identity -AccountId "XXXXXXXXXXX"
Select-AzSubscription -Subscription "XXXXXXXXXXX"

if ( Get-AzSubscription )
{
    # Get all VMs 
	[array]$VMs = Get-AzVm -Status | `
	Where-Object {$PSItem.Tags.Keys -eq "EC_ENVIRONMENT" -and $PSItem.Tags.Values -eq "PRE-PROD" -and $PSItem.Tags['EC_AUTOMATION'] -ne "NOSTOP" -and $PSItem.PowerState -eq "VM deallocated"
	} | `
	Sort-Object {$PSItem.Tags["START-ORDER"]}

    # List VM with start Order
    $VMs_Order = $VMs | Where-Object  { $PSItem.Tags.Keys.Contains("START-ORDER") }
    # List VM without Start order
    $VMs_NoOrder = $VMs | Where-Object  { ! $PSItem.Tags.Keys.Contains("START-ORDER") }

    # Start VM with order
	ForEach ($VM in $VMs_Order)
	{
		Write-Output "Starting: $($VM.Name)"    
		Start-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
	}     

    # Start VM without Order	
	ForEach ($VM in $VMs_NoOrder)
	{
		Write-Output "Starting: $($VM.Name)"
		Start-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName
	}     
}