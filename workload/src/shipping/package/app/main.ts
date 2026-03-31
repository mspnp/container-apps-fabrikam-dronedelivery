// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { PackageServiceInitializer } from './initializer.js'
import { PackageService } from './server.js';
import { Settings } from './util/settings.js';

PackageServiceInitializer.initialize(Settings.connectionString(), Settings.collectionName())
    .then(() => {
        PackageService.start();
    })
    .catch((ex) => {
        console.error('Initialization failed:', ex.message);
        process.exit(1);
    });
