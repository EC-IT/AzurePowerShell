# MPE - 20 nov 2020
# list Azure IP adress

$nic = Get-AzNetworkInterface

$list_ip = @()
foreach( $interface in $nic )
{
    $ip = "" | Select VirtualMachine,Subnet,PrivateIpAddress,Name
    $ip.VirtualMachine = $interface.VirtualMachine.Id.Split("/")[-1]
    $ip.Subnet = $interface.IpConfigurations.Subnet.Id.Split("/")[-1]
    $ip.PrivateIpAddress = $interface.IpConfigurations.PrivateIpAddress
    $ip.name = $interface.Name

    $list_ip += $ip    
}

$list_ip