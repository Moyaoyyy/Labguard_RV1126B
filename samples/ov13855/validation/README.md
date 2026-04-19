# OV13855 Validation Captures

该目录用于保存 Phase 2A 的少量验证性抓图，不作为正式数据集目录。

默认产物:

- `*.yuv` 或 `*.raw`: 原始单帧验证图
- `*.jpg`: 可选预览图
- `*.json`: 每张验证图的 sidecar 元数据
- `manifest.jsonl`: 全部验证抓图的汇总清单

说明:

- 这些文件由 `scripts/camera_capture.sh baseline-shot` 或 `baseline-series` 生成
- 产物仅用于安装确认、分辨率对比、图像质量基线和参数摸底
- 仓库默认只保留目录说明，不提交验证抓图二进制和运行期 manifest

执行约束:

- 真实采图必须在 `RV1126B` 板端执行
- `controls` / `apply-preset` / `baseline-shot` / `baseline-series` / `stress` 现在要求 `mount_baseline` 已冻结
- 若支架、角度、工作距离或视野覆盖发生变化，当前目录下已有结论全部失效，应重新生成

推荐目录形态:

```text
validation/
├─ manifest.jsonl
├─ empty_workbench/
├─ center_marker/
├─ bright_object/
├─ dark_object/
├─ reflective_object/
└─ edge_coverage/
```

单轮 Phase 2A 推荐场景:

- `empty_workbench`
- `center_marker`
- `bright_object`
- `dark_object`
- `reflective_object`
- `edge_coverage`

每个场景固定采 `3` 张。若从空目录开始做完整一轮，应新增:

- `18` 个原始验证图文件
- `18` 个 sidecar JSON
- `18` 条 `manifest.jsonl` 记录
- 可选 `18` 张预览 JPG

本轮完成后建议立即检查:

```bash
wc -l samples/ov13855/validation/manifest.jsonl
find samples/ov13855/validation -name '*.json' | wc -l
find samples/ov13855/validation -mindepth 1 -maxdepth 1 -type d | sort
```

通过条件:

- `manifest.jsonl` 行数为 `18`
- sidecar JSON 数量为 `18`
- 存在以下 `6` 个场景目录
  - `empty_workbench`
  - `center_marker`
  - `bright_object`
  - `dark_object`
  - `reflective_object`
  - `edge_coverage`

sidecar / manifest 只负责记录采集事实，不负责记录人工观察结论。以下观察项需要同步写入文档或实验记录:

- 工位中心清晰度
- 工位边缘可见性
- 高亮物体轮廓
- 深色物体边界
- 反光表面曝光稳定性
- 自动曝光与自动白平衡恢复速度
