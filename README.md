# Mnemo

> 让 AI 拥有记忆 - AI Memory System for Claude Code

[![Release](https://img.shields.io/github/v/release/icyyaww/mnemo-releases)](https://github.com/icyyaww/mnemo-releases/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Mnemo 是一个为 Claude Code 设计的**语义记忆系统**，自动记录所有对话内容，让 AI 能够在新会话中检索历史上下文。

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| **跨会话记忆** | 历史对话自动存储，新会话可检索 |
| **语义检索** | 基于意图理解，不是简单关键词匹配 |
| **隐私优先** | 本地部署，数据不出你的电脑 |
| **零侵入** | 自动同步，无需改变使用习惯 |

## 📦 支持平台

| 平台 | 架构 | 文件 |
|------|------|------|
| Linux | x86_64 | `mnemo-linux-amd64.tar.gz` |
| macOS | Intel | `mnemo-darwin-amd64.tar.gz` |
| macOS | Apple Silicon (M1/M2/M3/M4) | `mnemo-darwin-arm64.tar.gz` |
| Windows | x86_64 | `mnemo-windows-amd64.zip` |

---

## 🚀 快速安装

### Linux / macOS（一键安装）

```bash
curl -fsSL https://raw.githubusercontent.com/icyyaww/mnemo-releases/main/install.sh | bash
```

这个命令会自动：
- ✅ 检测系统和架构
- ✅ 安装 Ollama（如果没有）
- ✅ 下载 embedding 模型（nomic-embed-text）
- ✅ 下载并安装 Mnemo
- ✅ 配置 Claude Code MCP
- ✅ 创建启动/停止脚本

### Windows（PowerShell）

**步骤 1：安装 Ollama**

1. 访问 https://ollama.com/download/windows
2. 下载并运行安装程序
3. 安装完成后，打开 PowerShell 运行：
   ```powershell
   ollama pull nomic-embed-text
   ```

**步骤 2：安装 Mnemo**

```powershell
irm https://raw.githubusercontent.com/icyyaww/mnemo-releases/main/install.ps1 | iex
```

---

## 📖 手动安装

如果自动安装失败，可以手动安装：

### 1. 安装依赖

**必需：**
- Python 3.8+
- Node.js 18+
- Ollama

**安装 Ollama：**

```bash
# Linux / macOS
curl -fsSL https://ollama.com/install.sh | sh

# Windows: 从 https://ollama.com/download/windows 下载安装
```

**下载 embedding 模型：**

```bash
ollama pull nomic-embed-text
```

### 2. 下载 Mnemo

从 [Releases](https://github.com/icyyaww/mnemo-releases/releases) 页面下载对应平台的压缩包。

```bash
# Linux 示例
wget https://github.com/icyyaww/mnemo-releases/releases/latest/download/mnemo-linux-amd64.tar.gz
tar -xzf mnemo-linux-amd64.tar.gz
cd mnemo-*
```

### 3. 安装 Python 依赖

```bash
pip install watchdog requests openai
```

### 4. 安装 MCP 依赖

```bash
cd mnemo-mcp
npm install
```

### 5. 配置 Claude Code MCP

```bash
claude mcp add mnemo -s user -- node /path/to/mnemo-mcp/dist/index.js
```

---

## 🎮 使用方法

### 启动 / 停止

**Linux / macOS：**

```bash
# 启动记忆系统
mnemo-start

# 停止记忆系统
mnemo-stop
```

**Windows：**

```batch
# 启动
start-memory.bat

# 停止
stop-memory.bat
```

### 验证服务状态

```bash
# 健康检查
curl http://127.0.0.1:8080/api/v1/health

# 查看统计
curl http://127.0.0.1:8080/api/v1/stats
```

成功响应示例：
```json
{
  "status": "ok",
  "total_memories": 42,
  "index_size": 42
}
```

---

## 🔧 在 Claude Code 中使用

安装完成后，在 **新的** Claude Code 会话中可以使用以下工具：

### recall - 检索记忆

当你想回忆之前讨论过的内容时使用：

```
"检索之前关于 nginx 配置的讨论"
"回忆我们讨论的数据库设计方案"
"查找之前写的登录功能代码"
```

### remember - 存储记忆

手动保存重要信息：

```
"记住：用户偏好使用 TypeScript"
"记住：项目使用 pnpm 作为包管理器"
"记住：API 基础路径是 /api/v1"
```

### memory_stats - 查看状态

```
"查看记忆系统状态"
"显示记忆统计信息"
```

---

## ⚙️ 配置选项

### Embedding 模型

| 方案 | 模型 | 优点 | 配置 |
|------|------|------|------|
| **Ollama**（默认） | nomic-embed-text | 免费、本地、隐私好 | `EMBEDDING_PROVIDER=ollama` |
| **OpenAI** | text-embedding-3-small | 效果好、速度快 | `EMBEDDING_PROVIDER=openai`<br>`OPENAI_API_KEY=sk-xxx` |

切换到 OpenAI：

```bash
export EMBEDDING_PROVIDER=openai
export OPENAI_API_KEY=sk-your-key
```

### 数据目录

| 路径 | 说明 |
|------|------|
| `~/.mnemo/data-768/` | 记忆向量数据 |
| `~/.claude/mnemo-sync-state.json` | 同步状态 |
| `~/.mnemo/config/default.toml` | 配置文件 |

---

## 🏗️ 架构说明

```
┌─────────────────────────────────────────────────────────────┐
│                    Mnemo 记忆系统                            │
├─────────────────────────────────────────────────────────────┤
│  Claude Code 对话                                           │
│       ↓ (自动监控 ~/.claude/projects/*.jsonl)              │
│  mnemo-sync ──→ Ollama (embedding) ──→ Mnemo (向量存储)    │
│       ↓                                                     │
│  mnemo-mcp (MCP Server) ←──→ Claude Code (新会话检索)      │
└─────────────────────────────────────────────────────────────┘
```

**组件说明：**

| 组件 | 语言 | 功能 |
|------|------|------|
| **mnemo** | Rust | 核心服务，向量存储和检索 |
| **mnemo-sync** | Python | 监控 Claude Code 对话，自动同步到 Mnemo |
| **mnemo-mcp** | TypeScript | MCP Server，让 Claude Code 能调用记忆功能 |

---

## 🆚 与 CLAUDE.md 的区别

| 特性 | CLAUDE.md | Mnemo |
|------|-----------|-------|
| 维护方式 | 手动编写 | 自动同步 |
| 内容类型 | 项目说明 | **所有对话历史** |
| 检索方式 | 全文加载到上下文 | 语义搜索，按需检索 |
| 跨项目 | ❌ 每个项目独立 | ✅ 全局记忆 |
| 上下文消耗 | 固定消耗 | 按需检索，更省 token |

**最佳实践：** CLAUDE.md 用于项目规范说明，Mnemo 用于记录对话历史和知识积累。两者互补。

---

## 🔍 常见问题

### Q: 服务启动后检索返回空结果？

**A:** 可能是还没有同步对话。检查：

```bash
# 查看同步状态
cat ~/.claude/mnemo-sync-state.json

# 查看记忆数量
curl http://127.0.0.1:8080/api/v1/stats
```

### Q: 出现 500 错误？

**A:** 通常是 Ollama 没有运行或模型没下载：

```bash
# 检查 Ollama
curl http://localhost:11434/api/tags

# 如果没响应，启动 Ollama
ollama serve

# 确保模型已下载
ollama pull nomic-embed-text
```

### Q: 如何重置所有记忆？

**A:** 删除数据目录：

```bash
rm -rf ~/.mnemo/data-768/
rm ~/.claude/mnemo-sync-state.json
```

### Q: 磁盘空间占用？

**A:** 每条记忆约占用 3-4KB（768维向量 + 元数据）。10000 条对话约占用 30-40MB。

### Q: 支持中文吗？

**A:** 完全支持。nomic-embed-text 模型对中文有良好的支持。

---

## 📊 API 参考

### 健康检查

```bash
GET http://127.0.0.1:8080/api/v1/health
```

### 统计信息

```bash
GET http://127.0.0.1:8080/api/v1/stats
```

### 存储记忆

```bash
POST http://127.0.0.1:8080/api/v1/remember
Content-Type: application/json

{
  "description": "记忆内容",
  "embedding": [0.1, 0.2, ...],  // 768维向量
  "metadata": {
    "source": "manual",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

### 检索记忆

```bash
POST http://127.0.0.1:8080/api/v1/recall
Content-Type: application/json

{
  "embedding": [0.1, 0.2, ...],  // 768维查询向量
  "top_k": 5
}
```

---

## 🛠️ 故障排除

### 查看日志

```bash
# Mnemo 服务日志
tail -f /tmp/mnemo.log

# Ollama 日志
tail -f /tmp/ollama.log

# 同步服务日志（实时输出）
```

### 重启服务

```bash
mnemo-stop
mnemo-start
```

### 检查端口占用

```bash
# Linux / macOS
lsof -i :8080
lsof -i :11434

# Windows
netstat -ano | findstr :8080
netstat -ano | findstr :11434
```

---

## 📄 License

MIT License - 详见 [LICENSE](LICENSE)

---

## 🙏 致谢

- [Ollama](https://ollama.com/) - 本地 AI 运行时
- [Claude Code](https://claude.ai/code) - AI 编程助手
- [nomic-embed-text](https://ollama.com/library/nomic-embed-text) - 高质量开源 embedding 模型

---

**遇到问题？** 请在 [Issues](https://github.com/icyyaww/mnemo-releases/issues) 中反馈。
