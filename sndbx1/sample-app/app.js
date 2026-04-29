const express = require('express');
const fetch = require('node-fetch');
const app = express();
const PORT = 3000;

// AM Configuration
const AM_INTERNAL = 'http://pingam:8080/am';   // Container-to-container (backend REST calls)
const AM_EXTERNAL = 'http://pingam:8081/am';    // Browser-accessible (redirects)
const SP_META_ALIAS = '/partner/partner-sp';
const IDP_ENTITY_ID = 'techcorp-idp';
const COOKIE_NAME = 'iPlanetDirectoryPro';
const APP_URL = 'http://localhost:3000';

app.use(express.urlencoded({ extended: true }));

// Parse AM session cookie from request
function getSessionToken(req) {
  const cookies = req.headers.cookie || '';
  const match = cookies.split(';').find(c => c.trim().startsWith(COOKIE_NAME + '='));
  return match ? decodeURIComponent(match.split('=').slice(1).join('=').trim()) : null;
}

// Validate session with AM and get user info
async function validateSession(tokenId) {
  try {
    const res = await fetch(`${AM_INTERNAL}/json/sessions?_action=getSessionInfo`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept-API-Version': 'resource=4.0',
        [COOKIE_NAME]: tokenId
      },
      body: '{}'
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (err) {
    console.error('Session validation error:', err.message);
    return null;
  }
}

// ============================================================
// LANDING PAGE - Unprotected
// ============================================================
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Partner Corp App</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; background: #f5f5f5; }
        .card { background: white; border-radius: 8px; padding: 30px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .btn { display: inline-block; padding: 12px 24px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px; font-size: 16px; }
        .btn:hover { background: #0052a3; }
        .arch { background: #1a1a2e; color: #00ff88; padding: 20px; border-radius: 4px; font-family: monospace; font-size: 13px; white-space: pre; overflow-x: auto; }
        h1 { color: #333; }
        .tag { display: inline-block; background: #e8f4e8; color: #2d7d2d; padding: 2px 8px; border-radius: 3px; font-size: 12px; }
      </style>
    </head>
    <body>
      <h1>Partner Corp - Internal App</h1>
      <div class="card">
        <h2>Welcome to Partner Corp's Application</h2>
        <p>This app does <strong>NOT</strong> handle authentication itself. It relies on
        <strong>TechCorp's Identity Provider</strong> via SAML 2.0 federation.</p>
        <p>Click below to access the protected resource. You will be redirected through:</p>
        <div class="arch">
You (Browser)
  |
  |  1. Click "Login via SAML"
  v
Partner Corp's AM (SP - /partner realm)
  |
  |  2. SP sends SAML AuthnRequest to IdP
  v
TechCorp's AM (IdP - /techcorp realm)
  |
  |  3. You log in with TechCorp credentials
  |  4. IdP creates SAML Assertion
  v
Partner Corp's AM (SP - /partner realm)
  |
  |  5. SP validates assertion
  |  6. SP creates AM session (iPlanetDirectoryPro cookie)
  v
This App (/protected)
  |
  |  7. App reads AM session cookie
  |  8. App calls AM REST API to get user info
  v
"Welcome, demo! You're authenticated via SAML federation"</div>
        <br>
        <a class="btn" href="/login">Login via SAML Federation</a>
      </div>

      <div class="card">
        <h3>Architecture: What's happening</h3>
        <p><span class="tag">Architecture 2</span> This app has <strong>no SAML support</strong>.
        PingAM (root realm) acts as the SP gateway. After federation, AM creates a session,
        and this app validates that session via AM's REST API.</p>
      </div>
    </body>
    </html>
  `);
});

// ============================================================
// LOGIN - Redirect to SP-Initiated SSO
// ============================================================
app.get('/login', (req, res) => {
  // RelayState tells AM where to redirect after successful SAML SSO
  const relayState = encodeURIComponent(`${APP_URL}/protected`);
  const ssoUrl = `${AM_EXTERNAL}/saml2/jsp/spSSOInit.jsp`
    + `?metaAlias=${SP_META_ALIAS}`
    + `&idpEntityID=${IDP_ENTITY_ID}`
    + `&binding=urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST`
    + `&RelayState=${relayState}`;

  res.redirect(ssoUrl);
});

// ============================================================
// PROTECTED PAGE - Requires valid AM session
// ============================================================
app.get('/protected', async (req, res) => {
  const tokenId = getSessionToken(req);

  // No session cookie - show manual token entry
  // (Cookie is on pingam domain, not localhost, so we need manual entry in lab)
  if (!tokenId) {
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Protected Resource - Partner Corp</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; background: #f5f5f5; }
          .card { background: white; border-radius: 8px; padding: 30px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .success { background: #e8f5e9; border-left: 4px solid #4caf50; padding: 15px; margin: 15px 0; }
          .info { background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 15px 0; }
          .btn { display: inline-block; padding: 10px 20px; background: #0066cc; color: white; border: none; border-radius: 4px; font-size: 14px; cursor: pointer; }
          input[type="text"] { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; font-family: monospace; font-size: 12px; }
          .step { background: #fff3e0; border-left: 4px solid #ff9800; padding: 10px 15px; margin: 8px 0; }
          code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; font-size: 13px; }
        </style>
      </head>
      <body>
        <h1>Protected Resource</h1>

        <div class="card">
          <div class="success">
            <strong>SAML Federation Complete!</strong><br>
            If you were redirected here after logging in, the SAML flow succeeded.
            AM (SP) received and validated the SAML assertion from the IdP.
          </div>

          <h3>Why do I need to paste a token?</h3>
          <div class="info">
            <p>In this lab, the AM session cookie (<code>iPlanetDirectoryPro</code>) was set on the
            <code>pingam</code> domain. This app runs on <code>localhost</code> - a different domain.</p>
            <p><strong>In production</strong>, this is solved by:</p>
            <ul>
              <li><strong>AM Web Agent</strong> - installed on the app server, same domain, reads cookie directly</li>
              <li><strong>PingGateway (IG)</strong> - reverse proxy in front of the app, validates session</li>
              <li><strong>Same domain</strong> - app and AM share a domain (e.g., *.example.com)</li>
            </ul>
            <p>For this lab, we simulate by pasting the token manually.</p>
          </div>

          <h3>Steps to get your token:</h3>
          <div class="step">1. Open browser DevTools (F12) → Application tab → Cookies</div>
          <div class="step">2. Look for <code>iPlanetDirectoryPro</code> cookie on the <code>pingam</code> domain</div>
          <div class="step">3. Copy the full cookie value and paste below</div>

          <form action="/protected/validate" method="POST">
            <label><strong>iPlanetDirectoryPro token:</strong></label>
            <input type="text" name="tokenId" placeholder="Paste your AM session token here..." required>
            <button type="submit" class="btn">Validate Session & Show User Info</button>
          </form>
        </div>

        <div class="card">
          <h3>Or verify directly on AM:</h3>
          <p><a href="http://pingam:8081/am/json/sessions?_action=getSessionInfo" target="_blank">
            Click here to check your session on AM</a> (works because your browser has the cookie for pingam domain)</p>
        </div>
      </body>
      </html>
    `);
    return;
  }

  // If cookie exists (same domain scenario), validate directly
  await handleValidation(tokenId, res);
});

// ============================================================
// VALIDATE - Process the pasted token
// ============================================================
app.post('/protected/validate', async (req, res) => {
  const tokenId = req.body.tokenId;
  if (!tokenId) {
    return res.redirect('/protected');
  }
  await handleValidation(tokenId.trim(), res);
});

// ============================================================
// Shared validation + display logic
// ============================================================
async function handleValidation(tokenId, res) {
  const sessionInfo = await validateSession(tokenId);

  if (!sessionInfo || !sessionInfo.username) {
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Session Invalid</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; }
          .error { background: #ffebee; border-left: 4px solid #f44336; padding: 15px; margin: 15px 0; border-radius: 4px; }
          .btn { display: inline-block; padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 4px; }
        </style>
      </head>
      <body>
        <h1>Session Invalid</h1>
        <div class="error">
          <strong>The session token is invalid or expired.</strong><br>
          This could mean the AM session has timed out or the token was incorrect.
        </div>
        <p>AM Response: <pre>${JSON.stringify(sessionInfo, null, 2)}</pre></p>
        <a class="btn" href="/login">Try Again - Login via SAML</a>
      </body>
      </html>
    `);
    return;
  }

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Welcome - Partner Corp</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; background: #f5f5f5; }
        .card { background: white; border-radius: 8px; padding: 30px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .welcome { background: #e8f5e9; border: 2px solid #4caf50; border-radius: 8px; padding: 20px; text-align: center; }
        .welcome h1 { color: #2e7d32; margin: 0; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        td { padding: 8px 12px; border-bottom: 1px solid #eee; }
        td:first-child { font-weight: bold; width: 200px; color: #555; }
        .flow { background: #1a1a2e; color: #00ff88; padding: 20px; border-radius: 4px; font-family: monospace; font-size: 13px; white-space: pre; overflow-x: auto; }
        .btn { display: inline-block; padding: 10px 20px; background: #d32f2f; color: white; text-decoration: none; border-radius: 4px; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
        .tag { display: inline-block; background: #e8f4e8; color: #2d7d2d; padding: 2px 8px; border-radius: 3px; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="welcome">
        <h1>Welcome, ${sessionInfo.username}!</h1>
        <p>You are authenticated via <strong>SAML 2.0 Federation</strong></p>
      </div>

      <div class="card">
        <h2>Session Details <span class="tag">From AM REST API</span></h2>
        <p>This app called <code>POST /am/json/sessions?_action=getSessionInfo</code> with your token:</p>
        <table>
          <tr><td>Username</td><td>${sessionInfo.username}</td></tr>
          <tr><td>Universal ID</td><td>${sessionInfo.universalId || 'N/A'}</td></tr>
          <tr><td>Realm</td><td>${sessionInfo.realm || 'N/A'}</td></tr>
          <tr><td>Session Type</td><td>${sessionInfo.sessionType || 'N/A'}</td></tr>
          <tr><td>Max Idle Time</td><td>${sessionInfo.maxIdleExpirationTime || 'N/A'}</td></tr>
          <tr><td>Max Session Time</td><td>${sessionInfo.maxSessionExpirationTime || 'N/A'}</td></tr>
        </table>
        <details>
          <summary>Full AM Response (JSON)</summary>
          <pre>${JSON.stringify(sessionInfo, null, 2)}</pre>
        </details>
      </div>

      <div class="card">
        <h2>What Just Happened (Full Flow)</h2>
        <div class="flow">
1. You clicked "Login via SAML" on this app (Partner Corp)
2. App redirected to AM SP (root realm): /saml2/jsp/spSSOInit.jsp
3. AM SP generated a SAML AuthnRequest
4. AM SP redirected your browser to AM IdP (/techcorp realm)
5. You logged in with TechCorp credentials (demo user)
6. AM IdP created a signed SAML Assertion containing:
   - NameID: ${sessionInfo.username}
   - AuthnStatement (how you authenticated)
   - Conditions (validity period, audience)
7. IdP POSTed the assertion to SP's ACS endpoint
8. AM SP validated the assertion:
   - Checked XML signature (IdP's certificate)
   - Checked conditions (time, audience)
   - Extracted NameID
9. AM SP created a local session (iPlanetDirectoryPro cookie)
10. AM SP redirected you here (RelayState URL)
11. This app validated your session via AM REST API
12. You see this page!</div>
      </div>

      <div class="card">
        <h2>Interview Insight</h2>
        <p><strong>Q: How does a custom app work with SAML federation?</strong></p>
        <p>"The custom app doesn't handle SAML at all. PingAM acts as the SP gateway -
        it receives the SAML assertion, validates the signature, checks conditions,
        and creates a local AM session. The app then validates that session using AM's
        REST API or through a Web Agent/PingGateway that sits in front of the app.
        This is Architecture 2 - AM as SP proxy for apps with no native SAML support."</p>
      </div>

      <a class="btn" href="http://pingam:8081/am/UI/Logout">Logout (Destroy AM Session)</a>
    </body>
    </html>
  `);
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Partner Corp Sample App running on port ${PORT}`);
  console.log(`Open http://localhost:${PORT} in your browser`);
});
