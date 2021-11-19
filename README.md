# Container Apps Example Scenario

This repository guides you during the process of running a set of containers in Azure Container Apps. In this example scenario, the Fabrikam Drone Delivery app that were previously running in Azure Kubernetes Services consisting of several general purposes microservices is now being provisioned to a recently created Azure Container App environment.  This Azure managed service that is optimized for running applications that span many microservices will make containers internet-facing via an HTTPS ingress, and internally accessible thanks to its built-in DNS-based service discovery capobility. Addtionally, it will manage their secrets in a secure manner.

```output
                                                                                    ┌───────────────────┐
                                                                                    │                   │
                                                          ┌────────────────────────►│      Package      │
                                                          │                         │      service      │
                                                          │                         │                   │
                      ┌─────┐  ┌─────┐  ┌─────┐           │                         └───────────────────┘
                      │x   x│  │x   x│  │x   x│           │
┌───────────────────┐ │  x  │  │  x  │  │  x  │ ┌─────────┴─────────┐               ┌───────────────────┐
│                   │ └─────┘  └─────┘  └─────┘ │                   │               │                   │
│     Ingestion     │                           │     Workflow      │               │  Drone Scheduler  │
│      service      ├──────────────────────────►│     service       ├──────────────►│     service       │
│                   │          Message          │                   │               │                   │
└───────────────────┘          queue            └─────────┬─────────┘               └───────────────────┘
                                                          │
                                                          │                         ┌───────────────────┐
                                                          │                         │                   │
                                                          │                         │     Delivery      │
                                                          └────────────────────────►│     service       │
                                                                                    │                   │
                                                                                    └───────────────────┘
```

## Prerequisites

1. An Azure subscription. You can [open an account for free](https://azure.microsoft.com/free).
1. [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or you can perform this from Azure Cloud Shell by clicking below.

   ```bash
   az login
   ```

1. Ensure you have latest version

   ```bash
	 az upgrade
   ```

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

## Expected results

Following the steps below will result in the creation of the following Azure resources that will be used throughout this Example Scenario.

| Object                                    | Purpose                                                 |
|-------------------------------------------|---------------------------------------------------------|
| Five Azure User Managed Identities        | These are going to give `Read` and `List` secrets permissions over Azure KeyVault to the microservices |
| Five Azure KeyVault instances             | Secrets are saved into Azure KeyValt instances |
| Two Azure Cosmos Db instances             | Delivery and Package services took dependencies on Azure Cosmos Db |
| An Azure Redis Cache instance             | Delivery services uses Azure Redis cache to keep track of inflight deliveries |
| An Azure Service Bus                      | Ingestion and Workflow services are communicated using Azure Service Bus queues |
| An Azure Application Insights instance    | All services are sending trace information to a shared Azure Application Insights instance |

## Clone the repository

1. Clone this repository

   ```bash
   git clone --recurse-submodules https://github.com/mspnp/container-apps-fabrikam-dronedelivery.git
   ```

   :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can [install Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/install#install) to run Bash by entering the following command in PowerShell or Windows Command Prompt and then restarting your machine: `wsl --install`

1. Navigate to the cicdbots folder

   ```bash
   cd ./container-apps-fabrikam-dronedelivery
   ```

## Create the Azure Container Registry and upload the Fabrikam DroneDelivery images

1. Deploy the workload's prerequisites

   ```bash
   az deployment sub create --name workload-stamp-prereqs --location eastus --template-file ./workload/workload-stamp-prereqs.json
   ```

1. Get the workload User Assigned Identities

   ```bash
   DELIVERY_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery -n uid-delivery --query principalId -o tsv) && \
   DRONESCHEDULER_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery -n uid-dronescheduler --query principalId -o tsv) && \
   WORKFLOW_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery -n uid-workflow --query principalId -o tsv) && \
   PACKAGE_ID_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery -n uid-package --query principalId -o tsv) && \
   INGESTION_ID_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery -n uid-ingestion --query principalId -o tsv)
   ```

1. Deploy the workload Azure Container Registry and Azure resources associated to them

   ```bash
   az deployment group create -f workload-stamp.json -g rg-shipping-dronedelivery -p droneSchedulerPrincipalId=$DRONESCHEDULER_PRINCIPAL_ID \
   -p workflowPrincipalId=$WORKFLOW_PRINCIPAL_ID \
   -p deliveryPrincipalId=$DELIVERY_PRINCIPAL_ID \
   -p ingestionPrincipalId=$INGESTION_ID_PRINCIPAL_ID \
   -p packagePrincipalId=$PACKAGE_ID_PRINCIPAL_ID
   ```

1. Obtain the ACR server details

   ```bash
   ACR_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.acrName.value -o tsv)
   ACR_SERVER=$(az acr show -n $ACR_NAME --query loginServer -o tsv)
   ```

1. Build the microservice images

   ```bash
   az acr build -r $ACR_NAME -t $ACR_SERVER/delivery:0.1.0 ./workload/src/shipping/delivery/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/ingestion:0.1.0 ./workload/src/shipping/ingestion/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/workflow:0.1.0 ./workload/src/shipping/workflow/.
   az acr build -r $ACR_NAME -f ./workload/src/shipping/dronescheduler/Dockerfile -t $ACR_SERVER/dronescheduler:0.1.0 ./workload/src/shipping/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/package:0.1.0 ./workload/src/shipping/package/.
   ```

## Clean up

1. Delete the Azure Container Registry resource group

   ```bash
   az group delete -n rg-shipping-dronedelivery-acr -y
   ```

1. Delete the Azure Container Apps resource group

   ```bash
   az group delete -n rg-shipping-dronedelivery -y
   ```

