# 记一笔

一款简洁好用的纯离线个人记账APP，基于 Flutter 开发。

## 功能特性

- **多账本管理** - 支持创建多个账本，灵活管理不同场景的收支
- **分类记账** - 内置常用支出/收入分类，支持自定义分类、图标和颜色
- **预算管理** - 为每个分类设置月度预算，超支自动预警
- **数据可视化** - 饼图、条形图、趋势图多种图表展示收支情况
- **图表配色** - 支持自定义每个分类的图表颜色
- **数据备份与恢复** - 支持手动/自动备份，加密保护，一键恢复
- **数据导出** - 支持导出 CSV 和 Excel 格式
- **深色模式** - 支持白天/黑夜/跟随系统三种主题
- **自定义背景** - 支持纯色背景和自定义图片背景
- **完全离线** - 所有数据存储在本地，无需联网，保护隐私

## 下载安装

### 方式一：GitHub Releases（推荐）

1. 打开本项目的 [Releases 页面](https://github.com/Xiaoyang2233/personal-bill-app/releases)
2. 下载最新版本的 `记一笔_v1.1.4.apk` 文件
3. 在手机上打开下载的 APK 文件，按提示安装即可

> 注意：安装前需要在手机设置中允许「安装未知来源应用」

### 方式二：从源码构建

```bash
# 克隆项目
git clone https://github.com/Xiaoyang2233/personal-bill-app.git

# 进入项目目录
cd personal-bill-app

# 获取依赖
flutter pub get

# 构建 APK
flutter build apk --release
```

构建完成后，APK 文件位于 `build/app/outputs/flutter-apk/app-release.apk`

## 技术栈

- **框架**: Flutter
- **数据库**: SQLite (sqflite)
- **状态管理**: Provider
- **图表**: fl_chart
- **最低支持**: Android 5.0 (API 21)

## 联系开发者

- QQ: 3606898583
- GitHub: [Xiaoyang2233](https://github.com/Xiaoyang2233)

## 许可证

本项目仅供学习和个人使用。
