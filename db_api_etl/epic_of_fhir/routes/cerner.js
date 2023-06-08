

var express = require('express');
var router = express.Router();
const smart = require('fhirclient');
const path = require('path');


/* 
  GET cerner/redirect
  loads launch.html in view directory
  entry point for cerner test sandbox
*/
router.get('/redirect', function(req, res, next) {
  console.log("Attempting to login to Smart FHIR server");
  res.sendFile(path.join(__dirname + '/../views/cerner/launch.html'));
});

/*
  GET cerner/
  loads index.html in view directory
  last point in exchange.  Houses patient data loaded from example-smart-app.js file
*/
router.get('/', function(req, res, next) {
  res.sendFile(path.join(__dirname + '/../views/cerner/index.html'));
})

module.exports = router;

/* Test code for sec_poc app (Patient app side)

const smartSettings = {
  clientId: "90d00d27-1f90-4afa-aaba-783ff33ba624",
  redirectUri: "http://localhost:3000/cerner/sec_poc/",
  scope: 'patient/Patient.read patient/Observation.read launch online_access openid profile ',
  // iss: "https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/",
}

async function handler(client, res) {
  console.log("in handler");
  console.log(client.patient.id);
  const data = await (
      client.patient.id ? client.patient.read() : client.request("Patient")
  );
  res.type("json").send(JSON.stringify(data, null, 4));
} 

router.get('/redirect/sec_poc', function(req, res, next) {
  console.log("Attempting sec_poc login to Samrt FHIR");
  smart(req, res).authorize(smartSettings).catch(next);
})

router.get('/sec_poc/', function(req, res, next) {
  console.log("Here");
  smart(req, res).ready().then(client => handler(client, res));
})
*/