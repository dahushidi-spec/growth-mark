# 成长印记 Growth Mark

> 一款专为家庭打造的儿童创作作品与荣誉成长记录应用，让每一份童真创作都被珍视，让每一段成长轨迹都有迹可循。

<<<<<<< HEAD
=======

>>>>>>> feb4eb5 (Remove contest references from docs)
---

## 项目简介

"成长印记"以时间线为核心组织方式，帮助家长系统性地记录子女从幼儿到青少年时期的创作成果——书法、绘画、手工作品、音乐表演、写作习作，以及各类荣誉奖章、竞赛证书、考级证明等。通过 AI 智能分类、自动标签、成长报告生成等特色功能，让家庭的温暖记忆被妥善保存、便捷回顾、代代传承。

### 核心功能

- **成长时间线**：按时间轴展示孩子的所有作品和荣誉，支持分类筛选
- **作品记录**：拍照上传创作作品，AI 自动识别分类并建议标签
- **荣誉墙**：专门管理奖章、证书、考级成绩，按级别分类展示
- **AI 智能能力**：图像识别分类、智能描述生成、成长报告生成
- **家庭共享**：邀请配偶、祖辈加入家庭空间，共同参与孩子成长记录
- **成长画册**：一键生成精美电子画册，支持打印成实体书

---

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 移动端 | Flutter 3.x + Riverpod | 一套代码输出 iOS / Android 双端 |
| 后端 | Python 3.11 + FastAPI | 异步高性能，自动生成 API 文档 |
| 数据库 | MySQL 8.0 + Redis | 主库 + 缓存/消息队列 |
| AI | 多模态大模型 API | 通义千问 VL / GPT-4V 图像识别 |
| 存储 | 阿里云 OSS / 腾讯 COS | 图片视频存储 + CDN 加速 |
| 部署 | Docker + Nginx | 容器化部署，负载均衡 |

---

## 项目结构

```
growth-mark/
├── README.md                      # 项目说明（本文件）
├── docs/                          # 项目文档
│   ├── growth-mark.html           # 项目立项报告
│   ├── phase1-research.html       # 第一阶段：调研与设计文档
│   └── dev-plan.html              # 开发计划与任务分解
├── backend/                       # 后端项目（FastAPI）
│   ├── app/
│   │   ├── main.py                # 应用入口
│   │   ├── api/v1/                # API 路由
│   │   ├── core/                  # 核心配置（数据库/安全/配置）
│   │   ├── models/                # 数据模型
│   │   ├── schemas/               # Pydantic 模型
│   │   ├── services/              # 业务逻辑
│   │   └── tasks/                 # Celery 异步任务
│   ├── alembic/                   # 数据库迁移
│   ├── tests/                     # 测试用例
│   ├── requirements.txt           # Python 依赖
│   ├── .env.example               # 环境变量模板
│   └── Dockerfile
├── frontend/                      # 前端项目（Flutter）
│   ├── lib/
│   │   ├── main.dart              # 应用入口
│   │   ├── app/                   # 应用配置（路由/主题）
│   │   ├── features/              # 功能模块
│   │   │   ├── timeline/          # 时间线
│   │   │   ├── upload/            # 上传
│   │   │   ├── honors/            # 荣誉墙
│   │   │   ├── story/             # 成长故事
│   │   │   └── profile/           # 个人中心
│   │   ├── core/                  # 核心层（网络/存储/工具）
│   │   ├── models/                # 数据模型
│   │   └── shared/                # 共享组件
│   ├── assets/                    # 静态资源
│   ├── pubspec.yaml               # Flutter 依赖
│   └── analysis_options.yaml      # 代码规范配置
└── docker-compose.yml             # 一键部署编排
```

---

## 环境要求

