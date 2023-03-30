# MPE - dec 2021
# list size

$vms = Get-AzVM

$vms_size = @()
foreach ( $vm in $vms)
{
    $vm_size = "" | select name, vmsize
    $vm_size.name = $vm.Name
    $vm_size.vmsize = $vm.HardwareProfile.VmSize
    $vms_size += $vm_size
}

$vms_size