// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

// Mock Settings before any module is loaded so that Repository's static
// `collectionName` initialisation does not throw.
jest.mock('../../app/util/settings', () => ({
  Settings: {
    collectionName:  jest.fn().mockReturnValue('test-collection'),
    connectionString: jest.fn().mockReturnValue('mongodb://localhost:27017'),
    containerName:   jest.fn().mockReturnValue('package'),
    logLevel:        jest.fn().mockReturnValue('error'),
  },
}));

import { Package, PackageSize } from '../../app/models/package';
import { Repository } from '../../app/models/repository';
import * as apiModels from '../../app/models/api-models';

describe('Repository mapping', () => {

  const repo = new Repository();

  // ── mapPackageDbToApi ──────────────────────────────────────────────────────

  describe('mapPackageDbToApi', () => {

    it('maps _id to id', () => {
      const pkg = new Package('pkg-001');
      const result = repo.mapPackageDbToApi(pkg);
      expect(result.id).toBe('pkg-001');
    });

    it('maps size correctly', () => {
      const pkg = new Package('pkg-002');
      pkg.size = 'medium';
      const result = repo.mapPackageDbToApi(pkg);
      expect(result.size).toBe('medium');
    });

    it('maps all valid sizes', () => {
      const sizes: PackageSize[] = ['small', 'medium', 'large'];
      for (const s of sizes) {
        const pkg = new Package();
        pkg.size = s;
        expect(repo.mapPackageDbToApi(pkg).size).toBe(s);
      }
    });

    it('returns empty string for a falsy size', () => {
      const pkg = new Package('pkg-003');
      (pkg as any).size = null;  // force falsy at runtime
      const result = repo.mapPackageDbToApi(pkg);
      expect(result.size).toBe('');
    });

    it('maps tag correctly', () => {
      const pkg = new Package('pkg-004');
      pkg.tag = 'fragile';
      const result = repo.mapPackageDbToApi(pkg);
      expect(result.tag).toBe('fragile');
    });

    it('maps weight correctly', () => {
      const pkg = new Package('pkg-005');
      pkg.weight = 42.5;
      const result = repo.mapPackageDbToApi(pkg);
      expect(result.weight).toBe(42.5);
    });

    it('returns an apiModels.Package instance', () => {
      const result = repo.mapPackageDbToApi(new Package());
      expect(result).toBeInstanceOf(apiModels.Package);
    });

  });

  // ── mapPackageApiToDb ──────────────────────────────────────────────────────

  describe('mapPackageApiToDb', () => {

    it('maps size from api to db', () => {
      const apiPkg = new apiModels.Package();
      apiPkg.size = 'large';
      const result = repo.mapPackageApiToDb(apiPkg, 'pkg-010');
      expect(result.size).toBe('large');
    });

    it('maps weight from api to db', () => {
      const apiPkg = new apiModels.Package();
      apiPkg.weight = 7;
      const result = repo.mapPackageApiToDb(apiPkg, 'pkg-011');
      expect(result.weight).toBe(7);
    });

    it('maps tag from api to db', () => {
      const apiPkg = new apiModels.Package();
      apiPkg.tag = 'urgent';
      const result = repo.mapPackageApiToDb(apiPkg, 'pkg-012');
      expect(result.tag).toBe('urgent');
    });

    it('uses the explicit id when provided', () => {
      const apiPkg = new apiModels.Package();
      const result = repo.mapPackageApiToDb(apiPkg, 'explicit-id');
      expect(result._id).toBe('explicit-id');
    });

    it('auto-generates a non-empty id when none is provided', () => {
      const apiPkg = new apiModels.Package();
      const result = repo.mapPackageApiToDb(apiPkg);
      expect(result._id).toBeTruthy();
    });

    it('returns a Package instance', () => {
      const result = repo.mapPackageApiToDb(new apiModels.Package(), 'pkg-013');
      expect(result).toBeInstanceOf(Package);
    });

  });

});
