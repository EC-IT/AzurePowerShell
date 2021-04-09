# MPE - 06 fev 2020
# Monitor CPU RAM AppServicePlan


#
# Trust Self Signed Cert
# 
function IgnoreCert()
{

# Ignore certificat for PS v5
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12


}


#
# Recupere les URL, User, Pass pour KUDU
# 
function Get-AppPlanPublishingProfileCredential()
{
    param($name)

    $plan = Get-AzAppServicePlan -Name $name
    $appservice_list = Get-AzWebApp -AppServicePlan $plan


    # Cree tableau des resultats
    $PublishingProfile_list = @()

    # Pour chaque appservice....
    foreach ( $app in $appservice_list )
    {
        # ...recupere le nom, l'url et les ID
        [xml]$pp = Get-AzWebAppPublishingProfile -ResourceGroupName $app.ResourceGroup -Name $app.Name
        $appli = "" | Select user,pass,url,nom,base64AuthInfo
        $appli.user = $pp.publishData.publishProfile[0].userName
        $appli.pass = $pp.publishData.publishProfile[0].userPWD
        $appli.url = $pp.publishData.publishProfile[0].publishUrl
        $appli.base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $appli.user, $appli.pass))) 
        $appli.nom = $app.Name

        # ajoute les info de l'appservice au tableau resultat
        $PublishingProfile_list += $appli

    }
    $PublishingProfile_list


}





#
# Recupere les URL, User, Pass pour KUDU
# 
function Get-PublishingProfileCredential()
{
    param($name)
    $appservice = Get-AzWebApp -Name $name

     [xml]$PublishingProfile = Get-AzWebAppPublishingProfile -ResourceGroupName $appservice.ResourceGroup -Name $appservice.Name
    $PublishingProfileCredential = "" | Select user,pass,url,nom,base64AuthInfo
    $PublishingProfileCredential.user = $PublishingProfile.publishData.publishProfile[0].userName
    $PublishingProfileCredential.pass = $PublishingProfile.publishData.publishProfile[0].userPWD
    $PublishingProfileCredential.url = $PublishingProfile.publishData.publishProfile[0].publishUrl
    $PublishingProfileCredential.base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $PublishingProfileCredential.user, $PublishingProfileCredential.pass))) 
    $PublishingProfileCredential.nom = $name
    $PublishingProfileCredential
}



#
# Recupere la liste des process 
# 
function Get-AppServiceProcess_list()
{
    param($PublishingProfileCredential)

  # recupere la liste des process
    $url = $PublishingProfileCredential.url    
    $apiUrl = "https://${url}/api/processes"
    $process_list = Invoke-RestMethod  -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $PublishingProfileCredential.base64AuthInfo)} -UserAgent $userAgent -Method GET -ErrorAction SilentlyContinue
    $process_list 
}



#
# Recupere les infos du process IIS 
# 
function Get-AppPlanProcessIIS()
{
    param($PublishingProfile_list)
    

    $process_w3wp_list = @( @(), @() )
    # Pour chaque app 
    foreach ( $PublishingPro in $PublishingProfile_list )
    {
    # recupere la liste des process IIS parmis les process
    
        $process_list = Get-AppServiceProcess_list -PublishingProfileCredential $PublishingPro

        
        $process_iis = @()
        foreach ( $process in $process_list)
        {
            if ( $process.name -like '*w3wp*' )
            {
                 $process_iis += $process
            }
        }
        #$process_iis
    
        $process_w3wp = @()
        # pour chaque process IIS
        foreach ( $iis in $process_iis )
        {
            # recupere les infos
            $process_info = Invoke-RestMethod  -Uri $iis.href -Headers @{Authorization=("Basic {0}" -f $PublishingPro.base64AuthInfo)} -UserAgent $userAgent -Method GET  -ErrorAction SilentlyContinue

            # Si ce n'est pas le process Kudu : recupe la conso CPU et RAM
            if ( $process_info.is_scm_site -notlike "*True*" )
            {
                #$process_w3wp = @($process_info), @($PublishingPro)
                $process_w3wp = $process_info
            }
        }
        #$process_w3wp_list += @($process_w3wp)
        $process_w3wp_list[0] += $process_w3wp
        $process_w3wp_list[1] += $PublishingPro
    }
    $process_w3wp_list
}


