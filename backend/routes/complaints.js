const express = require('express');
const { createComplaint, listComplaints } = require('../controllers/complaintController');
const authMiddleware = require('../middleware/authMiddleware');
const { requireRole } = require('../middleware/roleMiddleware');

const router = express.Router();

router.post('/', authMiddleware, createComplaint);
router.get('/', authMiddleware, listComplaints);
router.get('/admin', authMiddleware, requireRole('admin'), listComplaints);

module.exports = router;
