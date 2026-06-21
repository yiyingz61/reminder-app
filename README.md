# 日程提醒 (Reminder)

一个 Flutter 手机日程提醒 app，使用 SQLite 做本地数据库持久化。

## 功能

- **我的一天（首页）**：列出选中日期的全部日程，顶部一周日期条可左右滑动切换，点击右上角日历图标可跳转任意日期；点日程卡片可编辑，右侧圆圈可勾选完成。
- **中间圆形按钮**：底部导航正中的悬浮圆形 `+` 按钮，用于新建日程（标题、日期、起止时间 / 全天、颜色标记、备注）。
- **待办**：第三个页签，列出全部待办，支持新建（标题、优先级、截止时间）、勾选完成、左滑删除。

## 数据持久化

SQLite（`sqflite`），数据库文件 `reminder.db`，两张表：

- `schedules`：日程（标题、备注、起止时间、是否全天、颜色、是否完成、day_key 索引）
- `todos`：待办（标题、是否完成、优先级、创建时间、截止时间）

数据层代码在 `lib/data/app_database.dart`。

## 项目结构

```
lib/
  main.dart                      入口 + 底部导航外壳（含中间圆形 FAB）
  theme.dart                     主题与配色
  models/schedule.dart           日程模型
  models/todo.dart               待办模型
  data/app_database.dart         SQLite 持久化层
  screens/home_screen.dart       我的一天 + 日期切换
  screens/schedule_edit_screen.dart  新建 / 编辑日程
  screens/todo_screen.dart       待办列表 + 新建
```

## 运行

本机工具链装在 `~/sdks`（Flutter 3.24.5 / JDK 17 / Android SDK）。先加载环境变量：

```bash
source ~/sdks/env.sh
cd ~/code/reminder_app
flutter pub get
flutter run            # 连接设备 / 模拟器后运行
flutter build apk      # 打包 APK
```

已验证：`flutter analyze` 无问题，widget 测试通过，debug APK 构建成功
（`build/app/outputs/flutter-apk/app-debug.apk`）。

> 注：当前环境没有模拟器或真机，APK 需要安装到 Android 设备上运行。
> 若 `flutter` 命令因首次运行的分析提示卡住，环境变量里已设 `FLUTTER_SUPPRESS_ANALYTICS=true`。
