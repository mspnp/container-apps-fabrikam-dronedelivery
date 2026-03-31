// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { MongoErrors } from './util/mongo-err.js'
import { MongoClient } from "mongodb";

export class PackageServiceInitializer {
    static async initialize(connection: string, collectionName: string) {
        // Validate required parameters
        if (!connection || connection.trim() === '') {
            throw new Error('Connection string is required and cannot be empty');
        }
        if (!collectionName || collectionName.trim() === '') {
            throw new Error('Collection name is required and cannot be empty');
        }

        try {
            await PackageServiceInitializer.initMongoDb(connection, collectionName);
        } catch (ex: any) {
            console.error(`MongoDB initialization failed: ${ex.message}`);
            throw ex;  // Re-throw to allow caller to handle
        }
    }

    private static async initMongoDb(connectionString: string, collectionName: string) {
        const client = await MongoClient.connect(connectionString);
        try {
            const db = client.db();
            await db.admin().command({
                shardCollection: `${db.databaseName}.${collectionName}`,
                key: { tag: 'hashed' },
            });
        } catch (ex: any) {
            // Ignore if collection is already sharded or command not found
            if (ex.code !== MongoErrors.CommandNotFound && ex.code !== 9) {
                console.error(`MongoDB sharding error: ${ex.message}`);
                throw ex;  // Re-throw unexpected errors
            }
        } finally {
            // Ensure client is always closed, even if an error occurs
            await client.close();
        }
    }
}
