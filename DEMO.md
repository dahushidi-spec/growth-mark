# 成长印记 · 一键 Demo

> 无需任何外部 API Key、无需 OSS、无需真实短信通道，`docker compose up -d --build` 一键启动全栈 Demo。

## 前置要求

- **Docker Desktop**（Windows/Mac）或 **Docker Engine + Compose v2**（Linux）
- 建议内存 ≥ 6GB（Flutter Web 构建镜像较大）
- 磁盘空间 ≥ 5GB

## 一键启动

```bash
git clone <repository-url>
cd growth-mark
docker compose up -d --build
```

首次构建约 5–10 分钟（拉镜像 + Flutter Web 编译）。后续启动约 30 秒。

启动后查看状态：

```bash
docker compose ps
```

应当看到 5 个容器：`mysql`、`redis`、`api`、`celery-worker`、`web`，状态均为 `healthy` 或 `running`。

## 访问应用

| 入口 | 地址 |
|---|---|
| 前端 App | http://localhost |
| API 文档（Swagger） | http://localhost/docs |
| ReDoc 文档 | http://localhost/redoc |
| 健康检查 | http://localhost/health |
| 后端直连（调试） | http://localhost:8000 |

## 演示账号

| 字段 | 值 |
|---|---|
| 手机号 | `13800138000` |
| 密码 | `123456` |

注册新账号：任意手机号，**验证码固定为 `123456`**（开发模式）。

种子数据已预置：
- 1 个家庭「成长之家」（含邀请码，可在家庭空间查看）
- 2 个孩子档案（小明 / 小红）
- 20 件作品（绘画/书法/手工/音乐/写作/其他 分类循环）
- 10 项荣誉（国家级/省级/市级/校级 循环）

## 功能导览

按底部导航栏顺序体验：

1. **时间线** `/main/timeline`
   - 浏览 20 条种子作品，按分类筛选
   - 点击任意作品进入详情页

2. **上传** `/main/upload`
   - 选择图片（PNG/JPG）
   - 点击「AI 识别」→ 返回 mock 结果（分类「其他」+ 描述提示，因为未配置真实 AI Key）
   - 填写标题后提交 → 时间线立即出现新作品

3. **荣誉墙** `/main/honors`
   - 浏览 10 条荣誉，按级别（国家/省/市/校）筛选
   - 查看荣誉统计

4. **成长故事** `/main/story`
   - 点击「生成报告」→ Celery 异步任务执行，返回 mock 成长报告文本
   - 查看历史报告列表

5. **个人中心** `/main/profile`
   - 查看/切换孩子档案（小明 / 小红）
   - 编辑孩子信息
   - 进入「家庭空间」查看邀请码
   - 进入「设置」调整偏好

6. **分享**（作品详情页内）
   - 在作品详情页点击分享按钮
   - 生成分享卡片，复制链接到剪贴板

## 服务架构

```
浏览器 ──► nginx :80 ──┬── /          → Flutter Web 静态资源
                       ├── /api/      → api:8000 (FastAPI)
                       ├── /uploads/  → api:8000 (本地图片)
                       └── /docs      → api:8000 (Swagger)

api:8000 ──► mysql:3306 (主库)
         ──► redis:6379 (缓存/频率限制)
         ──► celery-worker (异步任务，AI/报告)
```

## 降级说明（Demo 模式自动启用）

| 功能 | 真实环境 | Demo 模式 |
|---|---|---|
| 短信验证码 | 阿里云 SMS | 固定 `123456`，日志打印 |
| 图片存储 | 阿里云 OSS | 本地 `uploads/` 目录 |
| AI 图像识别 | 通义千问 VL | mock：返回分类「其他」+ 提示文案 |
| AI 成长报告 | 通义千问 | mock：返回固定模板文本 |

日志验证：
```bash
docker compose logs api | grep -E "DEV SMS|本地文件|AI"
```

## 常用命令

```bash
# 查看实时日志
docker compose logs -f api web

# 重启某服务
docker compose restart api

# 进入容器
docker compose exec api bash

# 手动重新种子
docker compose exec api python seed.py

# 停止（保留数据）
docker compose down

# 停止并清空数据
docker compose down -v
```

## 故障排查

**前端加载白屏**：等 Flutter Web 资源加载完毕，查看 `docker compose logs web`。

**登录返回 500**：MySQL 可能未就绪，查看 `docker compose logs api`，确认日志有「MySQL 已就绪」「种子数据创建完成」。

**上传图片后无法显示**：确认 `./backend/uploads/` 目录存在且有写权限；nginx 已挂载该目录通过 `/uploads/` 代理。

**端口冲突**：80 端口被占用时，修改 `docker-compose.yml` 中 `web.ports` 为 `"8080:80"`，访问 `http://localhost:8080`。

## 生产部署提示

本 Demo 配置**不可直接用于生产**：
- JWT 密钥为占位值
- APP_ENV=development（SMS 走固定码）
- 未启用 HTTPS
- 未配置 OSS / AI / SMS 真实密钥
- CORS 允许 localhost

生产部署请参考 [README.md](README.md) 中的「生产环境检查清单」。
