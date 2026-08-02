# 成长印记 Growth Mark — API 接口契约文档

> 版本：v1.0 | 更新日期：2026-06-27 | 基础URL：`/api/v1`

本文档定义前后端接口契约，前端可据此 Mock 开发，后端据此实现 API。

---

## 通用约定

### 请求基础信息

| 项目 | 值 |
|------|-----|
| Base URL | `http://localhost:8000/api/v1` |
| 请求格式 | `application/json`（文件上传除外，使用 `multipart/form-data`） |
| 响应格式 | `application/json` |
| 字符编码 | UTF-8 |
| 认证方式 | Bearer Token（JWT） |

### 统一响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": { ... }
}
```

### 错误码

| HTTP 状态码 | code | 含义 |
|-------------|------|------|
| 200 | 200 | 成功 |
| 400 | 400 | 请求参数错误 |
| 401 | 401 | 未认证或Token过期 |
| 403 | 403 | 无权限访问 |
| 404 | 404 | 资源不存在 |
| 409 | 409 | 资源冲突（如手机号已注册） |
| 422 | 422 | 请求体校验失败 |
| 500 | 500 | 服务器内部错误 |

### 认证机制

除 `/auth/register`、`/auth/login`、`/auth/refresh` 外，所有接口需在请求头携带：

```
Authorization: Bearer <access_token>
```

Token 过期后，使用 `refresh_token` 调用 `/auth/refresh` 获取新的 `access_token`。

### 分页约定

**请求参数：**

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| page | int | 1 | 页码，从1开始 |
| size | int | 20 | 每页条数，最大100 |

**分页响应：**

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [ ... ],
    "total": 86,
    "page": 1,
    "size": 20
  }
}
```

---

## 一、认证模块

### 1.1 用户注册

`POST /auth/register`

**请求体：**
```json
{
  "phone": "13800138000",
  "password": "123456",
  "nickname": "小米妈妈",
  "verification_code": "123456"
}
```

| 字段 | 类型 | 必填 | 校验规则 |
|------|------|------|----------|
| phone | string | 是 | 11位手机号 |
| password | string | 是 | 6-20位 |
| nickname | string | 是 | 1-50字符 |
| verification_code | string | 是 | 6位数字 |

**响应：**
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer",
    "user": {
      "id": 1,
      "phone": "13800138000",
      "nickname": "小米妈妈",
      "avatar_url": null
    }
  }
}
```

**错误：**
- 409: 手机号已注册
- 400: 验证码错误或已过期

---

### 1.2 发送验证码

`POST /auth/send-code`

**请求体：**
```json
{
  "phone": "13800138000"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "验证码已发送",
  "data": null
}
```

---

### 1.3 用户登录

`POST /auth/login`

**请求体：**
```json
{
  "phone": "13800138000",
  "password": "123456"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer",
    "user": {
      "id": 1,
      "phone": "13800138000",
      "nickname": "小米妈妈",
      "avatar_url": "https://cdn.growthmark.app/avatars/1.jpg"
    }
  }
}
```

**错误：**
- 401: 手机号或密码错误

---

### 1.4 刷新Token

`POST /auth/refresh`

**请求体：**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer"
  }
}
```

**错误：**
- 401: refresh_token无效或已过期

---

### 1.5 获取当前用户信息

`GET /auth/me`