### 本地开发环境

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| Flutter | >= 3.19.0 | 运行 `flutter doctor` 确认工具链完整 |
| Dart | >= 3.3.0 | 随 Flutter 内置 |
| Python | >= 3.11 | 后端运行环境 |
| MySQL | >= 8.0 | 主数据库 |
| Redis | >= 7.0 | 缓存与消息队列 |
| Docker | >= 24.0 | 容器化部署（可选，用于本地起 MySQL/Redis） |
| Git | >= 2.40 | 版本控制 |

### IDE 推荐

- **前端**：Android Studio 或 VS Code（安装 Flutter / Dart 插件）
- **后端**：VS Code（安装 Python / Pylance 插件）或 PyCharm

---

## 快速开始

### 1. 克隆仓库

```bash
git clone <repository-url>
cd growth-mark
```

### 2. 后端启动

```bash
cd backend

# 创建虚拟环境
python -m venv venv
source venv/bin/activate        # macOS/Linux
# venv\Scripts\activate         # Windows PowerShell

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入数据库连接、OSS密钥、AI API Key 等

# 数据库迁移
alembic upgrade head

# 填充种子数据（可选）
python seed.py

# 启动开发服务器
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

启动后访问：
- API 服务：http://localhost:8000
- Swagger 文档：http://localhost:8000/docs
- ReDoc 文档：http://localhost:8000/redoc

### 3. 前端启动

```bash
cd frontend

# 安装依赖
flutter pub get

# 生成代码（模型/路由等）
dart run build_runner build --delete-conflicting-outputs

# 运行（Debug 模式）
flutter run
```

### 4. 本地起 MySQL + Redis（Docker 方式）

```bash
# 在项目根目录执行
docker-compose up -d mysql redis
```

---

## 环境变量配置

后端 `.env` 文件配置项（参考 `.env.example`）：

```env
# ===== 应用配置 =====
APP_NAME=GrowthMark
APP_ENV=development
DEBUG=true

# ===== 数据库 =====
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=growth_mark_dev

# ===== Redis =====
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# ===== JWT 认证 =====
JWT_SECRET_KEY=your-secret-key-change-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=120
REFRESH_TOKEN_EXPIRE_DAYS=7

# ===== 阿里云 OSS =====
OSS_ACCESS_KEY_ID=your-access-key
OSS_ACCESS_KEY_SECRET=your-secret-key
OSS_BUCKET_NAME=growth-mark
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_CDN_DOMAIN=https://cdn.growthmark.app

# ===== 短信服务 =====
SMS_ACCESS_KEY_ID=your-sms-key
SMS_ACCESS_KEY_SECRET=your-sms-secret
SMS_SIGN_NAME=成长印记
SMS_TEMPLATE_CODE=SMS_XXXXXX

# ===== AI 大模型 =====
AI_PROVIDER=qwen    # qwen | openai
AI_API_KEY=your-ai-api-key
AI_MODEL=qwen-vl-max
AI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1

# ===== Celery =====
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/2

# ===== CORS =====
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

> **安全提示**：`.env` 文件已加入 `.gitignore`，切勿提交到仓库。生产环境请使用强随机密钥。

---

## 开发规范

### Git 分支策略

```
main          # 生产分支，保护分支
├── develop   # 开发主分支
├── feature/backend-xxx    # 后端功能分支
├── feature/frontend-xxx   # 前端功能分支
└── hotfix/xxx             # 紧急修复
```

### 提交规范（Conventional Commits）

```
<type>(<scope>): <subject>

类型 type：
  feat     新功能
  fix      修复 Bug
  docs     文档变更
  style    代码格式（不影响功能）
  refactor 重构
  test     测试相关
  chore    构建/工具变更

示例：
  feat(backend): 完成作品上传 API
  fix(frontend): 修复时间线分页加载问题
  docs: 更新 README 部署说明
```

### 代码规范

- **前端（Dart）**：使用 `dart format` 格式化，遵循 `analysis_options.yaml` 规则
- **后端（Python）**：使用 `black` 格式化 + `ruff` 检查，行宽 88 字符
- **API 命名**：RESTful 风格，路径小写复数，版本前缀 `/api/v1`
- **数据库命名**：表名小写复数，字段名 snake_case

