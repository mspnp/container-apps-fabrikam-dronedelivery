// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

// Default environment variables for all unit tests.
// Individual tests that validate missing-env-var behaviour should
// delete these in beforeEach and restore them in afterEach.
process.env['COLLECTION_NAME']  = process.env['COLLECTION_NAME']  || 'test-collection';
process.env['CONNECTION_STRING'] = process.env['CONNECTION_STRING'] || 'mongodb://localhost:27017';
process.env['CONTAINER_NAME']   = process.env['CONTAINER_NAME']   || 'package';
process.env['LOG_LEVEL']        = process.env['LOG_LEVEL']        || 'error'; // suppress log noise in tests
