
// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Linq;
using Microsoft.Extensions.Logging;
using Fabrikam.DroneDelivery.DeliveryService.Models;
using CosmosContainer = Microsoft.Azure.Cosmos.Container;


namespace Fabrikam.DroneDelivery.DeliveryService.Services
{
    public static class CosmosDBRepository<T> where T : BaseDocument
    {
        private static CosmosClient client;
        private static Container container;

        internal static string Endpoint;
        internal static string Key;
        internal static string DatabaseId;
        internal static string ContainerId;
        internal static ILogger logger;

        public static async void Configure(string endpoint, string key, string databaseId, string containerId, ILoggerFactory loggerFactory)
        {
            Endpoint = endpoint;
            Key = key;
            DatabaseId = databaseId;
            ContainerId = containerId;

            client = new CosmosClient(Endpoint, Key);
            logger = loggerFactory.CreateLogger(nameof(CosmosDBRepository<T>));
            logger.LogInformation($"Creating CosmosDb Database {DatabaseId} if not exists...");
            var databaseResponse = await client.CreateDatabaseIfNotExistsAsync(DatabaseId);
            logger.LogInformation($"CosmosDb Database {DatabaseId} creation if not exists: OK!");
            var containerResponse = await databaseResponse.Database.CreateContainerIfNotExistsAsync(ContainerId, "/partitionKey", 1000);
            container = containerResponse.Container;
            logger.LogInformation($"CosmosDb Container {ContainerId} creation if not exists: OK!");
        }

        public static async Task<T> GetItemAsync(string id, string partitionKey)
        {
            using (logger.BeginScope(nameof(GetItemAsync)))
            {
                logger.LogInformation("id: {Id}, partitionKey: {PartitionKey}", id, partitionKey);

                try
                {
                    logger.LogInformation("Start: Using CosmosClient to read document");
                    ItemResponse<T> response = await container.ReadItemAsync<T>(id, new PartitionKey(partitionKey));
                    logger.LogInformation("End: Using CosmosClient to read document");

                    return response.Resource;
                }
                catch (CosmosException e) when (e.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    return null;
                }
            }
        }

        public static async Task<IEnumerable<T>> GetItemsAsync(Expression<Func<T, bool>> predicate, string partitionKey)
        {
            using (logger.BeginScope(nameof(GetItemsAsync)))
            {
                logger.LogInformation("partitionKey: {PartitionKey}", partitionKey);

                var query = container.GetItemLinqQueryable<T>(true)
                    .Where(predicate)
                    .Where(d => d.DocumentType == typeof(T).ToString())
                    .ToFeedIterator();

                List<T> results = new List<T>();

                logger.LogInformation("Start: reading results from query");
                while (query.HasMoreResults)
                {
                    var response = await query.ReadNextAsync();
                    results.AddRange(response);
                }
                logger.LogInformation("End: reading results from query");

                return results;
            }
        }

        public static async Task<ItemResponse<T>> CreateItemAsync(T item, string partitionKey)
        {
            using (logger.BeginScope(nameof(CreateItemAsync)))
            {
                logger.LogInformation("partitionKey: {PartitionKey}", partitionKey);

                item.DocumentType = typeof(T).ToString();
                item.PartitionKey = partitionKey;

                try
                {
                    logger.LogInformation("Start: creating document");
                    var response = await container.CreateItemAsync(item, new PartitionKey(partitionKey));
                    logger.LogInformation("End: creating document");

                    return response;
                }
                catch (CosmosException e) when (e.StatusCode == System.Net.HttpStatusCode.Conflict)
                {
                    throw new DuplicateResourceException("CosmosDB Conflict", e);
                }
            }
        }

        public static async Task<ItemResponse<T>> UpdateItemAsync(string id, T item, string partitionKey)
        {
            using (logger.BeginScope(nameof(UpdateItemAsync)))
            {
                logger.LogInformation("id: {Id}, partitionKey: {PartitionKey}", id, partitionKey);

                item.DocumentType = typeof(T).ToString();

                logger.LogInformation("Start: replacing document");
                var response = await container.ReplaceItemAsync(item, id, new PartitionKey(partitionKey));
                logger.LogInformation("End: replacing document");

                return response;
            }
        }
    }
}
