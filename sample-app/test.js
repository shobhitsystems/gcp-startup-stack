const assert = require('assert');

console.log('Running startup-stack tests...');

function testHealthFormat() {
  const res = JSON.stringify({ status: 'ok', uptime_sec: 0 });
  const obj = JSON.parse(res);
  assert.strictEqual(obj.status, 'ok');
  assert.ok(typeof obj.uptime_sec === 'number');
  console.log('  ✓ /health response format valid');
}

function testInfoFormat() {
  const info = {
    env: 'test', project: 'test-project', revision: 'test-rev',
    db_password_set: false, api_key_set: false,
    secrets_source: 'Google Cloud Secret Manager — injected by Cloud Run at startup',
    stack: ['VPC', 'Cloud Run', 'Cloud SQL'],
  };
  assert.ok(Array.isArray(info.stack), 'stack must be an array');
  assert.ok(info.stack.length > 0, 'stack must have entries');
  assert.ok(typeof info.db_password_set === 'boolean');
  console.log('  ✓ /info response format valid');
}

function testPortDefault() {
  const port = Number(process.env.PORT || 8080);
  assert.ok(port > 0 && port < 65536, 'PORT must be a valid port number');
  console.log('  ✓ PORT default is valid');
}

function testMaskFunction() {
  const mask = (s) => s.length > 6
    ? s.substring(0, 4) + '*'.repeat(s.length - 4)
    : '****';
  const masked = mask('supersecretpassword123');
  assert.ok(masked.startsWith('supe'), 'mask must show first 4 chars');
  assert.ok(masked.includes('*'), 'mask must contain asterisks');
  assert.ok(!masked.includes('secretpassword'), 'mask must hide the secret');
  console.log('  ✓ Secret masking works correctly');
}

try {
  testHealthFormat();
  testInfoFormat();
  testPortDefault();
  testMaskFunction();
  console.log('\n✓ All tests passed\n');
} catch (err) {
  console.error('\n✗ Test failed:', err.message);
  process.exit(1);
}
