# Fabrikam Drone Delivery - Shared services

This repository contains source files and build instructions for the containerized Fabrikam Drone Delivery application. Once all the microservices are built and pushed to your Azure Container Registry, they're ready to be pulled by any Azure service that has support for containers.

It is used in the [Fabrikam drone delivery](https://github.com/mspnp/container-apps-fabrikam-dronedelivery) reference implementation.

## The Drone Delivery app

The Drone Delivery application is a sample application that consists of several microservices. Because it's a sample, the functionality is simulated, but the APIs and microservices interactions are intended to reflect real-world design patterns.

## Microservices and folder structure

- Ingestion service. Receives client requests and buffers them  (./src/shipping/ingestion)
- Workflow service. Dispatches client requests and manages the delivery workflow (./src/shipping/workflow)
- Package service. Manages packages (./src/shipping/package)
- Drone scheduler service. Schedules drones and monitors drones in flight (./src/shipping/dronescheduler)
- Delivery service. Manages deliveries that are scheduled or in-transit (./src/shipping/delivery).

## Deploy an Azure Container Registry (ACR)

Set environment variables.

```bash
export LOCATION=eastus
```

### Log in to Azure CLI

```bash
az login
```

### Deploy the workload's prerequisites

```bash
az deployment sub create --name workload-stamp-prereqs --location ${LOCATION} --template-file ./workload-stamp-prereqs.bicep
```

:book: This pre-flight Bicep template is creating a general purpose resource group  as well as one dedicated for the Azure Container Registry. Additionally five User Identites are provisioned as part of this too that will be later associated to every containerized microservice. This is because they will need Azure RBAC roles over the Azure KeyVault to read secrets in runtime. The resources will be created on the resouce group location and each resource group will contain the region as part of their names

### Get the workload user assigned identities

```bash
DELIVERY_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery-${LOCATION} -n uid-delivery --query principalId -o tsv) && \
DRONESCHEDULER_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery-${LOCATION} -n uid-dronescheduler --query principalId -o tsv) && \
WORKFLOW_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery-${LOCATION} -n uid-workflow --query principalId -o tsv) && \
PACKAGE_ID_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery-${LOCATION} -n uid-package --query principalId -o tsv) && \
INGESTION_ID_PRINCIPAL_ID=$(az identity show -g rg-shipping-dronedelivery-${LOCATION} -n uid-ingestion --query principalId -o tsv)
```

### Deploy the workload

```bash
az deployment group create -f ./workload-stamp.bicep -g rg-shipping-dronedelivery-${LOCATION} -p droneSchedulerPrincipalId=$DRONESCHEDULER_PRINCIPAL_ID \
-p workflowPrincipalId=$WORKFLOW_PRINCIPAL_ID \
-p deliveryPrincipalId=$DELIVERY_PRINCIPAL_ID \
-p ingestionPrincipalId=$INGESTION_ID_PRINCIPAL_ID \
-p packagePrincipalId=$PACKAGE_ID_PRINCIPAL_ID
```

### Assign Azure Container Registry variables

```bash
ACR_NAME=$(az deployment group show -g rg-shipping-dronedelivery-${LOCATION} -n workload-stamp --query properties.outputs.acrName.value -o tsv)
ACR_SERVER=$(az acr show -n $ACR_NAME --query loginServer -o tsv)
```

## Build the microservice images

### Steps

1. Build the Delivery service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/delivery:0.1.0 ./src/shipping/delivery/.
```

2. Build the Ingestion service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/ingestion:0.1.0 ./src/shipping/ingestion/.
```

3. Build the Workflow service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/workflow:0.1.0 ./src/shipping/workflow/.
```

4. Build the DroneScheduler service.

```bash
az acr build -r $ACR_NAME -f ./src/shipping/dronescheduler/Dockerfile -t $ACR_SERVER/dronescheduler:0.1.0 ./src/shipping/.
```

5. Build the Package service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/package:0.1.0 ./src/shipping/package/.
```

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
