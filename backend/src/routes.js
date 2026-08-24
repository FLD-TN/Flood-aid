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
const adminAuthController = require('./controllers/adminAuthController');
const sseController = require('./controllers/sseController');
const authController = require('./controllers/authController');
const kycController = require('./controllers/kycController');
const chatController = require('./controllers/chatController');
const dialectController = require('./controllers/dialectController');
const geoController = require('./controllers/geoController');
const sttController = require('./controllers/sttController');
const { authMiddleware } = require('./middleware/authMiddleware');
const { adminAuthMiddleware } = require('./middleware/adminAuthMiddleware');

// ====== Admin Auth ======
router.post('/admin/register', adminAuthController.register);
router.post('/admin/login', adminAuthController.login);

// ====== Module 0: Auth & eKYC ======
router.post('/auth/verify-phone', authMiddleware, authController.verifyPhone);
router.post('/kyc/recognize-id', authMiddleware, kycController.recognizeId);
router.post('/kyc/check-face', authMiddleware, kycController.checkFace);

// ====== Module 1: SOS ======
router.get('/sos/active', authMiddleware, sosController.getActiveByPhone);
router.get('/sos/history', authMiddleware, sosController.getHistoryByPhone);
router.post('/sos/cancel', authMiddleware, sosController.cancelCase);
router.post('/sos', authMiddleware, sosController.createSos);
router.get('/cases/nearby', sosController.getNearbyCases);
router.get('/case/:id', sosController.getCaseById);
router.get('/case/:id/tnv-location', sosController.getTnvLocation);
router.get('/case/:id/stream', sseController.streamCase);
router.get('/sse/volunteer-feed', sseController.streamVolunteerFeed);
router.post('/case/:id/accept', sosController.acceptCase);
router.get('/case/:id/my-assignment', sosController.checkMyAssignment);
router.post('/case/:id/resolve', sosController.resolveCase);
router.post('/case/:id/revoke', sosController.revokeCase);
router.post('/case/:id/confirm-route', sosController.confirmRoute);
router.get('/case/:id/messages', chatController.getMessages);
router.post('/case/:id/messages', chatController.sendMessage);

// ====== Speech-to-Text (Gemini, giữ phương ngữ) ======
router.post('/stt', authMiddleware, sttController.transcribe);

// ====== Từ điển phương ngữ (override, không DB) ======
router.get('/dialect-dict', dialectController.getDict);            // app tải về để merge
router.get('/dialect-dict/version', dialectController.getVersion); // app kiểm tra version
router.post('/dialect-dict', adminAuthMiddleware, dialectController.addTerm);      // admin thêm/sửa
router.delete('/dialect-dict', adminAuthMiddleware, dialectController.removeTerm); // admin xoá

// ====== VietMap Geo (proxy — giấu API key) ======
router.get('/geo/autocomplete', geoController.geoAutocomplete); // gợi ý địa chỉ khi gõ
router.get('/geo/place', geoController.geoPlace);               // ref_id → toạ độ
router.get('/geo/reverse', geoController.geoReverse);           // toạ độ → địa chỉ
router.get('/geo/route', geoController.geoRoute);               // tuyến đường (vẽ polyline)

// ====== Module 3: Location Tracking ======
router.post('/location', locationController.updateVolunteerLocation);

// ====== Module 3: Volunteers ======
router.post('/volunteers/register', authMiddleware, volunteerController.registerVolunteer);
router.get('/volunteers', volunteerController.listVolunteers);
router.get('/volunteers/locations', volunteerController.getVolunteerLocations);
router.put('/volunteers/:id/approve', volunteerController.approveVolunteer);
router.put('/volunteers/:id/availability', volunteerController.setAvailability);
router.put('/volunteers/:id/fcm-token', volunteerController.updateFcmToken);
router.put('/volunteers/:id/radius', volunteerController.updateNotificationRadius);
router.get('/volunteers/:volunteerId/history', sosController.getVolunteerHistory);
router.get('/volunteers/:volunteerId/active-mission', sosController.getActiveAssignment);

// ====== Module 5: Admin Dashboard (protected) ======
router.get('/admin/case-clusters', adminAuthMiddleware, adminController.getCaseClusters);
router.get('/admin/cases', adminAuthMiddleware, adminController.getAllCases);
router.get('/admin/stats', adminAuthMiddleware, adminController.getDashboardStats);


module.exports = router;
