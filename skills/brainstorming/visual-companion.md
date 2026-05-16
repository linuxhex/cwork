# Visual Companion (cwork)

在 cwork 中，视觉伴侣主要用于展示跨工程流程图、调用链、状态推进图，而不是 UI 设计。

推荐视觉输出：
- init -> brainstorming -> writing-plans -> executing-plans -> loop-refined -> commit-code
- 主工程与依赖工程契约变化图
- round 问题收敛趋势图

## 启停命令
- 启动：`bash skills/brainstorming/scripts/start-server.sh`
- 停止：`bash skills/brainstorming/scripts/stop-server.sh`
- 生成状态：`bash skills/brainstorming/scripts/build-visual-state.sh ...`
