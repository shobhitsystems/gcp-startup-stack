const http    = require('http');
const os      = require('os');

const PORT     = process.env.PORT     || 8080;
const ENV      = process.env.ENV      || 'unknown';
const PROJECT  = process.env.PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || 'unknown';
const REVISION = process.env.K_REVISION || 'local';
const start    = Date.now();

// Secrets are injected as env vars by Cloud Run from Secret Manager
// No .env files, no hardcoded values
const DB_PASSWORD = process.env.DB_PASSWORD || '(not set)';
const API_KEY     = process.env.API_KEY     || '(not set)';

const mask = (s) => s.length > 6
  ? s.substring(0, 4) + '*'.repeat(s.length - 4)
  : '****';

function html(content) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Shobhit Systems — GCP Startup Stack Demo</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: system-ui, -apple-system, sans-serif;
      background: #f9fafb;
      color: #111827;
      min-height: 100vh;
    }
    .header {
      background: #fff;
      border-bottom: 1px solid #e5e7eb;
      padding: 1rem 2rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .logo { font-weight: 700; font-size: 1rem; color: #111; }
    .logo span { color: #2563eb; }
    .badge {
      background: #d1fae5; color: #065f46;
      font-size: .7rem; font-weight: 700;
      padding: 2px 10px; border-radius: 99px;
      text-transform: uppercase; letter-spacing: .04em;
    }
    .main { max-width: 800px; margin: 2.5rem auto; padding: 0 1.5rem; }
    h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: .25rem; }
    .subtitle { color: #6b7280; font-size: .95rem; margin-bottom: 2rem; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 2rem; }
    @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
    .card {
      background: #fff;
      border: 1px solid #e5e7eb;
      border-radius: 10px;
      padding: 1.1rem 1.25rem;
    }
    .card-label {
      font-size: .72rem; font-weight: 700;
      color: #9ca3af; text-transform: uppercase;
      letter-spacing: .06em; margin-bottom: .35rem;
    }
    .card-value { font-family: monospace; font-size: .9rem; color: #111; word-break: break-all; }
    .card-value.green { color: #059669; }
    .card-value.blue  { color: #2563eb; }
    .stack-row {
      background: #fff;
      border: 1px solid #e5e7eb;
      border-radius: 10px;
      padding: 1rem 1.25rem;
      margin-bottom: 1rem;
    }
    .stack-title { font-weight: 600; font-size: .95rem; margin-bottom: .5rem; }
    .stack-item {
      display: flex; align-items: center; gap: .6rem;
      font-size: .85rem; color: #374151;
      padding: .25rem 0;
      border-top: 1px solid #f3f4f6;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #10b981; flex-shrink: 0; }
    .links { display: flex; gap: 1rem; flex-wrap: wrap; margin-top: 1.5rem; }
    .link {
      color: #2563eb; text-decoration: none; font-size: .875rem;
      border: 1px solid #bfdbfe; border-radius: 6px;
      padding: .35rem .8rem;
    }
    .link:hover { background: #eff6ff; }
    .footer {
      margin-top: 3rem; padding: 1.5rem;
      text-align: center;
      font-size: .8rem; color: #9ca3af;
      border-top: 1px solid #e5e7eb;
    }
    .footer a { color: #2563eb; text-decoration: none; }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo">Shobhit <span>Systems</span></div>
    <span class="badge">live demo</span>
  </div>

  <div class="main">
    <h1>GCP Startup Stack</h1>
    <p class="subtitle">
      Complete production infrastructure deployed with a single <code>terraform apply</code>.
      Everything below is live — not mocked.
    </p>

    <div class="grid">
      <div class="card">
        <div class="card-label">Environment</div>
        <div class="card-value green">${ENV}</div>
      </div>
      <div class="card">
        <div class="card-label">Cloud Run revision</div>
        <div class="card-value blue">${REVISION}</div>
      </div>
      <div class="card">
        <div class="card-label">GCP project</div>
        <div class="card-value">${PROJECT}</div>
      </div>
      <div class="card">
        <div class="card-label">Uptime</div>
        <div class="card-value">${Math.floor((Date.now() - start) / 1000)}s</div>
      </div>
      <div class="card">
        <div class="card-label">DB password (from Secret Manager)</div>
        <div class="card-value">${mask(DB_PASSWORD)}</div>
      </div>
      <div class="card">
        <div class="card-label">API key (from Secret Manager)</div>
        <div class="card-value">${mask(API_KEY)}</div>
      </div>
    </div>

    <div class="stack-row">
      <div class="stack-title">What was deployed by terraform apply</div>
      <div class="stack-item"><span class="dot"></span>Custom VPC — private subnet, Cloud NAT, no public IPs on resources</div>
      <div class="stack-item"><span class="dot"></span>Cloud Run — this service, auto-scales 0→10, secrets injected at runtime</div>
      <div class="stack-item"><span class="dot"></span>Cloud SQL PostgreSQL — private IP only, automated backups, PITR enabled</div>
      <div class="stack-item"><span class="dot"></span>Artifact Registry — Docker images with cleanup policies (keep last 10)</div>
      <div class="stack-item"><span class="dot"></span>Secret Manager — DB password + API key, auto-rotation configured</div>
      <div class="stack-item"><span class="dot"></span>IAM — 3 least-privilege service accounts (app, deployer, terraform)</div>
      <div class="stack-item"><span class="dot"></span>Workload Identity Federation — GitHub Actions, zero stored keys</div>
      <div class="stack-item"><span class="dot"></span>Cloud Build trigger — push to main → test → scan → deploy → smoke test</div>
      <div class="stack-item"><span class="dot"></span>Budget alerts — 50%, 80%, 100% spend threshold notifications</div>
    </div>

    <div class="links">
      <a class="link" href="/health">Health check</a>
      <a class="link" href="/info">Full JSON info</a>
      <a class="link" href="https://shobhitsystems.com">Shobhit Systems</a>
    </div>
  </div>

  <div class="footer">
    Built by <a href="https://shobhitsystems.com">Shobhit Systems</a> —
    GCP consulting for startups and small companies ·
    <a href="mailto:hello@shobhitsystems.com">hello@shobhitsystems.com</a>
  </div>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', uptime_sec: Math.floor((Date.now() - start) / 1000) }));
  }

  if (req.url === '/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      env:             ENV,
      project:         PROJECT,
      revision:        REVISION,
      hostname:        os.hostname(),
      uptime_sec:      Math.floor((Date.now() - start) / 1000),
      node_version:    process.version,
      db_password_set: DB_PASSWORD !== '(not set)',
      api_key_set:     API_KEY !== '(not set)',
      secrets_source:  'Google Cloud Secret Manager — injected by Cloud Run at startup',
      stack: [
        'VPC (private subnet + Cloud NAT)',
        'Cloud Run (this service)',
        'Cloud SQL PostgreSQL (private IP only)',
        'Artifact Registry',
        'Secret Manager',
        'IAM (3 least-privilege SAs)',
        'Workload Identity Federation',
        'Cloud Build trigger',
        'Budget alerts',
      ],
    }));
  }

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(html(`<!-- ${REVISION} -->`));
});

server.listen(PORT, () => {
  console.log(`Startup stack demo on :${PORT} | env=${ENV} | project=${PROJECT} | revision=${REVISION}`);
  console.log(`DB password set: ${DB_PASSWORD !== '(not set)'}`);
  console.log(`API key set:     ${API_KEY !== '(not set)'}`);
});
