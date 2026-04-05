# Camera Engineering Baseline

## 1. 目标

Phase 2A 的目标从“主相机工程化”收敛为“主相机可用数据基线”。

当前不是做正式数据集建设，而是把 OV13855 从“能出图”推进到“能稳定、可重复、带元数据地为后续视觉任务供数”。

## 2. 当前默认基线

### 2.1 主工作档

- `main_profile=preview`
- `video_node=/dev/video23`
- `width=1920`
- `height=1080`
- `pixfmt=NV12`
- `fps=30`
- `stream_skip=10`

该档位继续作为默认起点，只有在更高分辨率候选同时满足“细节更好、300 帧无异常、处理成本可接受”时才替换。

### 2.2 Raw 调试档

- `profile=raw_debug`
- `video_node=/dev/video1`
- `width=4224`
- `height=3136`
- `pixfmt=BG10`

保留原因:

- 用于 raw 链路核查
- 用于 ISP 路径与 sensor/CIF 路径的分界排查
- 不作为下游默认输入档

### 2.3 固定安装与验证抓图

- `mount_id=workbench_main_v1`
- `status=fixed`
- `orientation=landscape`
- `height_mm/tilt_deg/work_distance_mm=pending_measurement`
- `validation_root=samples/ov13855/validation`
- `manifest=samples/ov13855/validation/manifest.jsonl`

说明:

- 任何安装形态变化都视为使当前调参结论失效
- 允许少量验证性抓图，不做正式数据集采集

### 2.4 Presets

- `auto_baseline`: 自动模式参考档，允许等价于 no-op
- `workbench_balanced`: 固定工位主候选 preset
- `workbench_lowlight`: 实验 preset，默认禁用，待低照度验证再启用

## 3. 统一脚本入口

使用 `scripts/camera_capture.sh` 管理主相机信息查询、控制项摸底、preset 应用与验证抓图。

支持子命令:

- `info`
- `preview`
- `oneshot`
- `stress`
- `controls`
- `apply-preset`
- `baseline-shot`
- `baseline-series`

示例:

```bash
bash scripts/camera_capture.sh info preview
bash scripts/camera_capture.sh controls preview
bash scripts/camera_capture.sh apply-preset preview workbench_balanced
bash scripts/camera_capture.sh baseline-shot preview empty_workbench auto_baseline
bash scripts/camera_capture.sh baseline-series preview bright_object workbench_balanced 3
bash scripts/camera_capture.sh stress preview seconds 300
```

## 4. Sidecar 与 manifest

每次 `baseline-shot` 或 `baseline-series` 都会生成:

- 原始验证图 `*.yuv` 或 `*.raw`
- 可选预览图 `*.jpg`
- sidecar JSON `*.json`
- 汇总 manifest `manifest.jsonl`

固定字段:

- `capture_type`
- `scene_tag`
- `profile`
- `preset`
- `video_node`
- `width`
- `height`
- `pixfmt`
- `fps`
- `timestamp`
- `mount_id`
- `output_path`
- `preview_path`
- `requested_controls`
- `controls_log_path`

## 5. 当前边界

- 不做正式数据集采集与样本整理
- 不做 XW500 接入
- 不做检测训练、抓取定位或真实抓取联动
- 不修改驱动或 sensor 时序
- 不把实验 preset 暴露为下游正式依赖
