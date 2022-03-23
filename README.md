# Container Apps (Preview) Example Scenario

## Introduction

Fabrikam inc has created a new operations team, and under its organization there is a brown field app called [Drone Delivery](https://github.com/mspnp/fabrikam-dronedelivery-workload/tree/beb2c60f9450ce04038fb95aa0110ab4143fc76a). This application been running for a while in [AKS (Kubernetes)](https://github.com/mspnp/microservices-reference-implementation), and while they are huge fans of containers to build microservices and K8s, it has been discovered that it is not making use of any of the advance features like custom Service Mesh or Autoscaling among others.

The team has detected an opportunity to be more efficient at the devops level, and this is why they are now looking into a new fully managed Container App service to experiment with Fabrikam Drone Delivery. This will allow them to publish and run containarized microservices at scale, faster than before, reducing the complexity, saving resources by using scale to `0` built-in autoscaling capability, and without losing all the container advantages they love.

Azure Container Apps is a new cloud native serverless managed service that is just using AKS with KEDA behind the scenes to deploy and run containerized applications.

## Migrating a microservices workload from AKS to Azure Container Apps (Preview)

This repository guides you during the process of running an example application composed of microservices in Azure Container Apps (Preview). In this example scenario, the Fabrikam Drone Delivery app that was previously running in Azure Kubernetes Services will be run in a newly created Azure Container App environment. This Azure managed service is optimized for running applications that span many microservices. This example will make some containers internet-facing via an HTTPS ingress, and internally accessible thanks to its built-in DNS-based service discovery capability. Additionally, it will manage their secrets in a secure manner.

![Runtime architecture](microservices-with-container-apps-runtime-diagram.png)

Workflow Service is a message consumer app, so it needs to be deployed in single revision mode, otherwise an old versions could still process a message if happen to be one that retrieves it first.
```

For more information on how the Container Apps feature are being used in this Reference Implementation, please take a look below:

- [HTTPS ingress, this allows to expose the Ingestion service to internet.](https://docs.microsoft.com/en-us/azure/container-apps/ingress)
- [Internal service discovery, Delivery, DroneScheduler and Package services must be internally reachable by Workflow service](https://docs.microsoft.com/en-us/azure/container-apps/connect-apps)
- [Securely manage secrets, all services secrets are handled using this feature](https://docs.microsoft.com/en-us/azure/container-apps/secure-app)
- [Run containers from any registry, the Fabrikam Drone Delivery uses ACR to publish its Docker images](https://docs.microsoft.com/en-us/azure/container-apps/containers)
- [Use ARM templates to deploy my application, there is no need for another layer of indirection like Helm charts. All the Drone Delivery containers are part of the ARM templates](https://docs.microsoft.com/en-us/azure/container-apps/get-started)
- [Logs, see the container logs directly in Log Analytics without configuring any provider from code or Azure service](https://docs.microsoft.com/en-us/azure/container-apps/monitor).

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
| An Azure Container App Environment        | This is the managed Container App environment where Container Apps are deployed |
| Five Azure Container Apps                 | These are the Azure resources that represents the five Fabrikam microservices in the Azure Container App environment |
| An Azure Container Registry               | This is the private container registry where all Fabrikam workload images are uploaded and later pulled from the different Azure Container Apps |
| An Azure Log Analytics Workspace          | This is where all the Container Apps logs are sent        |
| An Azure Application Insights instance    | All services are sending trace information to a shared Azure Application Insights instance |
| Two Azure Cosmos Db instances             | Delivery and Package services have dependencies on Azure Cosmos DB |
| An Azure Redis Cache instance             | Delivery service uses Azure Redis cache to keep track of inflight deliveries |
| An Azure Service Bus                      | Ingestion and Workflow services communicate using Azure Service Bus queues |
| Five Azure User Managed Identities        | These are going to give `Read` and `List` secrets permissions over Azure KeyVault to the microservices. :warning: This is currently not use in use from this Reference Implementation. |
| Five Azure KeyVault instances             | Secrets are saved into Azure KeyVault instances. :warning: This is currently not use in use from this Reference Implementation. |

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
   az deployment group create -f ./workload/workload-stamp.json -g rg-shipping-dronedelivery -p droneSchedulerPrincipalId=$DRONESCHEDULER_PRINCIPAL_ID \
   -p workflowPrincipalId=$WORKFLOW_PRINCIPAL_ID \
   -p deliveryPrincipalId=$DELIVERY_PRINCIPAL_ID \
   -p ingestionPrincipalId=$INGESTION_ID_PRINCIPAL_ID \
   -p packagePrincipalId=$PACKAGE_ID_PRINCIPAL_ID
   ```

   :warning: Azure KeyVault and Managed Identities may be integrated in the future with Container Apps (Preview) in this Reference Implementation.

1. Obtain the ACR server details

   ```bash
   ACR_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.acrName.value -o tsv)
   ACR_SERVER=$(az acr show -n $ACR_NAME --query loginServer -o tsv)
   az acr update -n $ACR_NAME --admin-enabled true
   ACR_PASS=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)
   ```

1. Build the microservice images

   ```bash
   az acr build -r $ACR_NAME -t $ACR_SERVER/shipping/delivery:0.1.0 ./workload/src/shipping/delivery/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/shipping/ingestion:0.1.0 ./workload/src/shipping/ingestion/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/shipping/workflow:0.1.0 ./workload/src/shipping/workflow/.
   az acr build -r $ACR_NAME -f ./workload/src/shipping/dronescheduler/Dockerfile -t $ACR_SERVER/shipping/dronescheduler:0.1.0 ./workload/src/shipping/.
   az acr build -r $ACR_NAME -t $ACR_SERVER/shipping/package:0.1.0 ./workload/src/shipping/package/.
   ```

1. Get Application Insights instrumentation key

   ```bash
   AI_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.appInsightsName.value -o tsv)
   AI_KEY=$(az resource show -g rg-shipping-dronedelivery -n $AI_NAME --resource-type "Microsoft.Insights/components" --query properties.InstrumentationKey -o tsv)
   AI_ID=$(az resource show -g rg-shipping-dronedelivery -n $AI_NAME --resource-type "Microsoft.Insights/components" --query properties.AppId -o tsv)
   ```

1. Get microservices details

   ```bash
   # delivery
   DELIVERY_COSMOSDB_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.deliveryCosmosDbName.value -o tsv)
   DELIVERY_DATABASE_NAME="${DELIVERY_COSMOSDB_NAME}-db"
   DELIVERY_COLLECTION_NAME="${DELIVERY_COSMOSDB_NAME}-col"
   DELIVERY_COSMOSDB_ENDPOINT=$(az cosmosdb show -g rg-shipping-dronedelivery -n $DELIVERY_COSMOSDB_NAME --query documentEndpoint -o tsv)
   DELIVERY_COSMOSDB_KEY=$(az cosmosdb keys list -g rg-shipping-dronedelivery -n $DELIVERY_COSMOSDB_NAME --query primaryMasterKey -o tsv)
   DELIVERY_REDIS_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.deliveryRedisName.value -o tsv)
   DELIVERY_REDIS_ENDPOINT=$(az redis show -g rg-shipping-dronedelivery -n $DELIVERY_REDIS_NAME --query hostName -o tsv)
   DELIVERY_REDIS_KEY=$(az redis list-keys -g rg-shipping-dronedelivery -n $DELIVERY_REDIS_NAME --query primaryKey -o tsv)

   # drone scheduler
   DRONESCHEDULER_COSMOSDB_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.droneSchedulerCosmosDbName.value -o tsv)
   DRONESCHEDULER_COSMOSDB_ENDPOINT=$(az cosmosdb show -g rg-shipping-dronedelivery -n $DRONESCHEDULER_COSMOSDB_NAME --query documentEndpoint -o tsv)
   DRONESCHEDULER_COSMOSDB_KEY=$(az cosmosdb keys list -g rg-shipping-dronedelivery -n $DRONESCHEDULER_COSMOSDB_NAME --query primaryMasterKey -o tsv)

   # workflow
   WORKFLOW_NAMESPACE_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.ingestionQueueNamespace.value -o tsv)
   WORKFLOW_NAMESPACE_ENDPOINT=$(az servicebus namespace show -g rg-shipping-dronedelivery -n $WORKFLOW_NAMESPACE_NAME --query serviceBusEndpoint -o tsv)
   WORKFLOW_NAMESPACE_SAS_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.workflowServiceAccessKeyName.value -o tsv)
   WORKFLOW_NAMESPACE_SAS_KEY=$(az servicebus namespace authorization-rule keys list -g rg-shipping-dronedelivery --namespace-name $WORKFLOW_NAMESPACE_NAME -n $WORKFLOW_NAMESPACE_SAS_NAME --query primaryKey -o tsv)
   WORKFLOW_QUEUE_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.ingestionQueueName.value -o tsv)

   # package
   PACKAGE_MONGODB_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.packageMongoDbName.value -o tsv)
   PACKAGE_MONGODB_CONNNECTIONSTRING=$(az cosmosdb keys list --type connection-strings -g rg-shipping-dronedelivery --name $PACKAGE_MONGODB_NAME --query "connectionStrings[0].connectionString" -o tsv | sed 's/==/%3D%3D/g')

   # ingestion
   INGESTION_NAMESPACE_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.ingestionQueueNamespace.value -o tsv)
   INGESTION_NAMESPACE_SAS_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.ingestionServiceAccessKeyName.value -o tsv)
   INGESTION_NAMESPACE_SAS_KEY=$(az servicebus namespace authorization-rule keys list -g rg-shipping-dronedelivery --namespace-name $INGESTION_NAMESPACE_NAME -n $INGESTION_NAMESPACE_SAS_NAME --query primaryKey -o tsv)
   INGESTION_QUEUE_NAME=$(az deployment group show -g rg-shipping-dronedelivery -n workload-stamp --query properties.outputs.ingestionQueueName.value -o tsv)
   ```

## Deploy Azure Container App

1. Register the Azure Resource Manager provider for `Microsoft.App`

   ```bash
   az provider register --namespace Microsoft.App
   ```

1. Deploy the Container Apps (Preview) ARM template

   ```bash
   az deployment group create -f main.bicep -g rg-shipping-dronedelivery -p \
      acrSever=$ACR_SERVER \
      containerRegistryUser=$ACR_NAME \
      containerRegistryPassword=$ACR_PASS \
      applicationInsightsInstrumentationKey=$AI_KEY \
      deliveryCosmosdbDatabaseName=$DELIVERY_DATABASE_NAME \
      deliveryCosmosdbCollectionName=$DELIVERY_COLLECTION_NAME \
      deliveryCosmosdbEndpoint=$DELIVERY_COSMOSDB_ENDPOINT \
      deliveryCosmosdbKey=$DELIVERY_COSMOSDB_KEY \
      deliveryRedisEndpoint=$DELIVERY_REDIS_ENDPOINT \
      deliveryRedisKey=$DELIVERY_REDIS_KEY \
      droneSchedulerCosmosdbEndpoint=$DRONESCHEDULER_COSMOSDB_ENDPOINT \
      droneSchedulerCosmosdbKey=$DRONESCHEDULER_COSMOSDB_KEY \
      wokflowNamespaceEndpoint=$WORKFLOW_NAMESPACE_ENDPOINT \
      workflowNamespaceSASName=$WORKFLOW_NAMESPACE_SAS_NAME \
      workflowNamespaceSASKey=$WORKFLOW_NAMESPACE_SAS_KEY \
      workflowQueueName=$WORKFLOW_QUEUE_NAME \
      packageMongodbConnectionString=$PACKAGE_MONGODB_CONNNECTIONSTRING \
      ingestionNamespaceName=$INGESTION_NAMESPACE_NAME \
      ingestionNamespaceSASName=$INGESTION_NAMESPACE_SAS_NAME \
      ingestionNamespaceSASKey=$INGESTION_NAMESPACE_SAS_KEY \
      ingestionQueueName=$INGESTION_QUEUE_NAME
   ```

   :eyes: Please note that Azure Container Apps as well as this ARM API specification are currently in _Preview_ with [limited `location` support](https://azure.microsoft.com/global-infrastructure/services/?products=container-apps).

## Validation

Now that you have deployed in a Container Apps Environment, you can validate its functionality. This section will help you to validate the workload is exposed through a Container Apps External Ingress and responding to HTTP requests correctly.

### Steps

1. Get the Ingestion FQDN

    > :book: The app team conducts a final acceptance test to ensure that traffic is flowing end-to-end as expected. To do so, an HTTP request is submitted against the ingestion external ingress.

   ```bash
   INGESTION_FQDN=$(az deployment group show -g rg-shipping-dronedelivery -n main --query properties.outputs.ingestionFqdn.value -o tsv)
   ```

1. Send a request to https://dronedelivery.fabrikam.com.

   > :bulb: Since the certificate used for TLS is self-signed, the request disables TLS validation using the '-k' option.

   ```bash
   curl -X POST "https://${INGESTION_FQDN}/api/deliveryrequests" --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{
      "confirmationRequired": "None",
      "deadline": "",
      "dropOffLocation": "drop off",
      "expedited": true,
      "ownerId": "myowner",
      "packageInfo": {
        "packageId": "mypackage",
        "size": "Small",
        "tag": "mytag",
        "weight": 10
      },
      "pickupLocation": "mypickup",
      "pickupTime": "'$(date -u +%FT%TZ)'"
    }'
   ```

   The response to the request printed in your terminal should look similar to the one shown below:

   ```output
   {"deliveryId":"5453d09a-a826-436f-8e7d-4ff706367b04","ownerId":"myowner","pickupLocation":"mypickup","pickupTime":"2021-02-14T20:00:00.000+0000","deadline":"","expedited":true,"confirmationRequired":"None","packageInfo":{"packageId":"mypackage","size":"Small","weight":10.0,"tag":"mytag"},"dropOffLocation":"drop off"}
   ```

1. Query Application Insights to ensure your request have been ingested by the underlaying services

   :stopwatch: It might take five minutes for the query results to be available.

   ```bash
   az monitor app-insights query --app $AI_ID --analytics-query 'requests
   | summarize count_=sum(itemCount) by operation_Name
   | order by count_ desc
   | project strcat(operation_Name," (", count_, ")")' --query tables[0].rows[] -o table
   ```

   The following output demonstrates the type of response to expect from the CLI command.

   ```output
   Result
   --------------------------------------------------
   POST IngestionController/scheduleDeliveryAsync (1)
   PUT Deliveries/Put [id] (1)
   PUT /api/packages/mypackage (1)
   GET /api/packages/mypackage (1)
   PUT DroneDeliveries/Put [id] (1)
   ```

   :book: Above result demonstrates that the http request initiated from the client has been ingested by `IngestionController/scheduleDeliveryAsync` to be later consumed by the `Workflow` background process to be sent to `Deliveries/Put`, `/api/packages/mypackage` and `DroneDeliveries/Put` endpoints respectively. Them all are microservices running within Azure Container Apps.

## Troubleshooting

### Restart a revision

If you need a restart a revision with Provision Status `Failed` or for another reason you can use az cli:

```bash
az containerapp revision restart -g rg-shipping-dronedelivery --app <containerapp-name> -n <containerapp-revision-name>
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

## Next Steps

The team has been able to migrate and run Fabrikam Drone Delivery on top of Azure Container Apps (Preview). They are now laying out a new migration and modernization plan that will include:

1. [Start using DAPR](https://docs.microsoft.com/azure/container-apps/microservices#dapr-integration)
1. [Bring your own VNET](https://docs.microsoft.com/azure/container-apps/vnet-custom?tabs=bash&pivots=azure-portal)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.
