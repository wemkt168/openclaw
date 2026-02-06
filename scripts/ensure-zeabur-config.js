/**
 * scripts/ensure-zeabur-config.js
 * 
 * This script runs at container startup to ensure the OpenClaw configuration
 * in the persistent volume is compatible with the Zeabur environment.
 * 
 * It enforces:
 * 1. gateway.controlUi.allowInsecureAuth = true (to bypass pairing loop)
 * 2. gateway.trustedProxies includes Zeabur internal private IP ranges
 * 
 * Usage: node scripts/ensure-zeabur-config.js
 */

import fs from 'node:fs';
import path from 'node:path';
import JSON5 from 'json5';

const CONFIG_DIR = '/home/node/.openclaw';
const CONFIG_FILE = path.join(CONFIG_DIR, 'openclaw.json');
const DEFAULT_CONFIG = '/app/openclaw.defaults.json';

// Ensure config dir exists
if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
}

// 1. Initialize from defaults if missing
if (!fs.existsSync(CONFIG_FILE)) {
    console.log('[Zeabur] Config file missing. Initializing from defaults...');
    if (fs.existsSync(DEFAULT_CONFIG)) {
        fs.copyFileSync(DEFAULT_CONFIG, CONFIG_FILE);
    } else {
        // Fallback minimal config if default file missing
        const minimal = {
            gateway: {
                bind: 'lan',
                port: 8080
            }
        };
        fs.writeFileSync(CONFIG_FILE, JSON5.stringify(minimal, null, 2));
    }
}

// 2. Read and Patch Config
try {
    console.log('[Zeabur] Checking configuration...');
    const content = fs.readFileSync(CONFIG_FILE, 'utf8');
    const config = JSON5.parse(content);

    let modified = false;

    // Ensure gateway object exists
    config.gateway = config.gateway || {};
    config.gateway.controlUi = config.gateway.controlUi || {};

    // Enforce Allow Insecure Auth
    if (config.gateway.controlUi.allowInsecureAuth !== true) {
        console.log('[Zeabur] Enforcing allowInsecureAuth = true');
        config.gateway.controlUi.allowInsecureAuth = true;
        modified = true;
    }

    // Enforce Trusted Proxies
    config.gateway.trustedProxies = config.gateway.trustedProxies || [];
    const requiredProxies = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"];

    // Merge if missing
    const currentProxies = new Set(config.gateway.trustedProxies);
    let proxyAdded = false;
    for (const proxy of requiredProxies) {
        if (!currentProxies.has(proxy)) {
            config.gateway.trustedProxies.push(proxy);
            proxyAdded = true;
        }
    }

    if (proxyAdded) {
        console.log('[Zeabur] Updated trustedProxies');
        modified = true;
    }

    // 3. Write back if modified
    if (modified) {
        console.log('[Zeabur] Writing patched configuration...');
        // Use JSON5 stringify if available, but standard JSON stringify is safer/compatible
        // OpenClaw can read standard JSON finely.
        // Using standard JSON.stringify to ensure no weird formatting issues, 
        // although it strips comments. In production machine generated config, comments are less critical.
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
        console.log('[Zeabur] Configuration patched successfully.');
    } else {
        console.log('[Zeabur] Configuration is already correct.');
    }

} catch (err) {
    console.error('[Zeabur] Error patching configuration:', err);
    // Do not exit with error, let OpenClaw try to start anyway (it might fail validation but better than crash loop here)
}
