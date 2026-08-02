"""文件上传路由。"""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status

from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.upload import UploadResponse
from app.services.storage_service import ALLOWED_IMAGE_TYPES, get_storage

router = APIRouter(prefix="/upload", tags=["上传"])

# 最大文件大小 10MB
MAX_FILE_SIZE = 10 * 1024 * 1024


@router.post("/image", response_model=ApiResponse[UploadResponse])
async def upload_image(
    file: UploadFile,
    current_user: User = Depends(get_current_user),
):
    """上传图片文件。

    - 校验文件类型（jpg/png/webp/gif）
    - 校验文件大小（<=10MB）
    - 自动生成缩略图（300x300 等比缩放）
    - OSS 未配置时使用本地存储兜底
    """
    # 类型校验
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支持的文件类型: {file.content_type}，仅支持 jpg/png/webp/gif",
        )

    # 读取并校验大小
    data = await file.read()
    if len(data) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="文件大小超过 10MB 限制",
        )

    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="文件内容为空"
        )

    # 保存文件
    storage = get_storage()
    url, thumbnail_url = await storage.save(data, file.filename or "upload", file.content_type)

    return ApiResponse(
        data=UploadResponse(
            url=url,
            thumbnail_url=thumbnail_url,
            file_size=len(data),
            content_type=file.content_type,
        )
    )