**Headers：** `Authorization: Bearer <token>`

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "phone": "13800138000",
    "nickname": "小米妈妈",
    "avatar_url": "https://cdn.growthmark.app/avatars/1.jpg"
  }
}
```

---

## 二、孩子档案模块

### 2.1 创建孩子档案

`POST /children`

**请求体：**
```json
{
  "name": "小米",
  "gender": 1,
  "birth_date": "2021-03-15",
  "avatar_url": "https://cdn.growthmark.app/children/1.jpg"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 是 | 孩子姓名，1-20字符 |
| gender | int | 是 | 0=女, 1=男 |
| birth_date | string | 是 | 出生日期 YYYY-MM-DD |
| avatar_url | string | 否 | 头像URL |

**响应：**
```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "id": 1,
    "user_id": 1,
    "name": "小米",
    "gender": 1,
    "birth_date": "2021-03-15",
    "avatar_url": null,
    "age": "5岁3个月",
    "created_at": "2026-06-27T10:00:00Z"
  }
}
```

---

### 2.2 获取孩子列表

`GET /children`

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "name": "小米",
      "gender": 1,
      "birth_date": "2021-03-15",
      "avatar_url": "https://cdn.growthmark.app/children/1.jpg",
      "age": "5岁3个月"
    }
  ]
}
```

---

### 2.3 更新孩子档案

`PUT /children/{id}`

**请求体：**
```json
{
  "name": "小米",
  "avatar_url": "https://cdn.growthmark.app/children/1.jpg"
}
```

---

### 2.4 删除孩子档案

`DELETE /children/{id}`

---

## 三、作品模块

### 3.1 获取时间线

`GET /works/timeline`

**查询参数：**

| 参数 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| page | int | 否 | 1 | 页码 |
| size | int | 否 | 20 | 每页条数 |
| category | string | 否 | - | 筛选类别：绘画/书法/手工/音乐/写作/其他 |
| child_id | int | 否 | - | 筛选孩子 |
| start_date | string | 否 | - | 起始日期 YYYY-MM-DD |
| end_date | string | 否 | - | 结束日期 YYYY-MM-DD |

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 101,
        "child_id": 1,
        "user_id": 1,
        "title": "我的第一幅水彩画",
        "category": "绘画",
        "description": "小米画了家里的猫橘子",
        "image_url": "https://cdn.growthmark.app/works/101.jpg",
        "thumbnail_url": "https://cdn.growthmark.app/works/thumb_101.jpg",
        "created_date": "2026-06-15",
        "child_age": "5岁3个月",
        "tags": ["水彩", "动物"],
        "created_at": "2026-06-15T14:30:00Z"
      }
    ],
    "total": 86,
    "page": 1,
    "size": 20
  }
}
```

---

### 3.2 上传作品

`POST /works`

**请求体：**
```json
{
  "child_id": 1,
  "title": "我的第一幅水彩画",
  "category": "绘画",
  "description": "小米画了家里的猫橘子",
  "image_url": "https://cdn.growthmark.app/works/20260615_xxx.jpg",
  "created_date": "2026-06-15",
  "tags": ["水彩", "动物"]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| child_id | int | 是 | 孩子ID |
| title | string | 是 | 作品名称，1-100字符 |
| category | string | 是 | 类别枚举 |
| description | string | 否 | 创作故事 |
| image_url | string | 是 | 图片URL（先调用上传接口获取） |
| created_date | string | 是 | 创作日期 YYYY-MM-DD |
| tags | string[] | 否 | 标签列表 |

**响应：**
```json
{
  "code": 200,
  "message": "作品创建成功",
  "data": {
    "id": 101,
    "child_age": "5岁3个月",
    "thumbnail_url": "https://cdn.growthmark.app/works/thumb_101.jpg",
    "created_at": "2026-06-27T10:30:00Z"
  }
}
```

---

### 3.3 获取作品详情

`GET /works/{id}`

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 101,
    "child_id": 1,
    "user_id": 1,
    "title": "我的第一幅水彩画",
    "category": "绘画",
    "description": "小米画了家里的猫橘子",
    "image_url": "https://cdn.growthmark.app/works/101.jpg",
    "thumbnail_url": "https://cdn.growthmark.app/works/thumb_101.jpg",
    "created_date": "2026-06-15",
    "child_age": "5岁3个月",
    "tags": ["水彩", "动物"],
    "is_deleted": false,
    "created_at": "2026-06-15T14:30:00Z",
    "updated_at": "2026-06-15T14:30:00Z"
  }
}
```

---

### 3.4 更新作品

