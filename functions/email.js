/**
 * Outbound email via SendGrid HTTP API.
 * Configure with Firebase secrets: SENDGRID_API_KEY, EMAIL_FROM
 */
async function sendAppEmail({ apiKey, from, to, subject, text, html }) {
  const recipient = (to || '').trim().toLowerCase();
  const sender = (from || '').trim();
  if (!apiKey || !sender || !recipient) {
    console.log('[email] Missing SENDGRID_API_KEY, EMAIL_FROM, or recipient');
    return false;
  }

  const payload = {
    personalizations: [{ to: [{ email: recipient }] }],
    from: { email: sender, name: 'Care Signal' },
    subject: (subject || 'Care Signal').trim(),
    content: [{ type: 'text/plain', value: text || '' }],
  };
  if (html) {
    payload.content.push({ type: 'text/html', value: html });
  }

  try {
    const res = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.text();
      console.error('[email] SendGrid failed', res.status, err);
      return false;
    }
    return true;
  } catch (err) {
    console.error('[email] SendGrid request error', err);
    return false;
  }
}

function peerGroupFamilyInviteEmail({ hostName, groupTitle, inviteeEmail, helpUrl }) {
  const group = groupTitle || 'a peer group';
  const host = hostName || 'A Care Signal host';
  const email = inviteeEmail || 'your email';
  const lines = [
    `${host} invited you to join the peer group "${group}" on Care Signal.`,
    '',
    `Sign in to Care Signal with ${email}, then open Support → Peer Groups to accept.`,
    '',
    "If you don't have an account yet, sign up with that same email address.",
  ];
  if (helpUrl) {
    lines.push('', `Learn more: ${helpUrl}`);
  }
  return {
    subject: `You're invited to ${group} on Care Signal`,
    text: lines.join('\n'),
  };
}

function peerGroupCoHostInviteEmail({ hostName, groupTitle, inviteeEmail, helpUrl }) {
  const group = groupTitle || 'a peer group';
  const host = hostName || 'A host';
  const lines = [
    `${host} invited you to co-host "${group}" on Care Signal.`,
    '',
    'Open the Care Signal app → Peer Groups to accept or decline.',
  ];
  if (inviteeEmail) {
    lines.splice(2, 0, `Sign in with ${inviteeEmail}.`);
  }
  if (helpUrl) {
    lines.push('', `Learn more: ${helpUrl}`);
  }
  return {
    subject: `Co-host invitation: ${group}`,
    text: lines.join('\n'),
  };
}

module.exports = {
  sendAppEmail,
  peerGroupFamilyInviteEmail,
  peerGroupCoHostInviteEmail,
};
