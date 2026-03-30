// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { Settings } from '../../app/util/settings';

const ENV_KEYS = ['COLLECTION_NAME', 'CONNECTION_STRING', 'CONTAINER_NAME', 'LOG_LEVEL'];

// Save and restore real env values around each test that needs to clear them.
let savedEnv: Partial<NodeJS.ProcessEnv>;

beforeEach(() => {
  savedEnv = {};
  ENV_KEYS.forEach(k => { savedEnv[k] = process.env[k]; });
});

afterEach(() => {
  ENV_KEYS.forEach(k => {
    if (savedEnv[k] === undefined) {
      delete process.env[k];
    } else {
      process.env[k] = savedEnv[k];
    }
  });
});

describe('Settings', () => {

  describe('throws when required environment variables are missing', () => {

    it('throws for missing COLLECTION_NAME', () => {
      delete process.env['COLLECTION_NAME'];
      expect(() => Settings.collectionName())
        .toThrow('COLLECTION_NAME environment variable is required');
    });

    it('throws for whitespace-only COLLECTION_NAME', () => {
      process.env['COLLECTION_NAME'] = '   ';
      expect(() => Settings.collectionName())
        .toThrow('COLLECTION_NAME environment variable is required');
    });

    it('throws for missing CONNECTION_STRING', () => {
      delete process.env['CONNECTION_STRING'];
      expect(() => Settings.connectionString())
        .toThrow('CONNECTION_STRING environment variable is required');
    });

    it('throws for whitespace-only CONNECTION_STRING', () => {
      process.env['CONNECTION_STRING'] = '  ';
      expect(() => Settings.connectionString())
        .toThrow('CONNECTION_STRING environment variable is required');
    });

    it('throws for missing CONTAINER_NAME', () => {
      delete process.env['CONTAINER_NAME'];
      expect(() => Settings.containerName())
        .toThrow('CONTAINER_NAME environment variable is required');
    });

    it('throws for whitespace-only CONTAINER_NAME', () => {
      process.env['CONTAINER_NAME'] = ' ';
      expect(() => Settings.containerName())
        .toThrow('CONTAINER_NAME environment variable is required');
    });

  });

  describe('returns configured values when environment variables are set', () => {

    it('returns all configured values', () => {
      process.env['COLLECTION_NAME']  = 'my-collection';
      process.env['CONNECTION_STRING'] = 'mongodb://host:27017';
      process.env['CONTAINER_NAME']   = 'my-container';
      process.env['LOG_LEVEL']        = 'warn';

      expect(Settings.collectionName()).toBe('my-collection');
      expect(Settings.connectionString()).toBe('mongodb://host:27017');
      expect(Settings.containerName()).toBe('my-container');
      expect(Settings.logLevel()).toBe('warn');
    });

    it('defaults LOG_LEVEL to "debug" when not set', () => {
      delete process.env['LOG_LEVEL'];
      expect(Settings.logLevel()).toBe('debug');
    });

  });

});

