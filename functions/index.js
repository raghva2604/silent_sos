// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
admin.initializeApp();

const SENDGRID_KEY = functions.config().sendgrid?.key || '';
if (!SENDGRID_KEY) {
  console.warn('SendGrid key missing. Set with firebase functions:config:set sendgrid.key="KEY"');
}
sgMail.setApiKey(SENDGRID_KEY);

exports.onSosEvent = functions.firestore
  .document('sos_events/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const { audio_url, video_url, location, recipients, senderUid } = data;
    if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
      console.log('No recipients, skipping email.');
      return null;
    }

    const mapsLink = location ? `https://maps.google.com/?q=${location.lat},${location.lng}` : '';
    const htmlBody = `
      <p><strong>SOS Alert</strong></p>
      <p>Sender UID: ${senderUid || 'unknown'}</p>
      <p>Location: <a href="${mapsLink}">${mapsLink}</a></p>
      ${audio_url ? `<p>Audio: <a href="${audio_url}">Download audio</a></p>` : ''}
      ${video_url ? `<p>Video: <a href="${video_url}">Download video</a></p>` : ''}
      <p>Timestamp: ${new Date().toISOString()}</p>
    `;

    const msg = {
      to: recipients,
      from: 'noreply@yourdomain.com',
      subject: 'SOS Alert — immediate help required',
      html: htmlBody,
    };

    try {
      const res = await sgMail.send(msg);
      console.log('SendGrid response:', res && res[0] && res[0].statusCode);
    } catch (err) {
      console.error('SendGrid error:', err);
    }

    await snap.ref.update({ email_sent: true }).catch(e => console.warn('update fail', e));
    return null;
  });
