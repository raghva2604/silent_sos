const express = require('express');
const { updateLocation, getLatestLocations } = require('../controllers/locationController');

const router = express.Router();

router.post('/update-live-location', updateLocation);
router.get('/latest-location', getLatestLocations);
router.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'silent-sos-backend' });
});

module.exports = router;
