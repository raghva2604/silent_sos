const express = require('express');
const { generateIncidentSummary } = require('../controllers/aiController');

const router = express.Router();

router.post('/incident-summary', generateIncidentSummary);

module.exports = router;
