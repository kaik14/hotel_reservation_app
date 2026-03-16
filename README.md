# Hotel Reservation App

A Flutter application for hotel discovery and reservation workflows. This repository contains the mobile app code and related assets.

## Highlights

- Built with Flutter (Dart)
- Firebase authentication and Firestore support
- Stripe payment support
- Rich media experiences (video, 3D models, panorama)
- PDF/printing utilities

## Tech Stack

- Flutter SDK
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Payments: `flutter_stripe`
- Media/UI: `video_player`, `model_viewer_plus`, `panorama_viewer`, `flutter_staggered_grid_view`
- Utilities: `intl`, `shared_preferences`, `pdf`, `printing`, `confetti`

## Project Structure

- `lib/` Flutter app source
- `assets/` images, videos, models
- `android/`, `ios/` native platform projects
- `test/` tests

## Getting Started

1. Install Flutter SDK (3.9.2 or compatible).
2. Install dependencies:

```bash
flutter pub get
```

3. Configure Firebase for your app:
- Add `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS)
- Ensure Firebase project settings match your app IDs

4. Configure Stripe keys (if used in your environment).

5. Run the app:

```bash
flutter run
```

## Build

```bash
flutter build apk
flutter build ios
```

## Test

```bash
flutter test
```

---

# 酒店预订应用

这是一个用于酒店发现与预订流程的 Flutter 应用仓库，包含移动端代码及相关资源。

## 亮点

- 基于 Flutter（Dart）开发
- 支持 Firebase 登录与 Firestore 数据
- 支持 Stripe 支付
- 富媒体体验（视频、3D 模型、全景）
- PDF/打印功能

## 技术栈

- Flutter SDK
- Firebase：`firebase_core`、`firebase_auth`、`cloud_firestore`
- 支付：`flutter_stripe`
- 媒体与 UI：`video_player`、`model_viewer_plus`、`panorama_viewer`、`flutter_staggered_grid_view`
- 工具：`intl`、`shared_preferences`、`pdf`、`printing`、`confetti`

## 项目结构

- `lib/` Flutter 源码
- `assets/` 图片、视频、模型
- `android/`、`ios/` 原生工程
- `test/` 测试

## 快速开始

1. 安装 Flutter SDK（3.9.2 或兼容版本）。
2. 安装依赖：

```bash
flutter pub get
```

3. 配置 Firebase：
- 添加 `google-services.json`（Android）和/或 `GoogleService-Info.plist`（iOS）
- 确保 Firebase 项目与应用包名一致

4. 配置 Stripe 密钥（如果你的环境需要）。

5. 运行应用：

```bash
flutter run
```

## 构建

```bash
flutter build apk
flutter build ios
```

## 测试

```bash
flutter test
```
