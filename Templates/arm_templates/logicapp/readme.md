# End-to-End Private Azure Logic Apps Deployment

## Overview
This project delivers a **secure and production-ready deployment model for Azure Logic Apps** using private networking. The architecture ensures that all traffic between the Logic Apps, connected resources, and monitoring tools flows through **Azure Private Endpoints and VNet-injected services**, eliminating public exposure.

## Key Goals
- Enable private-only integration of Logic Apps with Azure services.  
- Automate infrastructure deployment with Bicep/ARM templates.  
- Provide observability with Azure Monitor and Log Analytics via Private Link Scope.  
- Support enterprise-grade DNS resolution using custom Private DNS Zones.  
- Route traffic through Azure Application Gateway for controlled ingress.

## Architecture Highlights
- **Logic Apps Standard (ISE/consumption hybrid)** running inside a secured VNet.  
- **Private Endpoints** for Storage, Key Vault, and other dependencies.  
- **Private DNS Zones** with conditional forwarding rules for name resolution.  
- **Azure Application Gateway** for controlled routing and TLS termination.  
- **Azure Monitor + Private Link Scope** for secure metrics and diagnostics ingestion.  

## Impact
This reference implementation accelerates **enterprise adoption of private Logic Apps** by providing a repeatable, secure deployment pattern. It reduces time-to-deploy, enforces compliance, and minimizes operational risk by ensuring workloads never traverse the public internet.

## Skills & Tools
- Azure Logic Apps Standard  
- Azure Private Endpoints & DNS  
- Application Gateway & VNet Integration  
- Bicep/ARM Infrastructure as Code  
- Azure Monitor / Log Analytics  


**Setting	Why it matters
**

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

**Architecture
**
![logicapps](https://github.com/user-attachments/assets/a2d3690a-9656-469a-aa95-23e18cdc62b4)
