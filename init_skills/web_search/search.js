#!/usr/bin/env node
// web_search —— 调用 Brave Search API 获取精简搜索结果
// 用法: node search.js "搜索词"

require("dotenv").config({ path: "/home/node/.openclaw/.env" });

const API_KEY = process.env.BRAVE_SEARCH_API_KEY;
if (!API_KEY) {
  console.error("❌ 缺少 BRAVE_SEARCH_API_KEY，请在 /home/node/.openclaw/.env 中配置。");
  process.exit(1);
}

const query = process.argv[2];
if (!query) {
  console.error("用法: node search.js \"搜索词\"");
  process.exit(1);
}

const url = `https://api.search.brave.com/res/v1/web/search?q=${encodeURIComponent(query)}&count=5`;

fetch(url, {
  headers: {
    "Accept": "application/json",
    "Accept-Encoding": "gzip",
    "X-Subscription-Token": API_KEY,
  },
})
  .then((res) => {
    if (!res.ok) {
      return res.text().then((body) => {
        console.error(`❌ Brave API 返回 ${res.status}: ${body}`);
        process.exit(1);
      });
    }
    return res.json();
  })
  .then((data) => {
    const results = (data.web && data.web.results) || [];
    const output = results.map((r) => ({
      title: r.title,
      url: r.url,
      snippet: r.description,
    }));
    console.log(JSON.stringify(output, null, 2));
  })
  .catch((err) => {
    console.error("❌ 请求失败:", err.message);
    process.exit(1);
  });
