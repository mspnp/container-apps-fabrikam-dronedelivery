// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { KoaApp } from './app.js';
import { Repository } from './models/repository.js';
import { Settings } from './util/settings.js';

export class PackageService {

  static async start() {
    const port = process.env.PORT || 80;

    console.log('Package service starting...');

    // Initialize repository with connection string
    try {
      await Repository.initialize(Settings.connectionString());
    } catch (ex: any) {
      console.error('failed to initialize repository - ensure connection string is configured');
      console.error(ex.message);
      process.exit(1);  // Crash the container
    }

    const app = KoaApp.create(Settings.logLevel());

    // Add package repo to the context
    app.context.packageRepository = new Repository();

    app.listen(port);
    console.log(`listening on port ${port}`);
  }
}
