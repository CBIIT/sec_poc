var express = require('express');
var router = express.Router();
var https = require('https');
const smart = require('fhirclient');

/*
  The promise when smart is ready.
  Handles all the requests with token to EPIC.
  Aka, call for observations and 
*/
async function handler(client, res) {
  // console.log(client)
  console.log(client.patient.id);
  const data = [];
  data.push(await (
      client.patient.id ? client.patient.read() : client.request("Patient")
  ));
  console.log(typeof(data));
  // client.patient.request("Observation", {"category":"laboratory"}).then((data) => {
  //   console.log(data);
  // });
  const q = new URLSearchParams();
  q.set("category", "laboratory");
  q.set("limit", "50");
  q.set("subject", client.patient.id);
  // Observation request
  data.push(
    await (
      client.request(`Observation?${q}`).then((data) => {
        return data;
      })
    )
  );

  const patientQ = new URLSearchParams();
  patientQ.set("patient", client.patient.id);
  // Diagnostic Report request
  data.push( 
    await(
        client.request(`DiagnosticReport?${patientQ}`).then((data) => {
          return data;
        })
    )
  );
  // Procedure request
  data.push(
    await(
      client.request(`Procedure?${patientQ}`).then((data) => {
        return data;
      })
      .catch(error => {
        console.log(error);
      })
    )
  )
  // Medication Dispense request
  data.push(
    await(
      client.request(`MedicationDispense?${patientQ}`).then((data) => {
        return data;
      })
      .catch(error => {
        console.log(error);
      })
    )
  );

  res.type("json").send(JSON.stringify(data, null, 4));
} 

async function observations(client){
  options = {
    host: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/',
    path: `Observation/${client.patient.id}`
  }
  req = https.request(options, (response) => {
    response.on('data', function(chunk) {
      console.log(chunk);
    });
  });
}

/* GET /app 
  Patient data EPIC listing.
  Acts as the index page
 */
router.get('/', function(req, res, next) {
  smart(req, res).ready().then(client => handler(client, res));
});

module.exports = router;