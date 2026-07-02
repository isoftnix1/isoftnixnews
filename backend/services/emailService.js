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

module.exports = {
  sendPasswordResetOtpEmail,
};
