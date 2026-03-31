// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

const supertest = require('supertest');
// Prevent __filename collision: package-swagger.ts uses import.meta.url which
// ts-jest (CJS mode) compiles to `const __filename = ...` clashing with Jest's own.
jest.mock('../../app/spec/package-swagger', () => ({ PackageServiceSwaggerApi: {} }));


import { KoaApp } from '../../app/app';

const app = KoaApp.create('debug');

const server = app.listen();

afterAll((done) => {
  server.close(done)
});

describe('HealthzControllers', () => {
  const request = supertest(server);

  describe('GET /', () => {
    it('<200> should always return with the package utilization information', async () => {
      //Arrange
      const expected = ['status'];

      // Act
      const res = await request
        .get('/healthz')
        .expect('Content-Type', /json/)
        .expect(200);
      const pkg = res.body;

      // Assert
      expect(Object.keys(pkg)).toEqual(expect.arrayContaining(expected));
      expect(pkg.status).toBe("OK");
    });
  });

});
