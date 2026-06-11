// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Fabrikam.Workflow.Service
{
    /// <summary>
    /// Application Insights setup class based on https://learn.microsoft.com/azure/azure-monitor/app/console
    /// </summary>
    /// <remarks>
    /// Telemetry Modules initialization as expected based on https://github.com/Microsoft/ApplicationInsights-aspnetcore/blob/04b5485d4a8aa498b2d99c60bdf8ca59bc9103fc/src/Microsoft.ApplicationInsights.AspNetCore/Implementation/TelemetryConfigurationOptions.cs#L27
    /// </remarks>
    internal static class TracingExtensions
    {
        // Key Vault secret name (used via key-per-file mount)
        private const string CustomKeyVaultAppInsightsIKey = "ApplicationInsights-InstrumentationKey";
        // Config key for connection string (maps to ApplicationInsights__ConnectionString env var)
        private const string AppInsightsConnectionString = "ApplicationInsights:ConnectionString";
        // Standard env var name — primary credential delivery mechanism in ACA (set via secret).
        // Also read automatically by the Azure Monitor OpenTelemetry exporter when not overridden in code.
        private const string StandardConnectionStringEnvVar = "APPLICATIONINSIGHTS_CONNECTION_STRING";
        // Config key for ikey (maps to ApplicationInsights__InstrumentationKey env var in ACA)
        private const string AppInsightsInstrumentationKey = "ApplicationInsights:InstrumentationKey";

        public static IServiceCollection AddApplicationInsightsTelemetry(
          this IServiceCollection services,
          IConfiguration configuration)
        {
            // Note:
            // This service is a worker host (HostBuilder), not a web host. The correct AI SDK for
            // this context is Microsoft.ApplicationInsights.WorkerService, which does not require
            // ASP.NET Core infrastructure (IHttpContextAccessor, IWebHostEnvironment). Using
            // AspNetCore package here causes a DI resolution failure at startup.

            var connectionString = configuration[AppInsightsConnectionString]
                ?? configuration[StandardConnectionStringEnvVar];
            var instrumentationKey = configuration[CustomKeyVaultAppInsightsIKey]
                ?? configuration[AppInsightsInstrumentationKey];

            // Skip registration entirely when no credentials are present to avoid a startup crash
            // from the underlying Azure Monitor OpenTelemetry exporter.
            if (string.IsNullOrWhiteSpace(connectionString) && string.IsNullOrWhiteSpace(instrumentationKey))
                return services;

            services.AddApplicationInsightsTelemetryWorkerService(options =>
            {
                if (!string.IsNullOrWhiteSpace(connectionString))
                {
                    options.ConnectionString = connectionString;
                }
                else if (!string.IsNullOrWhiteSpace(instrumentationKey))
                {
                    // Keep compatibility with existing Key Vault based iKey deployments.
                    options.ConnectionString = $"InstrumentationKey={instrumentationKey}";
                }
            });

            return services;
        }
    }
}
