from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
import httpx
from pydantic import BaseModel
from urllib.parse import quote

app = FastAPI()

@app.get("/proxy")
async def proxy_video(url: str):
    if not url:
        raise HTTPException(status_code=400, detail="Missing URL parameter")

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    ,
        # 某些网站可能需要 Referer，可以根据需要添加
        # 'Referer': 'https://www.google.com/' 
    }

    async def stream_generator():
        # 在 AsyncClient 中设置 follow_redirects=True
        async with httpx.AsyncClient(follow_redirects=True) as client:
            try:
                # 使用 client.stream 发起请求
                async with client.stream("GET", url, headers=headers, timeout=30) as response:
                    # 检查目标服务器是否成功响应
                    response.raise_for_status()

                    # 流式读取并yield数据块
                    async for chunk in response.aiter_bytes():
                        yield chunk
            except httpx.RequestError as e:
                # 处理请求过程中的网络错误
                print(f"An error occurred while requesting {e.request.url!r}: {e}")
                # 在生成器中不能直接返回HTTPException，这里可以选择不产出任何内容，让前端超时或显示错误
                # 或者可以尝试产出一个表示错误的特定消息，但前端需要能解析它
                return
            except httpx.HTTPStatusError as e:
                # 处理服务器返回的错误状态码 (4xx or 5xx)
                print(f"Error response {e.response.status_code} while requesting {e.request.url!r}.")
                return

    # 为了获取正确的 Content-Type，我们需要先发一个 HEAD 请求
    # 这有助于播放器正确识别视频格式
    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            head_response = await client.head(url, headers=headers)
            head_response.raise_for_status()
            content_type = head_response.headers.get('content-type', 'video/mp4')
    except Exception as e:
        print(f"Could not get Content-Type with HEAD request: {e}. Falling back to default.")
        content_type = 'video/mp4' # 如果HEAD请求失败，提供一个默认值

    return StreamingResponse(stream_generator(), media_type=content_type)

class VideoParseRequest(BaseModel):
    url: str

@app.post("/api/parse_video")
async def parse_video(request: VideoParseRequest):
    """
    接收一个分享链接，通过调用外部解析服务来获取视频信息。
    """
    shared_url = request.url
    # 对 shared_url 进行encode处理,防止参数丢失
    encoded_url = quote(shared_url, safe='')
    parse_service_url = f"http://192.168.1.2:8000/video/share/url/parse?url={encoded_url}"

    print(f"Forwarding parse request for {shared_url} to {parse_service_url}")

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(parse_service_url, timeout=60)
            response.raise_for_status()

            response_data = response.json()
            print(f"Received data from parse service: {response_data}")

            # 检查返回码是否成功
            if response_data.get('code') != 200:
                raise HTTPException(status_code=400, detail=response_data.get('msg', '解析服务返回失败'))

            # 提取核心数据
            data = response_data.get('data')
            if not data:
                raise HTTPException(status_code=404, detail="解析服务未返回有效数据")

            video_url = data.get('video_url')
            if not video_url:
                raise HTTPException(status_code=400, detail="解析成功，但未找到有效的视频播放地址。")

            # 提取标题
            title = data.get('title', '无标题')

            # 提取封面，带备选方案
            cover_url = data.get('cover_url')
            if not cover_url:
                author_info = data.get('author')
                if author_info and isinstance(author_info, dict):
                    cover_url = author_info.get('avatar')
            
            # 如果最后还是没有封面，给一个默认的
            if not cover_url:
                cover_url = f"https://via.placeholder.com/150/000000/FFFFFF/?text={title[:10]}"

            return {
                "title": title,
                "coverUrl": cover_url,
                "videoUrl": video_url
            }

        except httpx.HTTPStatusError as e:
            print(f"Error from parse service: {e.response.status_code} - {e.response.text}")
            try:
                error_detail = e.response.json().get("detail", "解析服务内部错误")
            except Exception:
                error_detail = f"解析服务出错，状态码: {e.response.status_code}"
            raise HTTPException(status_code=e.response.status_code, detail=error_detail)
        
        except httpx.RequestError as e:
            print(f"Failed to connect to parse service: {e}")
            raise HTTPException(status_code=502, detail=f"无法连接到视频解析服务: {e}")
        
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            raise HTTPException(status_code=500, detail=f"处理请求时发生未知错误: {e}")