// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using Azure.Messaging.ServiceBus;
using Fabrikam.Workflow.Service.Models;
using Fabrikam.Workflow.Service.RequestProcessing;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using JsonSerializer = Newtonsoft.Json.JsonSerializer;

namespace Fabrikam.Workflow.Service
{
    internal class WorkflowService : IHostedService
    {
        private readonly JsonSerializer _serializer;

        private readonly ILogger<WorkflowService> _logger;
        private readonly IRequestProcessor _requestProcessor;
        private readonly Func<IOptions<WorkflowServiceOptions>, ServiceBusClient> _createServiceBusClient;
        private readonly IOptions<WorkflowServiceOptions> _options;
        private ServiceBusProcessor _serviceBusProcessor;

        public WorkflowService(IOptions<WorkflowServiceOptions> options, ILogger<WorkflowService> logger, IRequestProcessor requestProcessor)
            : this(options, logger, requestProcessor, CreateServiceBusClient)
        { }

        public WorkflowService(IOptions<WorkflowServiceOptions> options, ILogger<WorkflowService> logger, IRequestProcessor requestProcessor, Func<IOptions<WorkflowServiceOptions>, ServiceBusClient> createServiceBusClient)
        {
            _options = options;
            _logger = logger;
            _requestProcessor = requestProcessor;
            _createServiceBusClient = createServiceBusClient;

            _serializer = new JsonSerializer();
        }

        private static ServiceBusClient CreateServiceBusClient(IOptions<WorkflowServiceOptions> options)
        {
            var connectionString = $"Endpoint={options.Value.QueueEndpoint};SharedAccessKeyName={options.Value.QueueAccessPolicyName};SharedAccessKey={options.Value.QueueAccessPolicyKey}";
            return new ServiceBusClient(connectionString);
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            var _serviceBusClient = _createServiceBusClient(_options);

            _serviceBusProcessor = _serviceBusClient.CreateProcessor(_options.Value.QueueName);
            _serviceBusProcessor.ProcessMessageAsync += ProcessMessageAsync;
            _serviceBusProcessor.ProcessErrorAsync += ProcessMessageExceptionAsync;
            await _serviceBusProcessor.StartProcessingAsync();

            _logger.LogInformation("Started");
            await Task.CompletedTask;
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            await _serviceBusProcessor?.StopProcessingAsync();
            await _serviceBusProcessor.DisposeAsync();
            _logger.LogInformation("Stopped");
        }

        private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
        {
            _logger.LogInformation("Processing message {messageId}", args.Message.MessageId);

            if (TryGetDelivery(args.Message, out var delivery))
            {
                try
                {
                    if (await _requestProcessor.ProcessDeliveryRequestAsync(delivery, args.Message.ApplicationProperties))
                    {
                        await args.CompleteMessageAsync(args.Message);
                        return;
                    }
                }
                catch (Exception e)
                {
                    _logger.LogError(e, "Error processing message {messageId}", args.Message.MessageId);
                }
            }

            try
            {
                await args.DeadLetterMessageAsync(args.Message);
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Error moving message {messageId} to dead letter queue", args.Message.MessageId);
            }
        }

        private Task ProcessMessageExceptionAsync(ProcessErrorEventArgs args)
        {
            // the error source tells me at what point in the processing an error occurred
            _logger.LogError(args.ErrorSource.ToString());
            // the fully qualified namespace is available
            _logger.LogError(args.FullyQualifiedNamespace);
            // as well as the entity path
            _logger.LogError(args.EntityPath);
            _logger.LogError(args.Exception, "Error processing message");

            return Task.CompletedTask;
        }

        private bool TryGetDelivery(ServiceBusReceivedMessage message, out Delivery delivery)
        {
            try
            {
                using (var payloadStream = new MemoryStream(message.Body.ToArray(), false))
                using (var streamReader = new StreamReader(payloadStream, Encoding.UTF8))
                using (var jsonReader = new JsonTextReader(streamReader))
                {
                    delivery = _serializer.Deserialize<Delivery>(jsonReader);
                }
                return true;
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Cannot parse payload from message {messageId}", message.MessageId);
            }

            delivery = null;
            return false;
        }
    }
}
