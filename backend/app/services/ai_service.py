"""AI 服务：调用大模型进行图像识别与成长报告生成。

支持通义千问 VL（qwen-vl-max）多模态模型，未配置 API Key 时返回占位结果，
调用失败时降级返回结构化兜底数据，保证主流程不中断。
"""

import json
import logging
import re
from typing import Any

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# 支持的作品分类集合，用于约束 AI 返回结果
_CATEGORY_OPTIONS = ["绘画", "书法", "手工", "音乐", "写作", "其他"]

# 图像识别 Prompt：要求模型严格按 JSON 返回
_RECOGNIZE_PROMPT = (
    "请分析这张儿童作品图片，严格按以下 JSON 格式返回（不要包含任何额外文字）：\n"
    "{\n"
    '  "category": "从["绘画","书法","手工","音乐","写作","其他"]中选择一个",\n'
    '  "tags": ["标签1", "标签2", "标签3"],\n'
    '  "description_suggestion": "一段50-150字的作品描述",\n'
    '  "confidence": 0.85\n'
    "}\n"
    "要求：tags 最多5个；confidence 为 0-1 的浮点数；"
    "如果无法识别图片内容，category 返回 \"其他\"，confidence 返回 0.3 以下。"
)


class AIService:
    """封装大模型调用（默认通义千问 qwen-vl-max）。"""

    def __init__(self) -> None:
        self.api_key = settings.AI_API_KEY
        self.model = settings.AI_MODEL
        self.base_url = settings.AI_BASE_URL

    async def recognize_image(self, image_url: str) -> dict[str, Any]:
        """识别作品图片，返回分类建议、标签、描述与置信度。

        Returns:
            dict: 包含 category/tags/description_suggestion/confidence 字段
        """
        if not self.api_key:
            return self._fallback_recognize()

        try:
            payload = {
                "model": self.model,
                "input": {
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {"image": image_url},
                                {"text": _RECOGNIZE_PROMPT},
                            ],
                        }
                    ]
                },
            }
            headers = {"Authorization": f"Bearer {self.api_key}"}

            transport = httpx.AsyncHTTPTransport(retries=2)
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(30.0), transport=transport
            ) as client:
                response = await client.post(
                    f"{self.base_url}/services/aigc/multimodal-generation/generation",
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                data = response.json()

            text = self._extract_text(data)
            result = self._parse_recognize_json(text)
            return result
        except httpx.HTTPError as e:
            logger.warning(f"AI 识别 HTTP 错误: {e}")
            return self._fallback_recognize()
        except Exception as e:  # noqa: BLE001
            logger.warning(f"AI 识别失败: {e}")
            return self._fallback_recognize()

    async def generate_report(
        self, work_list: list[dict[str, Any]], honor_list: list[dict[str, Any]]
    ) -> str:
        """根据作品与荣誉列表生成成长报告文本。"""
        if not self.api_key:
            return self._fallback_report(work_list, honor_list)

        works_summary = "、".join(
            f"{w.get('category')}《{w.get('title')}》" for w in work_list
        ) or "暂无作品"
        honors_summary = "、".join(
            f"{h.get('level')}《{h.get('title')}》" for h in honor_list
        ) or "暂无荣誉"

        prompt = (
            f"请根据以下孩子的成长记录，撰写一段温暖、鼓励性的成长报告：\n"
            f"作品：{works_summary}\n荣誉：{honors_summary}\n"
            "报告应包括成长亮点、努力方向与鼓励寄语，200-400 字。"
        )

        try:
            payload = {
                "model": self.model,
                "input": {
                    "messages": [{"role": "user", "content": prompt}],
                    "parameters": {"result_format": "message"},
                },
            }
            headers = {"Authorization": f"Bearer {self.api_key}"}

            transport = httpx.AsyncHTTPTransport(retries=2)
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(30.0), transport=transport
            ) as client:
                response = await client.post(
                    f"{self.base_url}/services/aigc/text-generation/generation",
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                data = response.json()

            text = self._extract_text(data)
            return text or self._fallback_report(work_list, honor_list)
        except httpx.HTTPError as e:
            logger.warning(f"AI 报告生成 HTTP 错误: {e}")
            return self._fallback_report(work_list, honor_list)
        except Exception as e:  # noqa: BLE001
            logger.warning(f"AI 报告生成失败: {e}")
            return self._fallback_report(work_list, honor_list)

    # ============ 辅助方法 ============

    @staticmethod
    def _extract_text(data: dict[str, Any]) -> str:
        """从大模型响应中提取文本内容（兼容通义千问多种返回格式）。"""
        try:
            output = data["output"]
            if "choices" in output:
                return output["choices"][0]["message"]["content"]
            if "text" in output:
                return output["text"]
            if "messages" in output:
                return output["messages"][0]["content"]
        except (KeyError, IndexError, TypeError):
            return ""
        return ""

    @staticmethod
    def _parse_recognize_json(text: str) -> dict[str, Any]:
        """解析模型返回的 JSON 文本，失败时降级。"""
        if not text:
            return AIService._fallback_recognize()

        # 尝试从文本中提取 JSON 块（模型可能包裹在 ```json ... ``` 中）
        json_str = text
        json_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1)
        else:
            # 尝试直接提取第一个 { ... } 块
            brace_match = re.search(r"\{.*\}", text, re.DOTALL)
            if brace_match:
                json_str = brace_match.group(0)

        try:
            data = json.loads(json_str)
            category = str(data.get("category", "其他"))
            if category not in _CATEGORY_OPTIONS:
                category = "其他"
            tags = data.get("tags", [])
            if not isinstance(tags, list):
                tags = []
            tags = [str(t) for t in tags][:5]
            description = str(data.get("description_suggestion", "AI 暂未返回描述。"))
            try:
                confidence = float(data.get("confidence", 0.5))
                confidence = max(0.0, min(1.0, confidence))
            except (TypeError, ValueError):
                confidence = 0.5
            return {
                "category": category,
                "tags": tags,
                "description_suggestion": description,
                "confidence": confidence,
            }
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"AI 返回 JSON 解析失败: {e}, text={text[:200]}")
            return AIService._fallback_recognize()

    @staticmethod
    def _fallback_recognize() -> dict[str, Any]:
        """AI 不可用时的降级识别结果。"""
        return {
            "category": "其他",
            "tags": [],
            "description_suggestion": "AI 服务暂不可用，请手动填写作品信息。",
            "confidence": 0.0,
        }

    @staticmethod
    def _fallback_report(
        work_list: list[dict[str, Any]], honor_list: list[dict[str, Any]]
    ) -> str:
        """AI 不可用时的降级报告。"""
        work_count = len(work_list)
        honor_count = len(honor_list)
        return (
            f"本阶段孩子共创作 {work_count} 件作品、获得 {honor_count} 项荣誉。"
            "每一次记录都是成长的印记，愿你继续在热爱中探索、在坚持中闪光。"
        )
