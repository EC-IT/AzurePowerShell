
#Import-Module Az.Resources

# recupere la liste des VM
$listvm = Get-AzVM -InformationVariable *

# recupere la liste des modeles
$listsize = Get-AzVMSize -Location 'West Europe'

$totalcpu = 0;
foreach ( $vm in $listvm )
{ 
    $size = $vm.HardwareProfile
    $vmsize = $listsize | ?{ $_.Name -eq $size.VmSize }
    $totalcpu += [int]$vmsize.NumberOfCores
}
$totalcpu


