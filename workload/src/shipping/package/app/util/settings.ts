// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

export class Settings {
  static collectionName(): string {
    const value = process.env['COLLECTION_NAME'];
    if (!value || value.trim() === '') {
      throw new Error('COLLECTION_NAME environment variable is required and cannot be empty');
    }
    return value;
  }

  static connectionString(): string {
    const value = process.env['CONNECTION_STRING'];
    if (!value || value.trim() === '') {
      throw new Error('CONNECTION_STRING environment variable is required and cannot be empty');
    }
    return value;
  }

  static containerName(): string {
    const value = process.env['CONTAINER_NAME'];
    if (!value || value.trim() === '') {
      throw new Error('CONTAINER_NAME environment variable is required and cannot be empty');
    }
    return value;
  }

  static logLevel(): string {
    return process.env['LOG_LEVEL'] || 'debug';
  }
}