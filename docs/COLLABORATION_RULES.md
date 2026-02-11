# AI Collaboration Rules (全局工作规范)

## 1. Zero-Waste Execution Protocol (代码修改零浪费原则)

### 🔴 The "Bad Habit" (Core Anti-Pattern)
- **Do NOT** start writing or modifying code immediately after a plan is proposed, even if the user says "Let's do X and Y".
- **Context**: The user may still be brainstorming or asking for advice ("What do you think?"). Premature coding wastes tokens and creates "garbage code" if the user changes their mind.

### ✅ The Required Workflow
1.  **Draft/Propose**: AI proposes a plan or confirms understanding of the user's intent.
2.  **Explicit Confirmation**: AI MUST ask: **"Ready to execute?"** (or similar).
3.  **Wait**: Only proceed to `write_to_file` or `replace_file_content` after the user gives a clear "Go", "Do it", or "Yes".

---

## 2. Skill Security Protocol (技能安全原则)
- **Read-Rewrite-Verify**: Never run external skills blindly.
    1.  Read the code.
    2.  Understand logic.
    3.  Scanner check (`skill-scanner`).
    4.  Rewrite clean version without blobs.
- **Scanner Integration**: `cisco-ai-defense/skill-scanner` is a trusted tool and mandatory for new imports.

---

*Verified by User on*: 2026-02-11
*Status*: Active - Highest Priority
