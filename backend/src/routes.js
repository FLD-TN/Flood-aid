/**
 * Routes — All API endpoints
 */

const express = require('express');
const router = express.Router();

// Controllers
const sosController = require('./controllers/sosController');
const locationController = require('./controllers/locationController');
const volunteerController = require('./controllers/volunteerController');
const adminController = require('./controllers/adminController');
const flagController = require('./controllers/flagController');
const sseController = require('./controllers/sseController');
const { authMiddleware } = require('./middleware/authMiddleware');

// ====== Module 1: SOS ======
router.get('/sos/active', authMiddleware, sosController.getActiveByPhone);
router.post('/sos', authMiddleware, sosController.createSos);
router.get('/cases/nearby', sosController.getNearbyCases);
router.get('/case/:id', sosController.getCaseById);
router.get('/case/:id/tnv-location', sosController.getTnvLocation);
router.get('/case/:id/stream', sseController.streamCase);
router.post('/case/:id/accept', sosController.acceptCase);
router.post('/case/:id/resolve', sosController.resolveCase);

// ====== Module 3: Location Tracking ======
router.post('/location', locationController.updateVolunteerLocation);

// ====== Module 3: Volunteers ======
router.post('/volunteers/register', authMiddleware, volunteerController.registerVolunteer);
router.get('/volunteers', volunteerController.listVolunteers);
router.get('/volunteers/locations', volunteerController.getVolunteerLocations);
router.put('/volunteers/:id/approve', volunteerController.approveVolunteer);
router.put('/volunteers/:id/availability', volunteerController.setAvailability);

// ====== Module 5: Admin Dashboard ======
router.get('/admin/case-clusters', adminController.getCaseClusters);
router.get('/admin/cases', adminController.getAllCases);
router.get('/admin/stats', adminController.getDashboardStats);

// ====== Module 5: Warning Flags ======
router.post('/flags', flagController.createFlag);
router.get('/flags', flagController.getFlags);
router.delete('/flags/:id', flagController.deactivateFlag);

module.exports = router;
