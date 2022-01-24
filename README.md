# Container Apps Example Scenario

This repository guides you during the process of running a set of containers in Azure Container Apps. In this example scenario, the Fabrikam Drone Delivery app that were previously running in Azure Kubernetes Services consisting of several general purposes microservices is now being provisioned to a recently created Azure Container App environment.  This Azure managed service that is optimized for running applications that span many microservices will make containers internet-facing via an HTTPS ingress, and internally accessible thanks to its built-in DNS-based service discovery capability. Additionally, it will manage their secrets in a secure manner.

```output

                         ┌─────────────┐      ┌─────────────┐       ┌─────────────┐
                         │   Azure     │      │   Azure     │       │   Azure     │
            ┌───────────►│   Service   │      │   Key Vault │       │   Container │
            │            │   Bus       │      │             │       │   Registry  │
            │            └─────┬───────┘      └─────────────┘       └─────────────┘
            │                  │
┌───────────│──────────────────│───────────────Azure Container App Environment────┐
│           │                  │                                                  │
│           │                  │                                                  │
│           │                  │                                ┌─────────────┐   │     ┌─────────────┐
│           │                  │                                │             │   │     │   Azure     │
│           │                  │                 ┌─────────────►│   Package   │────────►│   MongoDb   │
│           │                  │                 │              │   Container │   │     │             │
│           │                  │                 │              │   App       │   │     └─────────────┘
│           │                  │                 │              └─────────────┘   │
│           │                  │                 │                                │
│   ┌───────┴─────┐            │          ┌──────┴──────┐       ┌─────────────┐   │     ┌─────────────┐
│   │             │            │          │             │       │  Drone      │   │     │   Azure     │
│   │  Ingestion  │            │          │  Workflow   │       │  Scheduler  │ ───────►│   CosmosDb  │
│   │  Container  │            └─────────►│  Container  ├──────►│  Container  │   │     │             │
│   │  App        │                       │  App        │       │  App        │   │     └─────────────┘
│   └─────────────┘                       └──────┬──────┘       └─────────────┘   │
│                                                │                                │
│                                                │              ┌─────────────┐   │     ┌─────────────┐
│                                                │              │             │   │     │   Azure     │
│                                                │              │  Delivery   │ ───────►│   Redis     │
│                                                └─────────────►│  Container  │   │     │   Cache     │
│                                                               │  App        │   │     └─────────────┘
│                                                               └─────────────┘   │
│                                                                                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────┐┌────────────────────────────────────────┐
│         Azure                         ││          Azure Monitor                 │
│         Log Analytics Workspace       ││          Application Insights          │
└───────────────────────────────────────┘└────────────────────────────────────────┘

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
| Two Azure Cosmos Db instances             | Delivery and Package services have dependencies on Azure Cosmos Db |
| An Azure Redis Cache instance             | Delivery service uses Azure Redis cache to keep track of inflight deliveries |
| An Azure Service Bus                      | Ingestion and Workflow services communicate using Azure Service Bus queues |
| An Azure Application Insights instance    | All services are sending trace information to a shared Azure Application Insights instance |
| An Azure Container Registry               | This is the private container registry where all Fabrikam workload images are uploaded and later pulled from the different Azure Container Apps |
| An Azure Container App Environment        | It is the managed Container App environment where Container Apps are homed |
| Five Azure Container Apps                 | These are the Azure resources that represents the five Fabrikam microservices in the Azure Container App environment |
| An Azure Log Analytics Workspace          | This is where all the Container Apps logs are sent        |

## Clone the repository

1. Clone this repository

   ```bash
   git clone --recurse-submodules https://github.com/mspnp/container-apps-fabrikam-dronedelivery.git
   ```

   :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can [install Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/install#install) to run Bash by entering the following command in PowerShell or Windows Command Prompt and then restarting your machine: `wsl --install`

1. Navigate to the container-apps-fabrikam-dronedelivery folder

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

1. Get Application Insights Instrumention Key

   ```bash
   AI_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.appInsightsName.value -o tsv)
   AI_KEY=$(az resource show -g rg-shipping-dronedelivery -n $AI_NAME --resource-type "Microsoft.Insights/components" --query properties.InstrumentationKey -o tsv)
   ```

1. Get microservices details

   ```bash
   DELIVERY_COSMOSDB_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.deliveryCosmosDbName.value -o tsv)
   DELIVERY_DATABASE_NAME="${DELIVERY_COSMOSDB_NAME}-db"
   DELIVERY_COLLECTION_NAME="${DELIVERY_COSMOSDB_NAME}-col"
   DELIVERY_COSMOSDB_ENDPOINT=$(az cosmosdb show -g rg-shipping-dronedelivery -n $DELIVERY_COSMOSDB_NAME --query documentEndpoint -o tsv)
   DELIVERY_COSMOSDB_KEY=$(az cosmosdb keys list -g rg-shipping-dronedelivery -n $DELIVERY_COSMOSDB_NAME --query primaryMasterKey -o tsv)
   DELIVERY_REDIS_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.deliveryRedisName.value -o tsv)
   DELIVERY_REDIS_ENDPOINT=$(az redis show -g rg-shipping-dronedelivery  -n $DELIVERY_REDIS_NAME --query hostName -o tsv)
   DELIVERY_REDIS_KEY=$(az redis list-keys -g rg-shipping-dronedelivery  -n $DELIVERY_REDIS_NAME --query primaryKey -o tsv)
   ```

## Deploy Azure Container App

1. Register the Azure Resource Manager provider for `Microsoft.Web`

   ```bash
   az provider register --namespace Microsoft.Web
   ```

1. Deploy the Container Apps ARM template

   ```bash
   az deployment group create -f containerapps-stamp.bicep -g rg-shipping-dronedelivery -p acrSever=$ACR_SERVER \
      applicationInsightsInstrumentationKey=$AI_KEY \
      deliveryCosmosdbDatabaseName=$DELIVERY_DATABASE_NAME \
      deliveryCosmosdbCollectionName=$DELIVERY_COLLECTION_NAME \
      deliveryCosmosdbEndpoint=$DELIVERY_COSMOSDB_ENDPOINT \
      deliveryCosmosdbKey=$DELIVERY_COSMOSDB_KEY \
      deliveryRedisEndpoint=$DELIVERY_REDIS_ENDPOINT \
      deliveryRedisKey=$DELIVERY_REDIS_KEY
   ```

   :eyes: Please note that Azure Container Apps as well as this ARM API specification are currently in _Preview_ with [limited `location` support](https://azure.microsoft.com/global-infrastructure/services/?products=container-apps).

## Clean up

1. Delete the Azure Container Registry resource group

   ```bash
   az group delete -n rg-shipping-dronedelivery-acr -y
   ```

1. Delete the Azure Container Apps resource group

   ```bash
   az group delete -n rg-shipping-dronedelivery -y
   ```
