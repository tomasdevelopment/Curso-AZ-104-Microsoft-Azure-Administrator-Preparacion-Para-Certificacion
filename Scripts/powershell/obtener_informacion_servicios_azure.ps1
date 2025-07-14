#Obten una lista de informacion sobre tus web apps / get azure web apps
Get-AzWebApp
#Obten campos especificos Name y Location de tus Web App / Obtain only Name and Locatino from the Web Apps info
Get-AzWebApp | Select-Object Name, Location
#Obten una lista de tus maquinas virtuales / Get a list of the virtual machines
Get-AzVm
#Obten una lista de tus suscripciones
Get-AzSubscription
#Usan el id de la  suscripcion como contexto para todos tus Comando / Use suscription Id as context for your command
Set-AzContext -Subscription "<addyoursubscritionidhere>"

<#Consulta mas comandos para powershell en azure aca
https://learn.microsoft.com/en-us/powershell/azure/?view=azps-14.2.0&viewFallbackFrom=azps-3.3.0
#>
