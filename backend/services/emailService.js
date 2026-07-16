const nodemailer = require('nodemailer');

let transporter;

function getTransporter() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    throw new Error('SMTP is not configured');
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });

  return transporter;
}

async function sendPasswordResetOtpEmail(toEmail, otp) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  await getTransporter().sendMail({
    from,
    to: toEmail,
    subject: 'Reset your Updates account password',
    text: [
      'Your verification code is:',
      '',
      otp,
      '',
      'This code expires in 10 minutes.',
      '',
      'If you did not request this, ignore this email.',
    ].join('\n'),
  });
}

async function sendNewDeviceLoginAlert(toEmail, { deviceName, platform, ip, time }) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  await getTransporter().sendMail({
    from,
    to: [toEmail, 'isoftnix1@gmail.com'],
    subject: 'Security Alert: New Device Login',
    text: [
      'Security Alert',
      '',
      'We detected a login from a new device.',
      '',
      `Device:\n${deviceName || 'Unknown Device'}`,
      '',
      `Platform:\n${platform || 'Unknown Platform'}`,
      '',
      `IP:\n${ip || 'Unknown IP'}`,
      '',
      `Time:\n${time || 'Unknown Time'}`,
      '',
      'If this was you,',
      'no action is required.',
      '',
      'If this wasn\'t you,',
      'please change your password immediately.',
    ].join('\n'),
  });
}

async function sendUnauthorizedAdminLoginAlert(toEmail, { deviceName, platform, ip, time, reason, fingerprint }) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  await getTransporter().sendMail({
    from,
    to: [toEmail, 'isoftnix1@gmail.com'],
    subject: '🚨 Security Alert: Unauthorized Administrator Login Attempt Blocked',
    html: `
      <h2>Security Alert</h2>
      <p>An unauthorized device attempted to access the Administrator account. The login request was automatically blocked because the device is not registered in the authorized administrator hardware list.</p>
      
      <h3>Attempt Details:</h3>
      <ul>
        <li><strong>Date & Time:</strong> ${time}</li>
        <li><strong>Device:</strong> ${deviceName}</li>
        <li><strong>Platform:</strong> ${platform}</li>
        <li><strong>IP Address:</strong> ${ip}</li>
        <li><strong>Hardware Fingerprint:</strong> ${fingerprint}</li>
        <li><strong>Status:</strong> BLOCKED</li>
        <li><strong>Reason:</strong> ${reason}</li>
      </ul>
      
      <p><strong>If this was you:</strong><br/>
      Replace one of the existing administrator devices after verifying your password and Email OTP via the Admin Dashboard.</p>

      <p><strong>If this was not you:</strong><br/>
      Change your administrator password immediately.<br/>
      Review administrator security settings.<br/>
      Contact your security administrator if necessary.</p>
    `,
  });
}

async function sendCriticalAdminSecurityAlert(toEmail, attemptCount) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  await getTransporter().sendMail({
    from,
    to: [toEmail, 'isoftnix1@gmail.com'],
    subject: '🚨 CRITICAL SECURITY ALERT: Multiple Unauthorized Admin Logins',
    html: `
      <h2 style="color: red;">Critical Security Alert</h2>
      <p><strong>${attemptCount} unauthorized administrator hardware login attempts</strong> have been detected within the last 30 minutes.</p>
      <p>This may indicate a brute-force or targeted attack against your administrator account.</p>
      <p>Please review your administrator account and change your password immediately.</p>
    `,
  });
}

async function sendAdminHardwareReplacementOtp(toEmail, otp) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;

  await getTransporter().sendMail({
    from,
    to: toEmail,
    subject: 'OTP for Administrator Hardware Replacement',
    text: [
      'Your verification code to replace an administrator hardware slot is:',
      '',
      otp,
      '',
      'This code expires in 10 minutes.',
      '',
      'If you did not request this, your password may be compromised. Change it immediately.',
    ].join('\n'),
  });
}

module.exports = {
  sendPasswordResetOtpEmail,
  sendNewDeviceLoginAlert,
  sendUnauthorizedAdminLoginAlert,
  sendCriticalAdminSecurityAlert,
  sendAdminHardwareReplacementOtp,
};
