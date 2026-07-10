const express = require('express');
const { getHardwareSlots, requestHardwareReplacement, replaceHardwareSlot, getPendingDevices, authorizePendingDevice, rejectPendingDevice } = require('../controllers/adminHardwareController');
const { authMiddleware, roleMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

// Require both authentication and 'admin' role
router.use(authMiddleware);
router.use(roleMiddleware(['admin']));

router.get('/hardware-lock', getHardwareSlots);
router.post('/hardware-lock/request-otp', requestHardwareReplacement);
router.post('/hardware-lock/replace', replaceHardwareSlot);

router.get('/hardware-lock/pending', getPendingDevices);
router.post('/hardware-lock/authorize-pending', authorizePendingDevice);
router.delete('/hardware-lock/pending/:id', rejectPendingDevice);

module.exports = router;
