# 汉晋 PR 审阅约定

审阅、复检和发布按 [pr-review skill](../../.agents/skills/pr-review/SKILL.md)执行。本页保留汉晋特有的证据来源、测试取舍和回复偏好。

## 审阅和验证

- `审阅 #N` 在 PR 语境中指本仓库。`可以切分支`按有需要时切换，`新建工作树`按指示创建，`不要拉到本地`则用远端材料和现有只读资料。素材审阅限定不读图片时，检查文件名、程序 ID、加载路径和构建记录即可。
- 涉及武将、卡牌及规则交互时，按 [hanjin-content-development](../../.agents/skills/hanjin-content-development/SKILL.md)核对卡面原文、`rulebook/` 对应条文、已确认的汉晋差异及锁定版引擎。项目裁定决定应有行为，实际代码决定现行行为。沿实际使用入口查到回调、公共接口和执行端，关注事件数据、选牌与执行、公开候选与服务端校验、技能归属和清理。
- 遇到未决规则，先用一个具体场景问清两种结算；确认后将撤回意见从拟发评论移除。横向核对公共规则至少看一个同类分支。仅审阅或仅评论时，在回复中给出已核实的规则写回位置。发评论前核对提到的文档存在、职责相符，项目术语准确。
- PR 审阅默认复用已有有效测试结果，针对真实缺口补定向验证。全量验收的开发要求见[测试规范](testing.md)，用户明确跳过时停止本轮全量。共享 `.dev/runtime` 只由指定执行者同步或运行，避免占用其它任务的环境。涉及正式加载时核对安装包接线。

## 对外回复

- 使用「**Codex 自动回复**」开头，列作者实际要处理的事项、具体场景和依据。常规合并冲突、静态检查通过、已确认维持原状的内容通常省略。若用户要求暂缓，说明待确认的行为和已同意的公共实现方向。
- 涉及规则差异时链接对应条文和已确认项目裁定。按实际影响提醒作者同步实现、相关回归和对应文档。多份 PR 改同一行为时说明各自应改范围及哪个提交已进入目标分支。修改原评论时按用户指定的提交范围和功能归纳。
- 本仓库曾出现连接器读成功但写入 `403`，本机 `gh` 在获准环境中能够发布。沙箱内 `gh auth status` 的无效 token 提示曾与实际网络访问失败同时出现。按 [GitHub 发布参考](../../.agents/skills/pr-review/references/github-feedback.md)区分错误并选择通道。发布后回读并给出评论链接。用户接管或渠道受阻时，交付完整 Markdown 草稿和发布状态。

## 近期复盘

| 案例 | 对审阅流程的影响 |
| --- | --- |
| [#11 素材导入](https://github.com/SSadamune/Free-kill-hanjin/pull/11)、[#45 房间设置](https://github.com/SSadamune/Free-kill-hanjin/pull/45) | #11 通过文件清单与测试记录发现构建证据属于旧版本，省去了读取图片内容。#45 用有无联动开关的两种设置表覆盖差异，按用户要求停掉额外的全量测试。 |
| [#22 加载回调](https://github.com/SSadamune/Free-kill-hanjin/pull/22#issuecomment-7008759995)、[#34 阵法召唤](https://github.com/SSadamune/Free-kill-hanjin/pull/34#issuecomment-7060657561) | 分别追到锁定引擎的异常恢复和客户端标题显示。区分模拟回调、离屏 Qt 与真实对局。阵法两侧重合时的询问次数经用户确认后才定性。 |
| [#38 结算修订](https://github.com/SSadamune/Free-kill-hanjin/pull/38#issuecomment-7079279936)、[#47 通用消耗](https://github.com/SSadamune/Free-kill-hanjin/pull/47#issuecomment-7080477190) | 根据用户裁定撤回【奇策】限制外部追加目标的意见。【转蓬】复检用【玉玺】揭示了【赤霄剑】特例，修复方向应体现通用消耗裁定。 |
| [#35 逐将规则](https://github.com/SSadamune/Free-kill-hanjin/pull/35)、[#40 FAQ](https://github.com/SSadamune/Free-kill-hanjin/pull/40)、[#43 牌类标记](https://github.com/SSadamune/Free-kill-hanjin/pull/43#issuecomment-7091804767) | 分清武将弃牌堆、禁用列表与弃牌堆，并核实通用移除、变更和客将重抽各走哪条路径。规则分歧要给准确原文。共享机制需求未明时，可以先说明暂缓和日后统一处理的范围。 |
| [#36 正式审阅](https://github.com/SSadamune/Free-kill-hanjin/pull/36#pullrequestreview-6015846630)、[#37 原评论](https://github.com/SSadamune/Free-kill-hanjin/pull/37#issuecomment-7066880438) | #36 的连接器拒绝写入，本机 `gh` 发布成功。正式审阅正文随后删掉了常规冲突、静态检查及不必要的旧意见。#37 按用户指定的提交范围，在原评论中按功能综合实际修复。 |
| [#35 评论草稿](https://github.com/SSadamune/Free-kill-hanjin/pull/35) | 连接器无法写入，浏览器尝试多次后只留下草稿。用户接手并要求一键复制全文。遇到同类阻塞时及时切换到可用通道，或一次交付完整正文及真实发布状态。 |