`PUT /works/{id}`

**请求体：**
```json
{
  "title": "我的第一幅水彩画（修改）",
  "description": "更新描述",
  "category": "绘画",
  "tags": ["水彩", "动物", "猫"]
}
```

---

### 3.5 删除作品

`DELETE /works/{id}`

软删除，设置 `is_deleted = true`。

**响应：**
```json
{
  "code": 200,
  "message": "删除成功",
  "data": null
}
```

---

## 四、荣誉模块

### 4.1 获取荣誉列表

`GET /honors`

**查询参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| level | string | 否 | 级别：国家级/省级/市级/校级 |
| category | string | 否 | 类别 |
| child_id | int | 否 | 孩子ID |
| page | int | 否 | 页码 |
| size | int | 否 | 每页条数 |

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "child_id": 1,
        "title": "少儿绘画大赛金奖",
        "level": "市级",
        "category": "绘画",
        "image_url": "https://cdn.growthmark.app/honors/1.jpg",
        "award_date": "2026-05-20",
        "organization": "市文化局",
        "description": "在市级少儿绘画大赛中获得金奖",
        "created_at": "2026-05-20T16:00:00Z"
      }
    ],
    "total": 12,
    "page": 1,
    "size": 20
  }
}
```

---

### 4.2 上传荣誉

`POST /honors`

**请求体：**
```json
{
  "child_id": 1,
  "title": "少儿绘画大赛金奖",
  "level": "市级",
  "category": "绘画",
  "image_url": "https://cdn.growthmark.app/honors/1.jpg",
  "award_date": "2026-05-20",
  "organization": "市文化局",
  "description": "在市级少儿绘画大赛中获得金奖"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| child_id | int | 是 | 孩子ID |
| title | string | 是 | 荣誉名称 |
| level | string | 是 | 级别：国家级/省级/市级/校级 |
| category | string | 是 | 类别 |
| image_url | string | 是 | 证书图片URL |
| award_date | string | 是 | 获奖日期 |
| organization | string | 否 | 颁发机构 |
| description | string | 否 | 获奖描述 |

---

### 4.3 获取荣誉统计

`GET /honors/stats`

**查询参数：** `child_id` (可选)

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 12,
    "this_year": 5,
    "high_level": 3,
    "by_level": {
      "国家级": 1,
      "省级": 2,
      "市级": 5,
      "校级": 4
    },
    "by_category": {
      "绘画": 4,
      "音乐": 3,
      "书法": 2,
      "其他": 3
    }
  }
}
```

---

### 4.4 获取荣誉详情

`GET /honors/{id}`

---

### 4.5 删除荣誉

`DELETE /honors/{id}`

---

## 五、AI 模块

### 5.1 AI 图像识别

`POST /ai/recognize`

**请求体：**
```json
{
  "image_url": "https://cdn.growthmark.app/works/temp/20260615_xxx.jpg"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "识别成功",
  "data": {
    "category": "绘画",
    "tags": ["水彩", "动物", "猫"],
    "description_suggestion": "一幅充满童趣的水彩画，画中是一只橘色的猫咪，色彩明亮。",
    "confidence": 0.95
  }
}
```

**错误：**
- 500: AI识别失败（降级为手动分类）

---

### 5.2 生成成长报告

`POST /ai/report`

**请求体：**
```json
{
  "child_id": 1,
  "period": "2026-Q2",
  "start_date": "2026-04-01",
  "end_date": "2026-06-30"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "报告生成成功",
  "data": {
    "id": 1,
    "child_id": 1,
    "period": "2026-Q2",
    "content": "本季度小米共创作了15幅作品，其中绘画8幅...",
    "interest_analysis": "对绘画和动物题材表现出浓厚兴趣",
    "growth_suggestion": "建议尝试更多色彩搭配练习...",
    "generated_at": "2026-06-27T11:00:00Z"
  }
}
```

---

## 六、家庭空间模块

### 6.1 创建家庭空间

`POST /families`

**请求体：**
```json
{
  "name": "小米的家"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "家庭空间创建成功",
  "data": {
    "id": 1,
    "name": "小米的家",
    "invite_code": "A3X9K2",
    "creator_id": 1,
    "created_at": "2026-06-27T10:00:00Z"
  }
}
```

---

### 6.2 加入家庭空间

`POST /families/join`

**请求体：**
```json
{
  "invite_code": "A3X9K2"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "加入成功",
  "data": {
    "family_id": 1,
    "name": "小米的家",
    "role": "member"
  }
}
```

**错误：**
- 404: 邀请码无效
- 409: 已是该家庭成员

---

### 6.3 获取家庭成员列表

`GET /families/{id}/members`

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "user_id": 1,
      "nickname": "小米妈妈",
      "avatar_url": "https://cdn.growthmark.app/avatars/1.jpg",
      "role": "creator",
      "joined_at": "2026-06-27T10:00:00Z"
    },
    {
      "id": 2,
      "user_id": 2,
      "nickname": "小米奶奶",
      "avatar_url": "https://cdn.growthmark.app/avatars/2.jpg",
      "role": "member",
      "joined_at": "2026-06-27T11:00:00Z"
    }
  ]
}
```

