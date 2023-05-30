

var express = require('express');

var router = express.Router();
const smart = require('fhirclient');


const smartSettings = {
  clientId: "<YOUR CLIENT ID>",
  redirectUri: "http://localhost:3000/app",
  scope: "PATIENT.READ, PATIENT.SEARCH, OBSERVATION.READ, OBSERVATION.SEARCH",
  iss: "https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/",
}

/* GET /launch 
  EPIC entry point for generating a token.
  This will be the first route hit when starting the process.
  and will redirect you to GET /app route
*/
router.get('/', function(req, res, next) {
  console.log("Attempting to login to Smart FHIR server")
  // smart(req, res).init(smartSettings).then(client => handler(client, res));
  smart(req, res).authorize(smartSettings).catch(next);
});

module.exports = router;