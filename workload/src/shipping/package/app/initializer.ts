// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { MongoErrors } from './util/mongo-err.js'
import { MongoClient } from "mongodb";

export class PackageServiceInitializer {
    static async initialize(connection: string, collectionName: string) {
        try {
            await PackageServiceInitializer.initMongoDb(connection, collectionName);
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
}
