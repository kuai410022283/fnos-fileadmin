# fnos-fileadmin

[FileAdmin](https://github.com/kuai410022283/fileadmin) 的飞牛 fnOS（fnOS）应用打包仓库。

通过 GitHub Actions 自动构建 **x86_64 + aarch64** 双架构 `.fpk` 安装包。

## 特性

- 单包支持飞牛 x86 与 ARM 设备（`platform = all`）
- FileAdmin 二进制已内嵌 Web 前端，不依赖 Node、Nginx 或独立数据库
- 以专用 `package` 用户运行，不使用 root
- 保留 FileAdmin 自身的登录、用户、ACL、分享和配额体系
- 新建/编辑文本文件（upload + edit 权限，UTF-8，最大 1MB）
- 目录存在 `README.md` 时自动在文件列表下方渲染
- 登录页不提示管理员用户名，翻页使用图标按钮
- 安装向导设置服务端口和管理员初始密码
- 数据、数据库、密钥、上传临时文件和回收站统一放在应用数据目录
- 卸载时可选保留或删除应用数据，外部存储根不会被删除

## 应用信息

| 项目 | 值 |
|---|---|
| appname | `fileadmin` |
| 显示名称 | FileAdmin |
| 版本 | `1.0.27`（`x.y.z` 三段式） |
| 架构 | `all`：`x86_64` + `aarch64` |
| 服务端口 | 安装时配置，默认 `18080` |
| 入口 | `http://NAS-IP:端口/login` |
| 运行用户 | `fileadmin` package 用户 |
| 数据目录 | `/var/apps/fileadmin/var`（由 fnOS 管理） |
| 日志 | `$TRIM_PKGVAR/fileadmin.log` |

## 安装

从 [Releases](https://github.com/kuai410022283/fnos-fileadmin/releases) 下载最新：

```text
fileadmin_all_v1.0.27.fpk
```

在飞牛 NAS：

1. 打开 **应用中心**
2. 选择 **手动安装 / 开发导入**
3. 选择 `.fpk`
4. 在安装向导中设置服务端口和 FileAdmin 管理员初始密码（默认 `admin123`，建议修改）
5. 安装完成后从桌面打开 FileAdmin
6. 登录用户名为 `admin`，密码为安装时设置的值

首次登录后：

1. 进入 **存储根** 添加要管理的目录，例如 `/vol1/1000/Documents`
2. 在飞牛应用设置中给 FileAdmin 授权该目录访问权限
3. 进入 **用户/用户组/权限** 配置普通用户和 ACL
4. 如需个人空间，在用户列表初始化空间

> FileAdmin 以 package 用户运行，无法天然访问所有 NAS 目录。添加存储根前，请先在飞牛应用权限中授权对应目录。外部目录只被读写，不会被卸载删除。

## 安装向导与目录选择

当前安装向导支持：

- **服务端口**：`wizard_port`，默认 `18080`
- **管理员初始密码**：`wizard_admin_password`，默认 `admin123`
- 数据处理方式：卸载时保留或删除应用数据

安装向导**不支持原生的目录选择器**。fnOS 的 `wizard` 字段类型只有 `text`、`password`、`radio`、`checkbox`、`select`、`switch`、`tips`，没有文件选择器类型。

因此：

- 应用自身的数据目录由 fnOS 通过 `TRIM_PKGVAR` / `TRIM_APPDEST` 管理，不需要用户选择。
- FileAdmin 管理的「存储根」在安装完成后，由管理员进入 FileAdmin 的「存储根」页面添加。
- 飞牛开放 API 的 `pickUserFile` / `pickSharedFile` 是**应用页面内**的 JS SDK 能力，需要 `micro_app=true`、`api-scope`、统一网关和用户点击触发；它不能在原生安装向导中调用。

如果后续需要“安装完首次进入应用时弹出目录选择器”，需要把 FileAdmin 前端接入飞牛微应用 SDK 和统一网关，这是下一步的集成工作。

## iframe 与 CSP

飞牛桌面通过 iframe 打开 FileAdmin。FileAdmin 默认只允许同源嵌入：

```text
frame-ancestors 'self'
```

fnOS 包在 `package/app/server/config.yaml.template` 中使用：

```yaml
server:
  frame_ancestors:
    - "'self'"
    - "*"
```

此时 FileAdmin 不再发送 `X-Frame-Options`，飞牛桌面可以正常嵌入。

如果升级后仍然看到：

```text
Framing ... violates the following Content Security Policy directive:
"frame-ancestors 'none'"
```

说明旧的 `config.yaml` 没有被升级回调更新。可以手动在：

```text
/var/apps/fileadmin/var/config.yaml
```

的 `server:` 下加入：

```yaml
  frame_ancestors:
    - "'self'"
    - "*"
```

然后重启应用。生产环境建议把 `*` 收窄为实际飞牛面板来源，例如：

```yaml
  frame_ancestors:
    - "'self'"
    - "http://nas.example.com:5666"
    - "https://nas.example.com"
```

## 自动构建

工作流：[`.github/workflows/build-fpk.yml`](.github/workflows/build-fpk.yml)

### 手动触发

在 GitHub Actions 中运行 **Build fnOS FPK**，填写：

- `fileadmin_version`：`1.0.27`
- `fileadmin_ref`：`main`，或 FileAdmin 的 tag/commit

生成：

```text
fileadmin_all_v1.0.27.fpk
fileadmin_all_v1.0.27.fpk.sha256
```

### 打 tag 触发

```bash
git tag v1.0.27
git push origin v1.0.27
```

工作流会构建 `.fpk` 并创建 GitHub Release。

### 工作流做了什么

1. 从 `kuai410022283/fileadmin` 拉取指定 ref 的源码
2. 使用 Go 1.26.9 交叉编译 Linux `amd64` 和 `arm64`
3. 将二进制放入 `package/app/server/`
4. 更新 manifest 版本
5. 下载并运行飞牛 `fnpack`
6. 生成 `fileadmin_all_v<version>.fpk`
7. 上传构建产物；tag 构建额外创建 Release

## 一键本地打包

本地需要 Go 1.26.9+ 与网络访问（用于自动下载 fnpack）。

### Windows

把 FileAdmin 源码放在本仓库同级 `..\fileAdmin`，或设置源码目录：

```bat
set FILEADMIN_SRC=D:\path\to\fileAdmin
build-local.bat
```

### Linux / macOS

```bash
export FILEADMIN_SRC=/path/to/fileAdmin
./build-local.sh
```

脚本会自动：

1. 读取 `package/manifest` 中的版本号
2. 交叉编译 `linux/amd64` 和 `linux/arm64`
3. 下载对应平台的 fnpack
4. 生成 `fileadmin_all_v1.0.27.fpk`
5. 生成 `.sha256`

## 手动打包（可选）

准备两个 Linux 二进制：

```bash
# 在 FileAdmin 源码目录
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags "-s -w -X main.version=v1.0.27" \
  -o /path/to/fnos-fileadmin/package/app/server/fileadmin_x86_64 \
  ./cmd/fileadmin

CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
  go build -trimpath -ldflags "-s -w -X main.version=v1.0.27" \
  -o /path/to/fnos-fileadmin/package/app/server/fileadmin_aarch64 \
  ./cmd/fileadmin
```

下载 fnpack：

```bash
curl -fL -o fnpack \
  https://static2.fnnas.com/fnpack/fnpack-1.2.3-linux-amd64
chmod +x fnpack
```

打包：

```bash
./build.sh
```

生成：

```text
fileadmin_all_v1.0.27.fpk
```

## 目录结构

```text
.
├── .github/workflows/build-fpk.yml
├── build.sh
├── build-local.sh
├── build-local.bat
├── package
│   ├── manifest
│   ├── ICON.PNG
│   ├── ICON_256.PNG
│   ├── app
│   │   ├── server
│   │   │   ├── config.yaml.template
│   │   │   └── fileadmin_x86_64 / fileadmin_aarch64
│   │   └── ui
│   │       ├── config
│   │       └── images/icon_64.png, icon_256.png
│   ├── config
│   │   ├── privilege
│   │   └── resource
│   ├── cmd
│   │   ├── main
│   │   ├── install_callback
│   │   ├── upgrade_callback
│   │   ├── uninstall_callback
│   │   └── ...
│   ├── wizard
│   │   ├── install
│   │   ├── uninstall
│   │   └── config
│   └── i18n
│       ├── zh-CN
│       └── en-US
└── README.md
```

## 上架自查对应

| 飞牛要求 | 本包处理 |
|---|---|
| 不允许 root 应用 | `config/privilege` 使用 `run-as: package` |
| 鉴权优先统一网关；监听端口必须有自己的鉴权 | 使用端口服务，FileAdmin 自带登录、JWT、ACL；无免鉴权 API |
| `platform=x86/arm/all` | `platform=all`，实际包含 x86_64 与 aarch64 二进制 |
| 文件读写路径安全 | FileAdmin 服务端规范化路径、拒绝目录穿越、软链逃逸防护 |
| 付费声明 | 本应用免费，无付费功能 |
| 版本号三段式 | manifest 中为 `1.0.27`，工作流强制校验 `x.y.z` 或 `x.y.z-m` |
| 应用名称不得以飞牛开头 | 名称为 `FileAdmin`，appname 为 `fileadmin` |

## 说明与边界

- 当前使用 **端口服务**，未接入飞牛统一网关。FileAdmin 前端使用绝对路径和独立端口，接入网关需要额外的 base-path 适配；端口模式通过 FileAdmin 自身鉴权满足“不可免鉴权访问”。
- FileAdmin 目前是单进程应用，SQLite 数据库和上传会话保存在应用数据目录。
- 应用安装包不包含外部存储目录；用户数据需在飞牛应用权限中授权。
- 首次启动后会清空配置中的 `bootstrap_password`，只保留密码哈希在数据库中。

## 相关链接

- [FileAdmin 主仓库](https://github.com/kuai410022283/fileadmin)
- [飞牛应用开发文档](https://developer.fnnas.com/docs/guide/)
- [fnpack 文档](https://developer.fnnas.com/docs/cli/fnpack/)
- [统一网关文档](https://developer.fnnas.com/docs/core-concepts/gateway-registration/)

## 许可

Apache License 2.0，详见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
