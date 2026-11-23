# 发布或更新 GitHub 审阅意见

- 面向在 GitHub 上阅读的作者撰写正文，按要求注明署名，采用指定的语言和格式。写清当前结论和证据，让读者仅凭评论即可理解。确有必要引用早先的审阅时，给出链接，并注明作者或日期。代码证据链接到实际审阅的提交 SHA 和对应行。需要作者同步处理的文件或流程须与发现有关，路径和改动范围应先核实。用户要求总结修改时，按指定提交范围和行为归纳。给出代码建议时，提供最小相关差分，示例差分要注明用途。
- 发布前确认仓库、PR 编号和当前头提交。头提交变动时重新核对受影响的发现和行号。总体意见发到 PR 时间线。用户要求把多条行内意见合成一次审阅时，使用 `COMMENT`。编辑或回复时定位原有评论或讨论。`APPROVE`、`REQUEST_CHANGES` 和解决讨论各有对应操作。行内意见应绑定实际审阅的提交，按当前差分确认路径、左右侧和行号。回复行内讨论时使用该讨论首条评论的 ID。 [GitHub 审阅操作](https://docs.github.com/en/pull-requests/concepts/giving-reviews) · [行内评论接口](https://docs.github.com/en/rest/pulls/comments)
- 使用支持本次授权写入操作的连接器。若此前的权限拒绝仍适用于当前连接器和仓库，且访问权限未变，在获准时切换到已认证的 CLI。多行 Markdown 保存为 UTF-8 文件，用 `gh pr comment <number> --repo <owner/repo> --body-file <file>` 发布。行内审阅按需用 `gh api --input` 提交结构化 JSON。编辑前核对原作者、对象类型和准确 ID。 [CLI 评论命令](https://cli.github.com/manual/gh_pr_comment) · [CLI API 命令](https://cli.github.com/manual/gh_api) · [时间线评论接口](https://docs.github.com/en/rest/issues/comments) · [审阅接口](https://docs.github.com/en/rest/pulls/reviews)
- 区分沙箱网络受限、凭据无效和 GitHub 权限不足。已获用户授权的网络操作需要额外权限时，按当前环境的审批机制处理。已有适用的登录会话且操作结果可核验时，可用浏览器作为备选。再次尝试只会遇到相同失败时，说明具体阻塞或交付完整草稿。
- 写入前检查目标是否已有相同内容。超时或结果不明时，先回读目标时间线、审阅或讨论，再决定是否重试。发布后核对结果并返回链接。用户接管发布或发布受阻时，给出可完整复制的 Markdown，并明确当前是待发布草稿还是已发布内容。
