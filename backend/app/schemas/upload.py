"""上传相关响应模型。"""

from pydantic import BaseModel


class UploadResponse(BaseModel):
    """图片上传响应。"""

    url: str
    thumbnail_url: str
    file_size: int
    content_type: str
