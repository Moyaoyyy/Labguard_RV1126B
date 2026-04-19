# Camera Engineering Baseline

## 1. 目标

Phase 2A 的目标从“主相机工程化”收敛为“主相机可用数据基线”。

当前不是做正式数据集建设，而是把 OV13855 从“能出图”推进到“能稳定、可重复、带元数据地为后续视觉任务供数”。

## 2. 执行环境

Phase 2A 的真实验证必须在 `RV1126B` 板端执行。

- Fedora 主机 + `sshfs` 挂载只用于编辑仓库、查看板端产物和整理文档
- `v4l2-ctl` / ISP / kernel log 的真实结论必须来自板端命令执行
- `scripts/camera_capture.sh info` 可用于查看当前配置
- `controls` / `apply-preset` / `baseline-shot` / `baseline-series` / `stress` 现在都受 mount freeze gate 约束；若 `mount_baseline` 未补齐，脚本会直接拒绝执行

## 3. 当前仓库基线

### 3.1 主工作档

- `main_profile=preview`
- `video_node=/dev/video23`
- `width=1920`
- `height=1080`
- `pixfmt=NV12`
- `fps=30`
- `stream_skip=10`

当前仓库里，`preview` 仍是唯一冻结的主工作档。

更高分辨率候选必须在板端通过 `v4l2-ctl -d /dev/video23 --list-formats-ext` 选出 1 个再正式对比；仓库不预写候选 profile，避免把未验证结论写死进配置。

### 3.2 Raw 调试档

- `profile=raw_debug`
- `video_node=/dev/video1`
- `width=4224`
- `height=3136`
- `pixfmt=BG10`

保留原因:

- 用于 raw 链路核查
- 用于 ISP 路径与 sensor/CIF 路径的分界排查
- 不作为下游默认输入档

### 3.3 固定安装与验证抓图

- `mount_id=workbench_main_v1`
- `status=fixed`
- `orientation=landscape`
- `height_mm/tilt_deg/work_distance_mm=pending_measurement`
- `coverage_note` 仍是通用占位说明
- `validation_root=samples/ov13855/validation`
- `manifest=samples/ov13855/validation/manifest.jsonl`

说明:

- 任何安装形态变化都视为使当前调参结论失效
- 在补齐实测参数前，Phase 2A runtime evidence 一律不视为有效
- 允许少量验证性抓图，不做正式数据集采集

### 3.4 Presets

- `auto_baseline`: 当前默认推荐 preset，允许等价于 no-op
- `workbench_balanced`: 固定工位候选 preset，当前 `controls` 故意保持空，等待真实 control survey
- `workbench_lowlight`: 实验 preset，默认禁用，待低照度验证再启用

## 4. 统一脚本入口

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

若只想严格按既定顺序完成一轮板端 `auto_baseline` 取证，也可以直接运行:

```bash
bash scripts/run_phase2a_auto_baseline_session.sh
```

该脚本不会改变 `camera_capture.sh` 的接口，只是把当前文档要求的固定顺序、validation 目录清洁检查和证据数量校验串成一次会话。

板端推荐执行顺序:

```bash
bash scripts/camera_capture.sh info preview
bash scripts/camera_capture.sh oneshot preview
bash scripts/camera_capture.sh stress preview frames 300
bash scripts/camera_capture.sh controls preview
bash scripts/camera_capture.sh apply-preset preview auto_baseline
bash scripts/camera_capture.sh baseline-series preview empty_workbench auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview center_marker auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview bright_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview dark_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview reflective_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview edge_coverage auto_baseline 3
bash scripts/camera_capture.sh stress preview seconds 300
```

若 control survey 证明存在稳定收益，再把有效 control 写入 `workbench_balanced.controls`，随后重新执行对应场景对比与最终 `300` 秒压力测试。

## 5. Sidecar 与 manifest

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

当前 `preview .jpg` 不再从 `/dev/video23` 重新开流导出，而是从已经保存的原始帧再生成预览图。

这样做的原因:

- 避免 raw / preview 因为二次开流协商出不同格式而失配
- 允许在导出 preview 时对当前板端 `NV12` 输出里的固定 chroma bias 做预览级修正

当前限制:

- 该修正只作用于 preview `jpg`
- sidecar / `manifest.jsonl` / 原始 `yuv` 数据不变
- 根因仍指向板端相机链路 / IQ tuning，后续若完成 ISP 根因修复，应移除这层预览补偿

sidecar 和 `manifest.jsonl` 只记录采集事实；图像质量观察结论、candidate 对比结论和 final recommendation 仍需要同步回文档。

## 6. 当前边界

- 不做正式数据集采集与样本整理
- 不做 XW500 接入
- 不做检测训练、抓取定位或真实抓取联动
- 不修改驱动或 sensor 时序
- 不把实验 preset 暴露为下游正式依赖
- 不把 `Phase 2B` / `Phase 2C` 的探索代码反向混入 Phase 2A 验收
