# hyplayer

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### 创建flutter 项目

flutter create --org com.vkflow.hyplayer hyplayer
cd hyplayer
flutter run

flutter pub add video_player

## 项目目标

开发一款基于ai的儿童视频播放器
主要功能如下：
1、视频搜索（家长使用）
基于ai搜索，用自然语言描述需求，搜索相关视频，可以把需要的视频地址，添加到视频列表中
2、视频列表
从视频地址，获取视频真实mp4地址，封面，标题信息，保存到本地视频列表。
2、视频播放（单个循环，列表循环等）
在播放时，可下滑和下滑，切换视频；可设置单个循环，列表循环
