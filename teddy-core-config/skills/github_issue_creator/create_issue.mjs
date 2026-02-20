import fs from 'fs';
import path from 'path';

// Parse args
const titleDraft = process.argv[2];
const bodyDraft = process.argv[3] || "No description provided.";

if (!titleDraft) {
    console.error("Usage: node create_issue.mjs \"<title>\" \"[body]\"");
    process.exit(1);
}

if (!process.env.GITHUB_TOKEN) {
    console.error("Error: GITHUB_TOKEN environment variable is not set.");
    process.exit(1);
}

// 1. Date format YYYYMMDD
const now = new Date();
const yyyy = now.getFullYear();
const mm = String(now.getMonth() + 1).padStart(2, '0');
const dd = String(now.getDate()).padStart(2, '0');
const dateStr = `${yyyy}${mm}${dd}`;

// 2. Drafts directory logic
const draftsDir = path.join(process.cwd(), 'teddy-core-config', 'issue_drafts');
if (!fs.existsSync(draftsDir)) {
    fs.mkdirSync(draftsDir, { recursive: true });
}

// 3. Determine Sequence Number
const files = fs.readdirSync(draftsDir);
let count = 0;
// Look for files starting with the date string in bracket format
for (const file of files) {
    if (file.startsWith(`[${dateStr}`)) {
        count++;
    }
}

const seqNum = count === 0 ? "" : `-${count + 1}`;
const idStr = `${dateStr}${seqNum}`;

// 4. Format Title & Title Safe for File
// Force the required format: "[YYYYMMDD] or [YYYYMMDD-N] Short description"
const issueTitle = `[${idStr}] ${titleDraft}`;

// Naming requirement: filename formatted as "[ID] Short description"
const safeTitle = issueTitle.replace(/[<>:"/\\|?*]/g, '_');
const filename = path.join(draftsDir, `${safeTitle}.md`);

// 5. write to local draft
fs.writeFileSync(filename, bodyDraft, 'utf8');
console.log(`Local draft created: ${filename}`);

// 6. Send to GitHub API
async function createIssue() {
    console.log(`Creating GitHub issue: ${issueTitle}`);
    try {
        const response = await fetch('https://api.github.com/repos/wemkt168/openclaw/issues', {
            method: 'POST',
            headers: {
                'Accept': 'application/vnd.github+json',
                'Authorization': `Bearer ${process.env.GITHUB_TOKEN}`,
                'X-GitHub-Api-Version': '2022-11-28',
                'Content-Type': 'application/json',
                'User-Agent': 'Teddy-Auto-Issue-Creator'
            },
            body: JSON.stringify({
                title: issueTitle,
                body: bodyDraft
            })
        });

        if (response.ok) {
            const data = await response.json();
            console.log(`✅ Issue successfully created! URL: ${data.html_url}`);
        } else {
            const err = await response.text();
            console.error(`❌ Failed to create issue: ${response.status} ${response.statusText}`);
            console.error(err);
            process.exit(1); // Indicate failure
        }
    } catch (error) {
        console.error(`❌ Fetch error: ${error.message}`);
        process.exit(1);
    }
}

createIssue();
