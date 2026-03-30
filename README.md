# 东审

## 🧠 项目简介

dongshen 是一个用于管理和沉淀 AI 开发能力的配置仓库，主要包含：

- SubAgent（子代理）
- Skills（技能模块）
- Rules（规则约束）

用于提升 AI（如 Cursor / LLM）在实际开发中的稳定性、一致性与工程化能力。

---

## 🎯 设计目标

- 📌 统一 AI 行为规范（Rules）
- 🧩 模块化 AI 能力（Skills）
- 🤖 构建可复用的 Agent 体系（SubAgents）
- 🚀 提升开发效率与代码质量

---

## 📂 目录结构

```bash
.
├── cursor/            # Cursor 相关配置
│   ├── subagents/     # 子代理定义
│   ├── skills/        # 技能模块
│   ├── rules/         # 行为规则
│
├── claude/              # claude（可扩展）
└── README.md
