import fs from "fs";
import path from "path";

// ============================================
// GitHub Issue Creator (生产级)
// 功能: 自动标签、重复检测、退避重试、参数化仓库
// ============================================

// 解析命令行参数
const titleDraft = process.argv[2];
const bodyDraft = process.argv[3] || "No description provided.";

if (!titleDraft) {
  console.error('Usage: node create_issue.mjs "<title>" "[body]"');
  process.exit(1);
}

if (!process.env.GITHUB_TOKEN) {
  console.error("❌ Error: GITHUB_TOKEN 环境变量未设置。");
  console.error("请在 Zeabur 控制台或本地 .env 中配置 GITHUB_TOKEN。");
  process.exit(1);
}

// 仓库配置（支持环境变量覆盖）
const REPO = process.env.GITHUB_REPO || "wemkt168/openclaw";
const [OWNER, REPO_NAME] = REPO.split("/");
const API_BASE = `https://api.github.com/repos/${OWNER}/${REPO_NAME}`;
const AUTO_LABEL = "teddy-auto";
const MAX_RETRIES = 3;
const DRY_RUN = process.env.DRY_RUN === "1";

// 公共请求头
const headers = {
  Accept: "application/vnd.github+json",
  Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
  "X-GitHub-Api-Version": "2022-11-28",
  "Content-Type": "application/json",
  "User-Agent": "Teddy-Auto-Issue-Creator",
};

// ============================================
// 1. 生成时间戳 ID
// ============================================
const now = new Date();
const yyyy = now.getFullYear();
const mm = String(now.getMonth() + 1).padStart(2, "0");
const dd = String(now.getDate()).padStart(2, "0");
const dateStr = `${yyyy}${mm}${dd}`;

// 本地草稿目录
const draftsDir = path.join(process.cwd(), "teddy-core-config", "issue_drafts");
if (!fs.existsSync(draftsDir)) {
  fs.mkdirSync(draftsDir, { recursive: true });
}

// 序列号逻辑
const files = fs.readdirSync(draftsDir);
let count = 0;
for (const file of files) {
  if (file.startsWith(`[${dateStr}`)) {
    count++;
  }
}

const seqNum = count === 0 ? "" : `-${count + 1}`;
const idStr = `${dateStr}${seqNum}`;
const issueTitle = `[${idStr}] ${titleDraft}`;

// ============================================
// 2. 带退避的重试请求
// ============================================
async function fetchWithRetry(url, options, retries = MAX_RETRIES) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options);
      return response;
    } catch (error) {
      if (attempt === retries) {
        throw error;
      }
      const backoffMs = Math.min(1000 * Math.pow(2, attempt - 1), 8000);
      console.warn(`⚠️ 网络请求失败 (第 ${attempt}/${retries} 次)，${backoffMs}ms 后重试...`);
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }
}

// ============================================
// 3. 重复检测：搜索同标题 Issue
// ============================================
async function checkDuplicate(title) {
  console.log("🔍 检查是否存在重复 Issue...");
  try {
    const query = encodeURIComponent(
      `repo:${OWNER}/${REPO_NAME} is:issue "${titleDraft}" in:title`,
    );
    const response = await fetchWithRetry(
      `https://api.github.com/search/issues?q=${query}&per_page=5`,
      { method: "GET", headers },
    );

    if (response.ok) {
      const data = await response.json();
      if (data.total_count > 0) {
        // 精确匹配标题（包含原始 titleDraft 的部分）
        const exactMatch = data.items.find((item) => item.title.includes(titleDraft));
        if (exactMatch) {
          console.warn(`⚠️ 发现疑似重复 Issue: #${exactMatch.number} "${exactMatch.title}"`);
          console.warn(`   URL: ${exactMatch.html_url}`);
          return exactMatch;
        }
      }
    }
  } catch (error) {
    // 重复检测失败不应阻止创建，仅警告
    console.warn(`⚠️ 重复检测失败（不影响创建）: ${error.message}`);
  }
  console.log("✅ 未发现重复 Issue。");
  return null;
}

// ============================================
// 4. 确保标签存在
// ============================================
async function ensureLabel() {
  try {
    const response = await fetchWithRetry(`${API_BASE}/labels/${AUTO_LABEL}`, {
      method: "GET",
      headers,
    });
    if (response.status === 404) {
      console.log(`📌 正在创建标签 "${AUTO_LABEL}"...`);
      const createResp = await fetchWithRetry(`${API_BASE}/labels`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          name: AUTO_LABEL,
          color: "d876e3",
          description: "Automatically created by Teddy AI agent",
        }),
      });
      if (createResp.ok) {
        console.log(`✅ 标签 "${AUTO_LABEL}" 创建成功。`);
      } else {
        console.warn(`⚠️ 标签创建失败 (${createResp.status})，Issue 将不带标签。`);
        return false;
      }
    }
  } catch (error) {
    console.warn(`⚠️ 标签检查失败: ${error.message}`);
    return false;
  }
  return true;
}

// ============================================
// 5. 主流程
// ============================================
async function main() {
  // 5.1 写入本地草稿
  const safeTitle = issueTitle.replace(/[<>:"/\\|?*]/g, "_");
  const filename = path.join(draftsDir, `${safeTitle}.md`);
  fs.writeFileSync(filename, bodyDraft, "utf8");
  console.log(`📝 本地草稿已创建: ${filename}`);

  // 5.2 DRY_RUN 模式
  if (DRY_RUN) {
    console.log("🏜️ DRY_RUN 模式 - 跳过 GitHub API 调用。");
    console.log(`   标题: ${issueTitle}`);
    console.log(`   仓库: ${OWNER}/${REPO_NAME}`);
    console.log(`   标签: ${AUTO_LABEL}`);
    process.exit(0);
  }

  // 5.3 重复检测
  const duplicate = await checkDuplicate(titleDraft);
  if (duplicate) {
    console.log("⏭️ 已存在相同 Issue，跳过创建。");
    console.log(`   现有 Issue URL: ${duplicate.html_url}`);
    process.exit(0);
  }

  // 5.4 确保标签存在
  const labelReady = await ensureLabel();

  // 5.5 创建 Issue
  console.log(`🚀 正在创建 GitHub Issue: ${issueTitle}`);
  try {
    const response = await fetchWithRetry(`${API_BASE}/issues`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        title: issueTitle,
        body: bodyDraft,
        labels: labelReady ? [AUTO_LABEL] : [],
      }),
    });

    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Issue 创建成功！`);
      console.log(`   URL: ${data.html_url}`);
      console.log(`   编号: #${data.number}`);
    } else {
      const err = await response.text();
      console.error(`❌ 创建失败: ${response.status} ${response.statusText}`);
      console.error(err);
      process.exit(1);
    }
  } catch (error) {
    console.error(`❌ 请求失败 (已重试 ${MAX_RETRIES} 次): ${error.message}`);
    process.exit(1);
  }
}

main();
