#!/bin/bash

set -e

npm i
npm run lint:fix
npm run format
npm run test
npm run copy-to-client:check
