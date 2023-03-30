#Import-Module Az.Resources

# recupere la liste des VM
$listvm = Get-AzVM -InformationVariable *

# recupere la liste des modeles
$listsize = Get-AzVMSize -Location 'West Europe'

$vms = @()
foreach ( $vm in $listvm )
{ 
    $vma = "" | select name, cpu, memory, size, licence, disk, date
    $vma.size = $vm.HardwareProfile.VmSize
    $size = $vm.HardwareProfile
    $vmsize = $listsize | ?{ $_.Name -eq $size.VmSize }
    $vma.cpu = [int]$vmsize.NumberOfCores
    $vma.memory = [int]$vmsize.MemoryInMB/1024
    $vma.disk = $vm.StorageProfile.DataDisks.Count
    $vma.date = $vm.TimeCreated.ToString('dd-MM-yyyy')
    $vma.name = $vm.Name
    $vma.licence = $vm.LicenseType
    $vms += $vma
}
$vms | Format-Table