#
# Recupere les infos du process IIS 
# 
function Get-AppServiceProcessIIS()
{
    param($process_list, $PublishingProfileCredential)
    

    # recupere la liste des process IIS parmis les process
    $process_iis = @()
    foreach ( $process in $process_list)
    {
        if ( $process.name -like '*w3wp*' )
        {
             $process_iis += $process
        }
    }
    #$process_iis
    
    $process_w3wp = @()
    # pour chaque process IIS
    foreach ( $iis in $process_iis )
    {
        # recupere les infos
        $process_info = Invoke-RestMethod  -Uri $iis.href -Headers @{Authorization=("Basic {0}" -f $PublishingProfileCredential.base64AuthInfo)} -UserAgent $userAgent -Method GET  -ErrorAction SilentlyContinue

        # Si ce n'est pas le process Kudu : recupe la conso CPU et RAM
        if ( $process_info.is_scm_site -notlike "*True*" )
        {
            $process_w3wp = $process_info
        }
    }
    $process_w3wp

}

#
# Recupere le utilisation CPU et RAM du process
# 
function Get-AppPlanUsage()
{
    param($process_w3wp_list, $seconds=2)


    foreach ( $process_w3wp in $process_w3wp_list[0])
    {
        $i =  $process_w3wp_list[0].IndexOf($process_w3wp)
        $PPcred = $process_w3wp_list[1][$i];

     $app = "" | Select nom,cpu,ram
     
        $process_w3wp = Invoke-RestMethod  -Uri $process_w3wp.href -Headers @{Authorization=("Basic {0}" -f $PPcred.base64AuthInfo)} -UserAgent $userAgent -Method GET  -ErrorAction SilentlyContinue
        $cpu_time1 =  [TimeSpan]::Parse($process_w3wp.total_cpu_time).TotalSeconds
        Start-Sleep -Seconds $seconds
        $process_w3wp = Invoke-RestMethod  -Uri $process_w3wp.href -Headers @{Authorization=("Basic {0}" -f $PPcred.base64AuthInfo)} -UserAgent $userAgent -Method GET  -ErrorAction SilentlyContinue
        $cpu_time2 =  [TimeSpan]::Parse($process_w3wp.total_cpu_time).TotalSeconds
        $cpu_time = $cpu_time2 - $cpu_time1
        #$cpu_time1
        #$cpu_time2 
        $pct = ( 100 / $seconds * $cpu_time )

        $ram = ($process_w3wp.private_memory / 1048576)
        $app.nom = $process_w3wp.environment_variables.WEBSITE_SITE_NAME
        $app.cpu = $pct 
        $app.ram = [math]::Round($ram)
        $app

         #Start-Sleep -Seconds 8
    }
}


#
# Recupere le utilisation CPU et RAM du process
# 
function Get-AppServiceUsage()
{
    param($process_w3wp, $PublishingProfileCredential, $seconds=2)

     $app = "" | Select nom,cpu,ram

    $cpu_time1 =  [TimeSpan]::Parse($process_w3wp.total_cpu_time).TotalSeconds
    Start-Sleep -Seconds $seconds
    $process_w3wp = Invoke-RestMethod  -Uri $process_w3wp.href -Headers @{Authorization=("Basic {0}" -f $PublishingProfileCredential.base64AuthInfo)} -UserAgent $userAgent -Method GET  -ErrorAction SilentlyContinue
    $cpu_time2 =  [TimeSpan]::Parse($process_w3wp.total_cpu_time).TotalSeconds
    $cpu_time = $cpu_time2 - $cpu_time1
    $pct = ( 100 / $seconds * $cpu_time )

    $ram = ($process_w3wp.private_memory / 1048576)
    $app.nom = $process_w3wp.environment_variables.WEBSITE_SITE_NAME
    $app.cpu = $pct 
    $app.ram = [math]::Round($ram)
    $app
}


#
# Recupere CPU et RAM d'un AppService
# 
function Get-AppServicePerf()
{
    param($name, $seconds=2)
    IgnoreCert
    $userAgent = "powershell/1.0"
    $PublishingProfileCredential = Get-PublishingProfileCredential -name $name
    $Process_list = Get-AppServiceProcess_list -PublishingProfile $PublishingProfileCredential
    $process_w3wp = Get-AppServiceProcessIIS -process_list $Process_list -PublishingProfileCredential $PublishingProfileCredential
    $app = Get-AppServiceUsage -process_w3wp $process_w3wp -PublishingProfileCredential $PublishingProfileCredential -seconds $seconds
    $app
}




#
# Recupere CPU et RAM d'un AppServicePlan
# 
function Get-AppPlanPerf()
{
    param($name)
    $userAgent = "powershell/1.0"
    IgnoreCert

    $PublishingProfile_listcred = Get-AppPlanPublishingProfileCredential -name $name
    $process_w3wp_list = Get-AppPlanProcessIIS -PublishingProfile_list $PublishingProfile_listcred 

    $PlanUsage = Get-AppPlanUsage -process_w3wp_list $process_w3wp_list
    $PlanUsage
}



Get-AppPlanPerf -name "AppPlanName"