Setting	Why it matters
FUNCTIONS_EXTENSION_VERSION=~4	Pins Functions host to v4, avoiding unexpected platform upgrades.
FUNCTIONS_WORKER_RUNTIME=dotnet	Required for Logic Apps Standard (unless custom functions in another runtime).
APPINSIGHTS_INSTRUMENTATIONKEY / APPLICATIONINSIGHTS_CONNECTION_STRING	Telemetry. Use the connection string format going forward.
AzureWebJobsStorage=<conn string>	Durable state (blob, queue, table). Needs storage PE + private DNS.
WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=<conn string>	Mounts Azure Files for app content. Needs private file PE.
WEBSITE_CONTENTSHARE=<share name>	Fileshare name (lowercase).
APP_KIND=workflowApp	Identifies the app as a Logic App Standard.
WEBSITE_VNET_ROUTE_ALL=1	Forces all outbound traffic through VNET integration.
WEBSITE_CONTENTOVERVNET=1	Mounts content over VNET (requires private file endpoint + DNS).
AzureFunctionsJobHost__extensionBundle__id	Must be Microsoft.Azure.Functions.ExtensionBundle.Workflows.
AzureFunctionsJobHost__extensionBundle__version	Pin tightly in prod, e.g., "[1.17.*, 1.18.0)". Use [concat('[', '1.*, 2.0.0)')] in ARM.
<img width="1731" height="430" alt="image" src="https://github.com/user-attachments/assets/34a16ae0-c70f-4ba0-b288-01c9fcbff2c8" />
