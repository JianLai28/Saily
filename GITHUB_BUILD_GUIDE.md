# GitHub 编译指导文档

## 在 GitHub 上编译 Saily RootHide 版本

### 方法一：使用 GitHub Actions（推荐）

#### 1. 手动触发编译
1. 访问你的 GitHub 仓库
2. 点击 **Actions** 选项卡
3. 选择 **Build RootHide Release** 工作流
4. 点击 **Run workflow** 按钮
5. 选择分支（通常是 main 或 master）
6. 点击 **Run workflow** 开始编译

#### 2. 通过标签触发发布
1. 创建并推送标签：
   ```bash
   git tag v3.0.0-roothide
   git push origin v3.0.0-roothide
   ```
2. 推送后会自动触发编译并创建 Release

### 方法二：使用现有工作流

项目已经配置了以下 GitHub Actions 工作流：

- **Build Release** (`build.yml`) - 使用 rootless 脚本
- **Build RootHide Release** (`build-roothide.yml`) - 使用 roothide 脚本

### 编译环境配置

#### GitHub Actions 环境
- **操作系统**: macOS 13 (macos-13)
- **Xcode**: 14.2
- **Swift**: 5.9+
- **依赖**: ldid, xz, dpkg, coreutils

#### 本地验证（可选）
在本地测试编译前，可以在 GitHub Actions 中测试：

1. 创建测试分支：
   ```bash
   git checkout -b test-build
   git push origin test-build
   ```

2. 在 GitHub 上手动触发该分支的编译

### 编译产物

编译完成后，你可以在以下位置找到产物：

1. **Artifacts**: 在 Actions 页面查看编译任务的 Artifacts
2. **Releases**: 如果通过标签触发，会在 Releases 页面找到
3. **文件位置**: `*.deb` 格式的 iOS 安装包

### 故障排除

#### 编译失败常见原因
1. **依赖问题**: 检查 Package.swift 文件中的 Swift 工具版本
2. **权限问题**: 确保 GitHub Actions 有正确的权限
3. **网络问题**: 检查依赖包是否能正常下载

#### 调试方法
1. 查看 Actions 日志
2. 检查失败步骤的详细输出
3. 在本地复现问题（需要 macOS 13+ 和 Xcode 14+）

### 自定义编译

#### 修改编译参数
编辑 `.github/workflows/build-roothide.yml` 文件：

```yaml
# 修改 Xcode 版本
sudo xcode-select --switch /Applications/Xcode_15.0.app

# 修改运行环境
runs-on: macos-14

# 添加自定义参数
- name: Build with custom options
  run: |
    Resources/compile.release.roothide.sh clean
```

#### 添加环境变量
```yaml
env:
  CUSTOM_BUILD_NUMBER: ${{ github.run_number }}
  BUILD_TYPE: ${{ github.ref_name }}
```

### 安全注意事项

1. **密钥管理**: 使用 GitHub Secrets 存储敏感信息
2. **权限控制**: 限制 Actions 的权限范围
3. **审计日志**: 定期检查 Actions 日志

### 相关文件

- `.github/workflows/build.yml` - 现有 rootless 编译配置
- `.github/workflows/build-roothide.yml` - roothide 编译配置
- `Resources/compile.release.roothide.sh` - 编译脚本
- `GITHUB_BUILD_GUIDE.md` - 本文档

### 支持

如有编译问题，请：
1. 检查 GitHub Actions 日志
2. 创建 Issue 并提供详细错误信息
3. 参考现有工作流的配置