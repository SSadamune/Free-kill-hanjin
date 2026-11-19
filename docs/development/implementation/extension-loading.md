# 扩展加载与新核心布局

本文记录 qiao 扩展在 `packages/freekill-core` 新核心布局下的 `postLoad` 工作目录问题及修复。它属于引擎接口与接线说明，不改变游戏规则。

## 背景

新月杀 v0.5.25 同时支持两种扩展布局：

- 旧布局：核心的 `lua/`、`ltk/` 位于运行时根目录，标准包位于 `packages/standard` 等目录。
- 新布局：核心作为 `packages/freekill-core` 安装，标准包也位于该目录内。

`lua/core/mod_manager.lua` 的 `loadPackages` 在检测到当前工作目录位于 `packages/freekill-core` 时，会先 `FileIO.cd("../..")` 回到运行时根目录，再逐个加载 `packages/` 下的扩展；加载结束后，为了后续流程，会执行 `FileIO.cd("packages/freekill-core")` 回到核心目录。

扩展包的 `init.lua` 在 `loadPackages` 期间执行，此时工作目录仍是运行时根目录；但所有 `Fk:addPostLoadFunc` 注册的回调，要等 `loadPackages` 返回后才由 `lua/freekill.lua` 调用。此时工作目录已经被切回 `packages/freekill-core`。

## 现象

使用新核心布局启动客户端或服务端时，qiao 的 `postLoad` 会报类似错误：

```text
./packages/qiao/pkg/qiao_generals/init.lua:243: module
'packages.qiao.pkg.qiao_mode.rules.skill_source_labels' not found:
  no file './packages/qiao/pkg/qiao_mode/rules/skill_source_labels.lua'
  ...
```

对应文件实际存在。错误路径中的 `.` 不是运行时根目录，而是 `packages/freekill-core`，所以相对模块名被解析成 `packages/freekill-core/packages/qiao/...`。

## 不能直接修改 `package.path`

引擎在 `lua/freekill.lua` 中把全局 `package` 置空，作为扩展沙箱的一部分。扩展里使用 `package.path` 会直接报 `attempt to index a nil value (global 'package')`。因此不能通过给 `package.path` 追加根目录来修。

## 修复

在项目顶层 `init.lua` 中按回调注册顺序处理：

1. qiao 包加载时（工作目录仍是运行时根目录）记录 `extension_root = FileIO.pwd()`。锁定版本中 `FileIO.pwd` 对应 `QmlBackend::pwd()`，返回绝对路径。
2. qiao 的第一个 `postLoad` 回调保存引擎当前工作目录，并 `FileIO.cd(extension_root)`。
3. 在全部 qiao 子包 `require` 完成之后，注册最后一个 qiao 回调，恢复第 2 步保存的工作目录。

```lua
local extension_root = FileIO.pwd()
local post_load_cwd

Fk:addPostLoadFunc(function()
  post_load_cwd = FileIO.pwd()
  FileIO.cd(extension_root)
  -- qiao 的扩展排序等原有逻辑
end)

local packages = {
  (require "packages.qiao.pkg.qiao_generals"),
  (require "packages.qiao.pkg.qiao_bingqing"),
  (require "packages.qiao.pkg.qiao_buchen"),
  (require "packages.qiao.pkg.qiao_zongheng"),
  (require "packages.qiao.pkg.qiao_cards"),
  (require "packages.qiao.pkg.qiao_mode"),
}

Fk:addPostLoadFunc(function()
  if post_load_cwd then
    FileIO.cd(post_load_cwd)
    post_load_cwd = nil
  end
end)

return packages
```

这样 qiao 的 `postLoad` 在扩展根目录执行，`require("packages.qiao...")` 和 `require("packages.hegemony...")` 都能按运行时根目录解析；最后恢复引擎原来的目录，交给在 qiao 之后加载的扩展（如 `utility`）使用。

没有逐处修改 `postLoad` 中的 `require`，原因是这些调用分散在 `qiao_generals`、`qiao_bingqing`、`qiao_mode`、`qiao_cards` 及多个技能模块中，逐处改动范围更大且容易遗漏。也没有修改 `ModManager` 或上游运行时：项目按 `dependencies.lock.json` 锁定 v0.5.25，修复保持在扩展侧。

## 生效范围

- 只修改项目顶层 `init.lua`；不修改 `.dev/` 中的上游依赖、标准包或其他扩展。
- 覆盖 qiao 子包在 `postLoad` 中注册的模块解析，包括 generals、bingqing、mode、cards 及技能回调。
- 旧核心布局下 `postLoad` 时的工作目录本来就是运行时根目录，首尾回调保存和恢复同一路径，行为不变。

## 验证

- macOS 客户端下载并启用 `packages/freekill-core` 后启动本地服务器，`freekill.server.log` 显示：
  `[ModManager] Loaded 7 extension(s): standard, standard_cards, maneuvering, test, hegemony, qiao, utility`，以及 `440 generals`、`1004 skills`、`179 card types`，没有 `module ... not found`。
- `freekill-asio` 服务端在同一布局下加载同样的 7 个扩展，客户端登录后建房时服务端完成 qiao 的 `postLoad`，无模块解析错误。
- 复现与验收要点：在存在 `packages/freekill-core` 的运行时中加载 qiao，触发 `postLoad`；修复前出现上面的 `not found`，修复后正常加载。

现有自动化套件运行在旧核心布局的共享运行时上，不触达本问题；本次以真实客户端和服务端加载验证。如果后续需要在自动化中覆盖，可在测试夹具中模拟 `UsingNewCore` 的目录切换，或在发布前增加一条新核心布局的启动检查。

## 边界与后续

- 本修复依赖 `postLoad` 回调的注册顺序：所有 qiao 的 `postLoad` 必须在本包加载期间注册，且恢复回调最后注册。新增模块若在加载完成后延迟注册回调，会落在恢复之后，需要按同样方式处理。
- 如果上游改变 `loadPackages` 的目录恢复时机、取消 `package` 沙箱，或新增其他核心布局，需要重新核对本文。
- 本修复不涉及游戏规则、卡牌结算或玩家可见描述。
