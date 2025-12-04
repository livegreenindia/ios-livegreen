// Helper to run the REST seeder with node-fetch available
global.fetch = require('node-fetch');
require('./seedActivitiesRest.js');
