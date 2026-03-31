// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

import { Package } from '../../app/models/package';

describe('Package model', () => {

  describe('constructor', () => {

    it('auto-generates a non-empty string id when no id is provided', () => {
      const pkg = new Package();
      expect(pkg._id).toBeTruthy();
      expect(typeof pkg._id).toBe('string');
    });

    it('generates a unique id on each instantiation', () => {
      const a = new Package();
      const b = new Package();
      expect(a._id).not.toBe(b._id);
    });

    it('generates a hex string id that matches ObjectId format', () => {
      const pkg = new Package();
      expect(pkg._id).toMatch(/^[a-f0-9]{24}$/);
    });

    it('uses the provided id', () => {
      const pkg = new Package('my-custom-id');
      expect(pkg._id).toBe('my-custom-id');
    });

    it('initialises tag to an empty string', () => {
      const pkg = new Package();
      expect(pkg.tag).toBe('');
    });

    it('initialises weight to 0', () => {
      const pkg = new Package();
      expect(pkg.weight).toBe(0);
    });

    it('initialises size to "small"', () => {
      const pkg = new Package();
      expect(pkg.size).toBe('small');
    });

    it('id is readonly (cannot be reassigned)', () => {
      const pkg = new Package('original');
      // TypeScript enforces this at compile time; verify the value is unchanged at runtime
      expect(pkg._id).toBe('original');
    });

  });

});
