#MPE - 28 / 08 /2022
# https://stackoverflow.com/questions/67828512/building-a-list-of-ip-addresses

Function Get-SubnetAddresses($strNetwork)
 {

    [IPAddress]$IP = ($strNetwork.split("/"))[0]
    [int]$maskbits = ($strNetwork.split("/"))[1]

  # Convert the mask to type [IPAddress]:
  $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
  $maskbytes = [BitConverter]::GetBytes([UInt32] $mask)
  $DottedMask = [IPAddress]((3..0 | ForEach-Object { [String] $maskbytes[$_] }) -join '.')
  
  # bitwise AND them together, and you've got the subnet ID
  $lower = [IPAddress] ( $ip.Address -band $DottedMask.Address )

  # We can do a similar operation for the broadcast address
  # subnet mask bytes need to be inverted and reversed before adding
  $LowerBytes = [BitConverter]::GetBytes([UInt32] $lower.Address)
  [IPAddress]$upper = (0..3 | %{$LowerBytes[$_] + ($maskbytes[(3-$_)] -bxor 255)}) -join '.'

  # Make an object for use elsewhere
  Return [pscustomobject][ordered]@{
    Lower=$lower
    Upper=$upper
  }
}


Function Get-IPRange {
param (
  [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName)][IPAddress]$lower,
  [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName)][IPAddress]$upper
)
  # use lists for speed
  $IPList = [Collections.ArrayList]::new()
  $null = $IPList.Add($lower)
  $i = $lower

  # increment ip until reaching $upper in range
  while ( $i -ne $upper ) { 
    # IP octet values are built back-to-front, so reverse the octet order
    $iBytes = [BitConverter]::GetBytes([UInt32] $i.Address)
    [Array]::Reverse($iBytes)

    # Then we can +1 the int value and reverse again
    $nextBytes = [BitConverter]::GetBytes([UInt32]([bitconverter]::ToUInt32($iBytes,0) +1))
    [Array]::Reverse($nextBytes)

    # Convert to IP and add to list
    $i = [IPAddress]$nextBytes
    $null = $IPList.Add($i.IPAddressToString)
  }

  return $IPList
}


function Count-FreeIP($list_ip)
{
    $total = 0
    $libre = 0
    foreach( $ip in $list_ip)
    {
        $total++
        $free = $(Test-AzPrivateIPAddressAvailability -VirtualNetwork $vnet  -IPAddress $ip).Available
        if ($free )
        {
            $libre++
        }
    }
    ($libre/$total).ToString("P")
}


function Count-FreeIPsubnet($subnet)
{
    #$subnet.Name
    $prefix = $subnet.AddressPrefix
    $range = Get-SubnetAddresses $prefix
    $list_ip = Get-IPRange -lower $range.Lower -upper $range.Upper
    Count-FreeIP -list_ip $list_ip
}

function Count-FreeIPSubnetName($subnetName, $vnetName, $rgname )
{
    $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgname 
    $subnets = $vnet.Subnets
    foreach ( $subnet in $subnets )
    {
        if ( $subnet.Name -eq $subnetName )
        {
            Count-FreeIPsubnet -subnet $subnet
        }
    }
}



$vnets = Get-AzVirtualNetwork

echo "Free IP percent : "
$stats = @()
foreach ( $vnet in $vnets )
{
    foreach ( $subnet in $vnet.Subnets)
    {   
        $subnet_stat = "" | select vnet,name,percent
        $percent = Count-FreeIPSubnetName -subnetName $subnet.Name -vnetName $vnet.Name -rgname $vnet.ResourceGroupName
        $subnet_stat.vnet = $vnet.Name
        $subnet_stat.name = $subnet.Name
        $subnet_stat.percent = $percent
        $stats += $subnet_stat
    }
}
$stats
