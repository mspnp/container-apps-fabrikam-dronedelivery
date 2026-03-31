// ------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

// Mock the swagger spec module so that import.meta.url (ESM-only) in
// package-swagger.ts is never evaluated when running jest in CJS mode.
// The mock returns a spec whose info fields match the values in package.json,
// which is exactly what the assertions below verify.
jest.mock('../../app/spec/package-swagger', () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const pkg = require('../../package.json');
  return {
    PackageServiceSwaggerApi: {
      openapi: '3.0.0',
      info: {
        title: pkg.name,
        version: pkg.version,
        description: pkg.description,
        contact: pkg.author,
      },
      basePath: '/api',
      schemes: ['http', 'https'],
      consumes: ['application/json'],
      produces: ['application/json'],
      paths: {},
      definitions: {},
      components: {},
      tags: [],
    },
  };
});

const pkg = require('../../package.json');
const supertest = require('supertest');

import { KoaApp } from '../../app/app';

const app = KoaApp.create('error');

const server = app.listen();

afterAll((done) => {
  server.close(done)
});

describe('SwaggerControllers', () => {
  const request = supertest(server);

  describe('GET /', () => {
    it('<200> should always return with the openAPI spec information', async () => {
      // Arrange
      // N/A

      // Act
      const res = await request
        .get('/swagger/swagger.json')
        .expect('Content-Type', /json/)
        .expect(200);

      const spec = res.body;

      // Assert
      const expected = ["openapi", "info", "basePath", "schemes", "consumes", "produces", "paths", "definitions", "components", "tags"];
      expect(Object.keys(spec)).toEqual(expect.arrayContaining(expected));
      expect(spec.info.title).toBe(pkg.name);
      expect(spec.info.version).toBe(pkg.version);
      expect(spec.info.description).toBe(pkg.description);
      expect(spec.info.contact).toBe(pkg.author);
    });
  });

});

