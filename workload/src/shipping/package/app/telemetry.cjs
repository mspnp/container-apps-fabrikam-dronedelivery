// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

// CommonJS wrapper for ApplicationInsights v3.x initialization.
//
// This file MUST be loaded before any other application code so that
// OpenTelemetry can monkey-patch Node.js core modules (http, https, etc.)
// before Koa, MongoDB, or any other framework imports them.
//
// Loaded via: node --require ./telemetry.cjs main.js
// (set in Dockerfile ENTRYPOINT and gulp nodemon nodeArgs)

const applicationinsights = require('applicationinsights');

const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING
                      || process.env.APPINSIGHTS_CONNECTION_STRING;

if (connectionString) {
    applicationinsights
        .setup(connectionString)
        .setSendLiveMetrics(true)
        .start();

    // Set cloud role for identification in Application Insights.
    // defaultClient.context.tags is the v2-compat shim still supported in v3.x.
    applicationinsights.defaultClient.context.tags[
        applicationinsights.defaultClient.context.keys.cloudRole
    ] = process.env.CONTAINER_NAME || 'package';

    process.stdout.write('Application Insights started (v3.x via telemetry.cjs)\n');
} else {
    process.stdout.write('WARNING: No Application Insights connection string found. Telemetry disabled.\n');
}

module.exports = {
    telemetryClient: applicationinsights.defaultClient,
};