---

### 6.4 移除家庭成员

`DELETE /families/{id}/members/{user_id}`

仅创建者和管理员可操作。

---

## 七、文件上传模块

### 7.1 获取上传URL

`POST /upload/sign`

获取OSS临时上传URL，客户端直接上传文件到OSS。

**请求体：**
```json
{
  "file_name": "photo.jpg",
  "content_type": "image/jpeg",
  "file_type": "work"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "upload_url": "https://growth-mark.oss-cn-hangzhou.aliyuncs.com/works/20260615_xxx.jpg?Expires=...",
    "file_url": "https://cdn.growthmark.app/works/20260615_xxx.jpg",
    "expires_in": 300
  }
}
```

---

## 八、分享模块

### 8.1 生成分享卡片

`POST /shares/card`

**请求体：**
```json
{
  "work_id": 101,
  "template": "warm"
}
```

**响应：**
```json
{
  "code": 200,
  "message": "卡片生成成功",
  "data": {
    "card_url": "https://cdn.growthmark.app/shares/card_101_20260627.jpg",
    "share_url": "https://share.growthmark.app/w/abc123",
    "expires_at": "2026-07-27T10:00:00Z"
  }
}
```

---

### 8.2 查看分享内容

`GET /shares/{token}`

无需认证，公开访问（有过期时间）。

**响应：**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "type": "work",
    "title": "我的第一幅水彩画",
    "image_url": "https://cdn.growthmark.app/works/101.jpg",
    "description": "小米画了家里的猫橘子",
    "child_name": "小米",
    "child_age": "5岁3个月",
    "created_date": "2026-06-15",
    "expires_at": "2026-07-27T10:00:00Z"
  }
}
```

---

## 附录

### 枚举值定义

**作品类别 (WorkCategory)：**
`绘画` | `书法` | `手工` | `音乐` | `写作` | `其他`

**荣誉级别 (HonorLevel)：**
`国家级` | `省级` | `市级` | `校级`

**家庭角色 (FamilyRole)：**
`creator` | `admin` | `member`

**分享类型 (ShareType)：**
`work` | `honor` | `report` | `card`

### 日期格式约定

| 场景 | 格式 | 示例 |
|------|------|------|
| 日期 | YYYY-MM-DD | 2026-06-15 |
| 日期时间 | ISO 8601 | 2026-06-27T10:00:00Z |
| 年龄显示 | X岁X月 | 5岁3个月 |
| 报告周期 | YYYY-Qn | 2026-Q2 |

### Mock 数据示例

前端开发时可使用以下测试账号：
- 手机号：`13800138000`
- 密码：`123456`
- 预置数据：2个孩子、20条作品、10条荣誉
