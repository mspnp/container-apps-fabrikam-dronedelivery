// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using Azure.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Serilog;
using System;

namespace Fabrikam.DroneDelivery.DroneSchedulerService
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var host = CreateHostBuilder(args).Build();
            var logger = host.Services.GetRequiredService<ILogger<Program>>();
            logger.LogInformation("Fabrikam Dronescheduler Service is starting.");

            host.Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder
                        .UseStartup<Startup>()
                        .ConfigureAppConfiguration(configurationBuilder =>
                        {
                            var buildConfig = configurationBuilder.Build();

                            if (buildConfig["KEY_VAULT_URI"] is var keyVaultUri && !string.IsNullOrEmpty(keyVaultUri))
                            {
                                configurationBuilder.AddAzureKeyVault(new Uri(keyVaultUri), new DefaultAzureCredential());
                            }
                        })
                        .ConfigureLogging((hostingContext, loggingBuilder) =>
                        {
                            // Keep Application Insights logging in non-test environments.
                            // Integration tests run with ASPNETCORE_ENVIRONMENT=Test and avoid this provider
                            // to prevent test host startup failures caused by telemetry package/runtime mismatch.
                            if (!hostingContext.HostingEnvironment.IsEnvironment("Test"))
                            {
                                loggingBuilder.AddApplicationInsights();
                            }

                            loggingBuilder.AddSerilog(dispose: true);
                        })
                        .UseUrls("http://0.0.0.0:8080");
                });
    }
}
