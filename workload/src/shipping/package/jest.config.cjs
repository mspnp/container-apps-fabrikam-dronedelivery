module.exports = {
  testEnvironment: 'node',
  bail: true,
  verbose: true,
  setupFiles: [
    './tests/jest.setup.js'
  ],
  setupFilesAfterEnv: [
    'jest-extended'
  ],
  testPathIgnorePatterns: [
    '/node_modules/'
  ],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1'
  },
  "moduleFileExtensions": ["js", "jsx", "json", "ts", "tsx"],
  "collectCoverage": true,
  "collectCoverageFrom": [
    "app/**/*.{ts,tsx,js,jsx}",
    "!app/spec/package-swagger.ts"
  ],
  "transform": {
    "\\.ts$": "ts-jest"
  },
  "coverageThreshold": {
    "global": {
      "lines": 60,
    }
  },
  "coverageReporters": [
    "text",
    "text-summary"
  ]
};