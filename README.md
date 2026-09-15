# 俄语同传（RuZhInterpreter）

把俄语语音实时翻译成汉语的 iPhone 应用。说一句俄语，屏幕上实时显示中文译文。

功能：
- 实时俄语语音识别（苹果 SFSpeechRecognizer，识别过程实时上屏）
- 俄语 → 简体中文离线翻译（苹果系统翻译框架，iOS 18+）
- 逐句显示俄语原句 + 中文译文，自动滚动
- 一键开始 / 停止 / 清空

要求：iPhone 系统版本 **iOS 18.0 或以上**。

## 没有 Mac 怎么安装到 iPhone？（三步）

整个流程在 Windows 上即可完成，不需要 Mac。

### 第 1 步：把项目上传到 GitHub 并云端编译

1. 注册 / 登录 [github.com](https://github.com)。
2. 点右上角 **+** → **New repository**，名字随便取（如 `ruzh-interpreter`），选择 **Public**（公开仓库可无限免费使用 macOS 云构建），点 **Create repository**。
3. 在仓库页面点 **uploading an existing file**，把本项目 `RuZhInterpreter` 文件夹里的**所有内容**（包括 `.github` 文件夹、`project.yml`、`RuZhInterpreter` 文件夹）拖进去上传。
   - 注意：Windows 资源管理器默认不显示 `.github` 这种以点开头的文件夹，可以先在资源管理器里打开「查看 → 显示 → 隐藏的项目」再全选。
   - 或者用 Git 命令上传：
     ```bash
     cd RuZhInterpreter
     git init
     git add .
     git commit -m "俄语同传 App"
     git remote add origin https://github.com/你的用户名/仓库名.git
     git push -u origin main
     ```
4. 上传后进入仓库的 **Actions** 页 → 若提示启用工作流则点 **I understand, enable** → 左侧选 **Build iOS App** → 右侧点 **Run workflow** → **Run workflow** 确认。
5. 等待约 5~10 分钟，任务完成后点进这次运行，在页面底部 **Artifacts** 处下载 **RuZhInterpreter-ipa**，解压得到 `RuZhInterpreter-unsigned.ipa`。

### 第 2 步：在 Windows 上用 Sideloadly 签名安装

1. iPhone 用数据线连接电脑，手机上点「信任」。
2. 如果没装过 iTunes，先去 https://www.apple.com/itunes/download/ 下载安装 Windows 版 iTunes（提供手机驱动）。
3. 下载安装 [Sideloadly](https://sideloadly.io)。
4. 打开 Sideloadly：
   - **Apple account** 填你的 Apple ID（普通免费账号即可）；
   - 把 `RuZhInterpreter-unsigned.ipa` 拖进窗口；
   - 点 **Start**，等待签名并自动安装到手机。
5. 手机上：**设置 → 通用 → VPN与设备管理**，找到你的 Apple ID 开发者描述文件，点 **信任**。

### 第 3 步：打开 App 并授权

1. 打开「俄语同传」App。
2. 首次使用会依次弹出**语音识别**和**麦克风**权限，都点「允许」。
3. 点红色麦克风按钮开始。第一次翻译时如果提示翻译模型未下载，先打开系统自带**「翻译」App**，添加俄语和简体中文语言包，再回来用。

## 重要须知（免费 Apple ID 限制）

- 免费 Apple ID 签名的 App **7 天有效期**，到期后连上电脑用 Sideloadly 重新签一次即可（数据不丢）。
- 一个免费 Apple ID 最多同时签 3 个 App。
- 俄语语音识别走苹果服务器，需要手机联网；识别质量与语速、口音有关。
- 中文翻译模型下载后可离线使用。
- 如果你的 iPhone 是 iOS 17.4 ~ 17.x，把 `project.yml` 中 `iOS: "18.0"` 改成 `"17.4"` 后重新构建也能用，但建议直接用 iOS 18。

## 技术栈

- SwiftUI + `@Observable`（iOS 18）
- `AVAudioEngine` + `SFSpeechRecognizer`（locale `ru-RU`，实时部分结果，逐句切分）
- `Translation` 框架 `TranslationSession`（`ru` → `zh-Hans`，系统离线翻译模型）

## 项目结构

```
RuZhInterpreter/
├── project.yml                     # XcodeGen 工程定义
├── .github/workflows/build-ios.yml # GitHub Actions 云端打包
└── RuZhInterpreter/
    ├── RuZhInterpreterApp.swift    # App 入口
    ├── ContentView.swift           # 界面
    └── InterpreterModel.swift      # 语音识别 + 翻译核心逻辑
```
