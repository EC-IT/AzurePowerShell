# MPE - 31 01 2020

function Get-AzWebAppCredentials()
{
	# recupere les AppService
	$appservice_list = Get-AzWebApp 

	# Cree tableau des resultats
	$PublishingProfile_list = @()

	# Pour chaque appservice....
	foreach ( $app in $appservice_list )
	{
		# ...recupere le nom, l'url et les ID
		[xml]$pp = Get-AzWebAppPublishingProfile -ResourceGroupName $app.ResourceGroup -Name $app.Name
		$appli = "" | Select user,pass,url,nom
		$appli.user = $pp.publishData.publishProfile[0].userName
		$appli.pass = $pp.publishData.publishProfile[0].userPWD
		$appli.url = $pp.publishData.publishProfile[0].publishUrl
		$appli.nom = $app.Name

		# ajoute les info de l'appservice au tableau resultat
		$PublishingProfile_list += $appli

	}

	# Affiche le résultat
	$PublishingProfile_list
}
