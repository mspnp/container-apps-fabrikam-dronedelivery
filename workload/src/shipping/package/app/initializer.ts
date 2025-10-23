// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { MongoErrors } from './util/mongo-err.js'
import { Settings } from './util/settings.js';
import appInsights from "applicationinsights";
import { MongoClient } from "mongodb";

export class PackageServiceInitializer {
    static async initialize(connection: string, collectionName: string, containerName: string) {
        try {
            PackageServiceInitializer.initAppInsights(containerName);
            await PackageServiceInitializer.initMongoDb(connection,
                collectionName);
        }
        catch (ex) {
            console.log(ex);
        }
    }

    private static async initMongoDb(connectionString: string, collectionName: string) {
        try {
            const client = await MongoClient.connect(connectionString);
            var db = client.db();
            await db.admin().command({
                shardCollection: db.databaseName + "." + collectionName,
                key: { tag: "hashed" },
            });
        }
        catch (ex: any) {
            if (ex.code != MongoErrors.CommandNotFound && ex.code != 9) {
                console.log(ex);
            }
        }
    }

    private static async initAppInsights(cloudRole = "package") {
        if (Settings.appInsigthsConnectionString()) {
            appInsights.setup(Settings.appInsigthsConnectionString());
            appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.cloudRole] = cloudRole;
            process.stdout.write('App insights setup - configuring client\n');
            appInsights.start();
            process.stdout.write('Application Insights started');
        } else {
            throw new Error('No app insights setup. Connection String must be specified in non-development environments.');
        }
    }
}
