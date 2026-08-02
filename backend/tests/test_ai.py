"""AI 服务与接口测试：图像识别、报告生成、JSON 解析。

AIService 在模块加载时读取 settings.AI_API_KEY（默认空字符串），因此默认走降级路径。
"""

from app.services.ai_service import AIService
from tests.test_auth import _register_user
from tests.test_children import _child_payload


async def _setup(client, phone="13800000090"):
    """注册用户 + 创建孩子档案，返回 (headers, child_id)。"""
    data = await _register_user(client, phone)
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post("/api/v1/children", headers=headers, json=_child_payload())
    return headers, resp.json()["data"]["id"]


# ============ 服务层：图像识别 ============

async def test_recognize_without_api_key():
    """未配置 API_KEY 时调用 recognize_image 应返回降级结果。"""
    service = AIService()
    result = await service.recognize_image("http://example.com/img.jpg")
    assert result["category"] == "其他"
    assert result["confidence"] == 0.0
    assert result["tags"] == []
    assert "description_suggestion" in result


# ============ 接口层：图像识别 ============

async def test_recognize_endpoint(client):
    """已登录用户调用识别接口应返回 200 与完整字段。"""
    data = await _register_user(client, "13800000091")
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    resp = await client.post(
        "/api/v1/ai/recognize",
        headers=headers,
        json={"image_url": "http://example.com/img.jpg"},
    )
    assert resp.status_code == 200
    result = resp.json()["data"]
    assert "category" in result
    assert "tags" in result
    assert "description_suggestion" in result
    assert "confidence" in result


# ============ JSON 解析 ============

async def test_parse_json_from_code_block():
    """能解析 ```json {...} ``` 包裹的 JSON。"""
    text = (
        "```json\n"
        '{"category": "绘画", "tags": ["水彩", "风景"], '
        '"description_suggestion": "一幅水彩风景画", "confidence": 0.85}\n'
        "```"
    )
    result = AIService._parse_recognize_json(text)
    assert result["category"] == "绘画"
    assert result["tags"] == ["水彩", "风景"]
    assert result["description_suggestion"] == "一幅水彩风景画"
    assert result["confidence"] == 0.85


async def test_parse_json_from_plain_text():
    """能解析纯 JSON 文本。"""
    text = (
        '{"category": "书法", "tags": ["楷书"], '
        '"description_suggestion": "楷书作品", "confidence": 0.9}'
    )
    result = AIService._parse_recognize_json(text)
    assert result["category"] == "书法"
    assert result["tags"] == ["楷书"]
    assert result["confidence"] == 0.9


async def test_parse_invalid_json_fallback():
    """解析无效 JSON 应返回降级结果。"""
    result = AIService._parse_recognize_json("这不是JSON")
    assert result["category"] == "其他"
    assert result["confidence"] == 0.0
    assert result["tags"] == []


# ============ 服务层：报告生成 ============

async def test_generate_report_without_api_key():
    """未配置 API_KEY 时 generate_report 应返回降级报告文本。"""
    service = AIService()
    content = await service.generate_report(
        work_list=[{"title": "我的画", "category": "绘画"}],
        honor_list=[{"title": "一等奖", "level": "市级"}],
    )
    assert content
    assert "1 件作品" in content
    assert "1 项荣誉" in content


# ============ 接口层：报告生成 ============

async def test_report_endpoint(client):
    """已登录用户调用报告生成接口应返回 200 与非空 content。"""
    headers, child_id = await _setup(client, "13800000092")
    resp = await client.post(
        "/api/v1/ai/report",
        headers=headers,
        json={"child_id": child_id},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["content"]
