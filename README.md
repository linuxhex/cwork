# superpowers-lite-zh

精简版多工程研发工作流 skills。

## Skills
- `init`: 初始化主工程/依赖工程、强制切分支、生成并拆分需求文档。
- `brainstorming`: 需求澄清与跨工程影响分析。
- `writing-plans`: 可执行计划拆分与验证门禁。
- `executing-plans`: 按计划实施并驱动修复闭环。
- `logic-review-loop`: 大范围逻辑推演 -> 修复 -> 再推演循环。

## init 脚本

```bash
bash skills/init/scripts/init_requirement_workspace.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --feature-branch <feature_...> \
  --requirement-key <lowercase_underscore_key> \
  --requirement-title "<需求标题>"
```

初始化后会生成：
- 主工程：`docs/requirements/<key>/00-05*.md` + `dependencies/*`
- 依赖工程：`docs/requirements/<key>/00/01/02/99*.md`
