# MPE - JUIN 2021
# GET AZURE VM PRICE

function get-vmprice()
{
    param($name, $region="westeurope", $currency="EUR" )

    $query = "currencyCode='" + "$currency" + "'&`$filter=serviceName eq 'Virtual Machines' and armRegionName eq '" + "$region" + "' and priceType eq 'Consumption' and serviceFamily eq 'Compute' and endswith(productName, 'Windows')  and armSkuName eq '" + "$name" + "'"
    $query = $query.Replace(' ','%20')
    $query = $query.Replace("'",'%27')

    $uri = "https://prices.azure.com/api/retail/prices?$query"
    $webReq = Invoke-WebRequest -Uri  "$uri" | ConvertFrom-Json
    $items = $webReq.Items

    foreach ( $item in $items)
    {
        if ( ! ($item.skuName -match "Low" -or $item.skuName -match "Spot") )
        {
            [math]::Round([float]$item[0].unitPrice * 730,2)
        }
    }
}

get-vmprice -name "Standard_DS11_v2"
$name="Standard_DS11_v2"