---

## API 概览

| 模块 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 认证 | POST | /api/v1/auth/register | 手机号注册 |
| 认证 | POST | /api/v1/auth/login | 登录 |
| 认证 | POST | /api/v1/auth/refresh | 刷新 Token |
| 作品 | GET | /api/v1/works/timeline | 时间线列表 |
| 作品 | POST | /api/v1/works | 上传作品 |
| 作品 | GET | /api/v1/works/{id} | 作品详情 |
| 作品 | PUT | /api/v1/works/{id} | 编辑作品 |
| 作品 | DELETE | /api/v1/works/{id} | 删除作品 |
| 荣誉 | GET | /api/v1/honors | 荣誉列表 |
| 荣誉 | POST | /api/v1/honors | 上传荣誉 |
| AI | POST | /api/v1/ai/recognize | AI 识别作品 |
| AI | POST | /api/v1/ai/report | 生成成长报告 |
| 家庭 | POST | /api/v1/families | 创建家庭 |
| 家庭 | POST | /api/v1/families/join | 加入家庭 |
| 分享 | POST | /api/v1/shares/card | 生成分享卡片 |

完整接口文档启动后访问 Swagger：http://localhost:8000/docs

---

## 数据库设计

核心数据表 9 张：

| 表名 | 说明 |
|------|------|
| users | 用户表 |
| children | 孩子档案表 |
| families | 家庭空间表 |
| family_members | 家庭成员关联表 |
| works | 作品表 |
| honors | 荣誉表 |
| work_tags | 作品标签表 |
| growth_reports | 成长报告表 |
| shares | 分享记录表 |

详细表结构和关系请参考 `docs/phase1-research.html` 中的"技术方案细化"章节。

---

## 部署

### Docker 部署

```bash
# 构建镜像
docker-compose build

# 启动全部服务
docker-compose up -d

# 查看日志
docker-compose logs -f api
```

### 生产环境检查清单

- [ ] `.env` 中所有密钥已替换为生产环境强随机值
- [ ] `DEBUG=False`，关闭调试模式
- [ ] HTTPS 证书已配置
- [ ] 数据库自动备份已开启
- [ ] Sentry 异常监控已接入
- [ ] OSS 防盗链已配置
- [ ] CORS 允许的域名已限制为生产域名

---

## 项目文档

| 文档 | 说明 |
|------|------|
| [项目立项报告](docs/growth-mark.html) | 创意介绍、目标用户、市场调研、功能规划、开发路线图 |
| [调研与设计文档](docs/phase1-research.html) | 用户访谈提纲、原型设计规划、技术方案细化 |
| [开发计划](docs/dev-plan.html) | 6 周里程碑、32 项前后端任务分解、联调测试、风险管理 |
<<<<<<< HEAD
=======

---

## 开发里程碑

| 阶段 | 时间 | 目标 |
|------|------|------|
| Week 1 | 6/30 - 7/6 | 基础设施搭建：脚手架、数据库、认证、框架 |
| Week 2 | 7/7 - 7/13 | 核心功能：作品/荣誉 CRUD、时间线、上传 |
| Week 3 | 7/14 - 7/20 | AI 与高级：AI 识别、家庭空间、成长故事 |
| Week 4 | 7/21 - 7/27 | 功能完善：全功能开发完成，进入联调 |
| Week 5 | 7/28 - 8/3 | 联调测试：前后端联调、Bug 修复、性能优化 |
| Week 6 | 8/4 - 8/8 | Demo 交付：UI 打磨、录制视频、提交初赛 |

---

## 技术支持

- **赛道**：生活娱乐
- **项目日期**：2026 年 6 月

---

## License

本项目所有权利归项目团队所有。
>>>>>>> feb4eb5 (Remove contest references from docs)
