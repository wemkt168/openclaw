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

import JSON5 from "json5";
import fs from "node:fs";
import path from "node:path";

const CONFIG_DIR = "/home/node/.openclaw";
const CONFIG_FILE = path.join(CONFIG_DIR, "openclaw.json");
const DEFAULT_CONFIG = "/app/openclaw.defaults.json";

// Ensure config dir exists
if (!fs.existsSync(CONFIG_DIR)) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
}

// 1. Initialize from defaults if missing
if (!fs.existsSync(CONFIG_FILE)) {
  console.log("[Zeabur] Config file missing. Initializing from defaults...");
  if (fs.existsSync(DEFAULT_CONFIG)) {
    fs.copyFileSync(DEFAULT_CONFIG, CONFIG_FILE);
  } else {
    // Fallback minimal config if default file missing
    const minimal = {
      gateway: {
        bind: "lan",
        port: 8080,
      },
    };
    fs.writeFileSync(CONFIG_FILE, JSON5.stringify(minimal, null, 2));
  }
}

// 2. Read and Patch Config
try {
  console.log("[Zeabur] Checking configuration...");
  const content = fs.readFileSync(CONFIG_FILE, "utf8");
  const config = JSON5.parse(content);
  let modified = false;

  // =====================================================================
  // 🛡️ 階段 1：藍圖基底修復 (借鑒 anti 的概念，但改用安全的深層次屬性拷貝)
  // =====================================================================
  config.gateway = config.gateway || {};

  if (fs.existsSync(DEFAULT_CONFIG)) {
    try {
      const defaultContent = fs.readFileSync(DEFAULT_CONFIG, "utf8");
      const defaultConfig = JSON5.parse(defaultContent);

      if (defaultConfig.gateway) {
        // 安全地補齊第一層缺失的物件，防止淺拷貝碾壓
        config.gateway.controlUi =
          config.gateway.controlUi || defaultConfig.gateway.controlUi || {};
        config.gateway.auth = config.gateway.auth || defaultConfig.gateway.auth || {};
        config.gateway.trustedProxies =
          config.gateway.trustedProxies || defaultConfig.gateway.trustedProxies || [];
        // 如果舊設定連 bind/port 都沒有，先拿藍圖的來墊底
        config.gateway.bind = config.gateway.bind || defaultConfig.gateway.bind;
        config.gateway.port = config.gateway.port || defaultConfig.gateway.port;
      }
    } catch (err) {
      console.error("[Zeabur] 🚨 Error reading default config for merge:", err.message);
    }
  }

  // =====================================================================
  // ⚔️ 階段 2：絕對強制覆寫 (我的防禦邏輯，確保 Zeabur 環境存活)
  // =====================================================================

  // 🛡️ 終極安全氣囊 (確保所有子物件絕對存在，防範階段 1 合併失效)
  config.gateway.controlUi = config.gateway.controlUi || {};
  config.gateway.auth = config.gateway.auth || {};
  config.gateway.trustedProxies = config.gateway.trustedProxies || [];

  // 1. 強制設定 Insecure Auth (Zeabur 反向代理內部必須)
  if (config.gateway.controlUi.allowInsecureAuth !== true) {
    config.gateway.controlUi.allowInsecureAuth = true;
    modified = true;
  }

  // 2. 智能金鑰注入 (解決 anti 漏掉的金鑰輪替問題)
  const envToken = process.env.OPENCLAW_GATEWAY_TOKEN;
  if (!config.gateway.auth.token || config.gateway.auth.token === "${OPENCLAW_GATEWAY_TOKEN}") {
    if (envToken) {
      console.log("[Zeabur] Injecting OPENCLAW_GATEWAY_TOKEN from environment.");
      config.gateway.auth.token = envToken;
      config.gateway.auth.mode = "token";
      modified = true;
    } else {
      console.error("[Zeabur] 🚨 WARNING: OPENCLAW_GATEWAY_TOKEN env variable is missing!");
    }
  } else if (envToken && config.gateway.auth.token !== envToken) {
    // [關鍵防呆]：如果使用者在 Zeabur 後台改了環境變數密碼，這裡會自動同步更新舊大腦！
    console.log("[Zeabur] Updating OPENCLAW_GATEWAY_TOKEN to match new environment variable.");
    config.gateway.auth.token = envToken;
    modified = true;
  }

  // 3. 強制注入信任代理 (確保不會被防火牆擋住)
  config.gateway.trustedProxies = config.gateway.trustedProxies || [];
  const requiredProxies = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"];
  for (const proxy of requiredProxies) {
    if (!config.gateway.trustedProxies.includes(proxy)) {
      config.gateway.trustedProxies.push(proxy);
      modified = true;
    }
  }

  // 4. 強制綁定 IP 和 Port (解決 anti 盲目尊重舊設定導致 502 Bad Gateway 的問題)
  if (config.gateway.bind !== "lan" && config.gateway.bind !== "0.0.0.0") {
    config.gateway.bind = "lan";
    modified = true;
  }
  if (config.gateway.port !== 8080) {
    config.gateway.port = 8080;
    modified = true;
  }

  // =====================================================================
  // 💾 階段 3：寫回持久化大腦
  // =====================================================================
  if (modified) {
    console.log("[Zeabur] Writing patched configuration...");
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
    console.log("[Zeabur] ✅ Configuration patched successfully.");
  } else {
    console.log("[Zeabur] Configuration is already up-to-date.");
  }
} catch (err) {
  console.error("[Zeabur] 🚨 Fatal error patching configuration:", err);
  console.error("[Zeabur] Stack trace:", err.stack);
  // Do not exit with error, let OpenClaw try to start anyway (it might fail validation but better than crash loop here)
}
