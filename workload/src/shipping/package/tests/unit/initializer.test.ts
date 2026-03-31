// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

// jest.mock is hoisted above imports — MongoClient.connect is a jest.fn() by the
// time the initializer module is loaded.
jest.mock('mongodb', () => ({
  MongoClient: {
    connect: jest.fn(),
  },
}));

import { MongoClient } from 'mongodb';
import { PackageServiceInitializer } from '../../app/initializer';

// ── helpers ───────────────────────────────────────────────────────────────────

const mockClose   = jest.fn();
const mockCommand = jest.fn();

function makeClient(commandImpl?: () => Promise<any>) {
  mockCommand.mockImplementation(commandImpl ?? (() => Promise.resolve({})));
  mockClose.mockResolvedValue(undefined);
  return {
    db: () => ({
      databaseName: 'testdb',
      admin: () => ({ command: mockCommand }),
    }),
    close: mockClose,
  };
}

const mockConnect = MongoClient.connect as jest.Mock;

// ── tests ─────────────────────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  mockConnect.mockResolvedValue(makeClient());
});

describe('PackageServiceInitializer', () => {

  // ── input validation ────────────────────────────────────────────────────────

  describe('validate connection string', () => {

    it('throws when connection string is empty', async () => {
      await expect(PackageServiceInitializer.initialize('', 'col'))
        .rejects.toThrow('Connection string is required');
    });

    it('throws when connection string is whitespace only', async () => {
      await expect(PackageServiceInitializer.initialize('   ', 'col'))
        .rejects.toThrow('Connection string is required');
    });

    it('does not call MongoClient when connection string is invalid', async () => {
      await expect(PackageServiceInitializer.initialize('', 'col')).rejects.toThrow();
      expect(mockConnect).not.toHaveBeenCalled();
    });

  });

  describe('validate collection name', () => {

    it('throws when collection name is empty', async () => {
      await expect(PackageServiceInitializer.initialize('mongodb://host', ''))
        .rejects.toThrow('Collection name is required');
    });

    it('throws when collection name is whitespace only', async () => {
      await expect(PackageServiceInitializer.initialize('mongodb://host', '  '))
        .rejects.toThrow('Collection name is required');
    });

    it('does not call MongoClient when collection name is invalid', async () => {
      await expect(PackageServiceInitializer.initialize('mongodb://host', '')).rejects.toThrow();
      expect(mockConnect).not.toHaveBeenCalled();
    });

  });

  // ── happy path ──────────────────────────────────────────────────────────────

  describe('successful initialisation', () => {

    it('resolves when connection and collection name are valid', async () => {
      await expect(PackageServiceInitializer.initialize('mongodb://host', 'mycol'))
        .resolves.toBeUndefined();
    });

    it('calls MongoClient.connect with the supplied connection string', async () => {
      await PackageServiceInitializer.initialize('mongodb://host:27017', 'mycol');
      expect(mockConnect).toHaveBeenCalledWith('mongodb://host:27017');
    });

    it('always closes the MongoClient after a successful run', async () => {
      await PackageServiceInitializer.initialize('mongodb://host', 'mycol');
      expect(mockClose).toHaveBeenCalledTimes(1);
    });

    it('passes the correct shardCollection command', async () => {
      await PackageServiceInitializer.initialize('mongodb://host', 'col');
      expect(mockCommand).toHaveBeenCalledWith(
        expect.objectContaining({
          shardCollection: expect.stringContaining('col'),
          key: { tag: 'hashed' },
        })
      );
    });

  });

  // ── tolerated MongoDB errors ────────────────────────────────────────────────

  describe('tolerates expected MongoDB error codes', () => {

    it('ignores CommandNotFound (code 59) and resolves', async () => {
      const err = Object.assign(new Error('Command not found'), { code: 59 });
      mockConnect.mockResolvedValue(makeClient(() => Promise.reject(err)));

      await expect(PackageServiceInitializer.initialize('mongodb://host', 'col'))
        .resolves.toBeUndefined();
    });

    it('ignores already-sharded error (code 9) and resolves', async () => {
      const err = Object.assign(new Error('Already sharded'), { code: 9 });
      mockConnect.mockResolvedValue(makeClient(() => Promise.reject(err)));

      await expect(PackageServiceInitializer.initialize('mongodb://host', 'col'))
        .resolves.toBeUndefined();
    });

    it('still closes the client after a tolerated error', async () => {
      const err = Object.assign(new Error('Command not found'), { code: 59 });
      mockConnect.mockResolvedValue(makeClient(() => Promise.reject(err)));

      await PackageServiceInitializer.initialize('mongodb://host', 'col');
      expect(mockClose).toHaveBeenCalledTimes(1);
    });

  });

  // ── unexpected MongoDB errors ───────────────────────────────────────────────

  describe('re-throws unexpected MongoDB errors', () => {

    it('throws on an unrecognised error code', async () => {
      const err = Object.assign(new Error('Unexpected failure'), { code: 999 });
      mockConnect.mockResolvedValue(makeClient(() => Promise.reject(err)));

      await expect(PackageServiceInitializer.initialize('mongodb://host', 'col'))
        .rejects.toThrow('Unexpected failure');
    });

    it('still closes the client after an unexpected error (finally block)', async () => {
      const err = Object.assign(new Error('Unexpected failure'), { code: 999 });
      mockConnect.mockResolvedValue(makeClient(() => Promise.reject(err)));

      try {
        await PackageServiceInitializer.initialize('mongodb://host', 'col');
      } catch {}

      expect(mockClose).toHaveBeenCalledTimes(1);
    });

    it('throws when MongoClient.connect itself rejects', async () => {
      mockConnect.mockRejectedValue(new Error('Connection refused'));

      await expect(PackageServiceInitializer.initialize('mongodb://host', 'col'))
        .rejects.toThrow('Connection refused');
    });

  });

});
