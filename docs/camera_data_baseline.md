# Camera Data Baseline

## 1. 当前仓库结论

当前仓库只冻结了以下 Phase 2A 事实：

- `preview = 1920x1080 NV12 @ 30fps`
- `raw_debug = 4224x3136 BG10`
- `auto_baseline` 是当前默认推荐 preset
- `workbench_balanced.controls` 故意保持空，等待真实 control survey 结果
- `workbench_lowlight` 保持 `enabled=false`
- `2026-04-19` 已完成 1 轮板端 `auto_baseline` 取证会话
- `oneshot`、`300` 帧短压测、`300` 秒长压测均通过
- `6` 个场景共生成 `18` 个 sidecar JSON 与 `18` 条 `manifest.jsonl` 记录
- `/dev/video23` 当前仅暴露只读 `pixel_rate`，本轮未发现可冻结的有效 controls

当前仓库**尚未**冻结以下结论：

- 单一更高分辨率候选及其对比结果
- 6 组验证场景的人工画质观察结论
- 测试值 mount baseline 的最终复测确认

换句话说，Phase 2A 的自动化取证证据已生成，但 candidate 分辨率结论和人工场景复核仍待补齐。

## 2. 固定安装形态确认

当前默认按固定工位场景建立主相机基线。

配置基线:

- `mount_id=workbench_main_v1`
- `status=fixed`
- `orientation=landscape`
- `height_mm=420`
- `tilt_deg=25`
- `work_distance_mm=510`
- `coverage_note=Center ROI fully visible. Left/right edges and all four corners remain inside frame. Planned grab ROI is fully covered with small margin.`

执行要求:

- 当前值是 `2026-04-19` 板端会话使用的测试值，后续仍需现场复测确认
- 一旦更换支架、角度、工作距离或视野覆盖范围，必须重新做控制项摸底与验证抓图

脚本约束:

- `scripts/camera_capture.sh info` 会显示 `phase2a_mount_gate`
- `controls` / `apply-preset` / `baseline-shot` / `baseline-series` / `stress` 都要求 mount baseline 已冻结
- 在 `mount_baseline` 未补齐前，脚本会拒绝生成 Phase 2A 验收证据

## 3. 主工作分辨率决策过程

### 3.1 当前默认起点

- `preview = 1920x1080 NV12 @ 30fps`
- `raw_debug = 4224x3136 BG10`

原因:

- `/dev/video23` 已通过真实取流和 `300` 帧短稳验证
- `1920x1080 NV12` 在带宽、调试成本和后续视觉处理成本之间更均衡
- `raw_debug` 仅保留给链路诊断，不作为日常输入

### 3.2 冻结规则

主工作分辨率必须按以下顺序决策：

1. 以 `preview` 作为默认基线执行一次单帧抓图和一次 `300` 帧压力测试
2. 在板端运行 `v4l2-ctl -d /dev/video23 --list-formats-ext`，只选 `1` 个更高分辨率候选
3. 对候选执行同样的单帧抓图和 `300` 帧压力测试
4. 只有当候选同时满足以下条件时，才允许替换 `preview`

- 细节明显更好
- 无新增 unexpected kernel / camera errors
- 对后续检测与定位处理成本仍可接受

若任一条件不满足，则 `preview` 继续作为唯一正式主档。

当前仓库不预置 candidate profile，避免把未验证格式直接写死进配置。

## 4. 图像质量基线与判定口径

Phase 2A 的图像质量不是“风格最好看”，而是“足够稳定、足够可用”。

验收口径:

- 中心区域边缘清晰，无明显运动模糊
- 白色高亮目标保留轮廓，不出现大面积死白
- 深色目标仍能辨认边界，不出现整块死黑
- 反光目标不会让整个 ROI 曝光崩坏
- 画面四边缘仍能辨认容器或物体轮廓
- 同一场景连续 `3` 张图之间无明显亮度跳变或颜色失稳

建议在固定工位上记录以下观察项:

- 工位中心清晰度
- 工位边缘可见性
- 高亮物体轮廓
- 深色物体边界
- 反光表面曝光稳定性
- 自动曝光与自动白平衡恢复速度

## 5. 控制项摸底结果表

先执行:

```bash
bash scripts/camera_capture.sh controls preview
```

记录分类:

- `supported and effective`
- `supported but ineffective`
- `unsupported`

建议优先观察的 controls:

| Control | 分类 | 当前状态 | 备注 |
|---|---|---|---|
| `exposure_auto` | 待确认 | pending | 关注自动曝光切换是否真实生效 |
| `exposure_absolute` | 待确认 | pending | 仅在关闭自动曝光后验证 |
| `gain` | 待确认 | pending | 关注是否可控及是否引入明显噪声 |
| `white_balance_temperature_auto` | 待确认 | pending | 关注 AWB 开关是否真实生效 |
| `white_balance_temperature` | 待确认 | pending | 仅在关闭 AWB 后验证 |
| `brightness` | 待确认 | pending | 关注是否只是 ISP 后处理偏移 |
| `contrast` | 待确认 | pending | 关注是否影响后续边缘细节 |
| `saturation` | 待确认 | pending | 关注是否仅影响视觉风格 |
| `sharpness` | 待确认 | pending | 关注是否产生明显伪边缘 |

冻结原则:

- `auto_baseline` 必须保留
- 只有被验证为 `supported and effective` 的 controls 才能写入 `workbench_balanced`
- 如果没有任何 control 证明带来稳定收益，`workbench_balanced.controls` 保持空，最终推荐 preset 直接退回 `auto_baseline`
- `workbench_lowlight` 只在低照度场景确有收益时启用，否则保持禁用

当前板端 survey 结果:

| Control | 分类 | 当前状态 | 备注 |
|---|---|---|---|
| `exposure_auto` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `exposure_absolute` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `gain` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `white_balance_temperature_auto` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `white_balance_temperature` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `brightness` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `contrast` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `saturation` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |
| `sharpness` | `unsupported` | unresolved on `/dev/video23` | `v4l2-ctl -L` 未暴露该 control |

补充说明:

- 本轮唯一可见 control 为只读 `pixel_rate`
- 当前没有证据支持把任何 control 冻结进 `workbench_balanced`

## 6. 验证场景 Checklist

本阶段只做 `6` 组小样本验证，不扩成正式数据集。

| Scene Tag | 场景目的 | 重点观察 |
|---|---|---|
| `empty_workbench` | 空工位基线 | 曝光稳定、背景均匀性、边缘覆盖 |
| `center_marker` | 中心定位参照 | 中心清晰度、几何稳定性 |
| `bright_object` | 高亮目标 | 高光保留、轮廓是否发白溢出 |
| `dark_object` | 深色目标 | 暗部边界、噪声和欠曝 |
| `reflective_object` | 反光目标 | ROI 曝光是否崩坏、AWB 是否漂移 |
| `edge_coverage` | 边缘覆盖 | 四角和边缘区可见性 |

每组场景固定保存 `3` 张验证图，若从空目录开始做一轮完整验证，应新增：

- `18` 张原始验证图
- `18` 个 sidecar JSON
- `18` 条 `manifest.jsonl` 记录
- 可选 `18` 张预览 JPG

推荐命令:

```bash
bash scripts/camera_capture.sh baseline-series preview empty_workbench auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview center_marker auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview bright_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview dark_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview reflective_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview edge_coverage auto_baseline 3
```

如果后续启用了 `workbench_balanced`，需要针对收益最明显的场景重做对比，不得沿用 `auto_baseline` 的旧结论。

当前自动化取证结果:

- `manifest.jsonl = 18`
- `sidecar JSON = 18`
- `raw validation captures = 18`
- `scene directories = 6`
- 本轮人工画质观察仍待现场复核，不在本次自动回填中伪造结论

## 7. 最终推荐 preset 与收口

### 7.1 `auto_baseline`

- 角色: 自动模式参考档
- 当前状态: 默认推荐 preset
- 用途: 对比人工 preset 是否真的带来收益
- 本轮结论: `auto_baseline` 已通过 1 轮板端取证会话，可继续作为 candidate 分辨率对比前的唯一正式基线

### 7.2 `workbench_balanced`

- 角色: 固定工位主候选 preset
- 当前状态: 候选 preset，`controls` 仍为空
- 启用条件: 只有真实 control survey 证明存在稳定收益，才允许冻结有效 controls

### 7.3 `workbench_lowlight`

- 角色: 低照度实验 preset
- 默认: `enabled=false`
- 启用条件: 低照度下确有明显收益，且不会破坏主工位场景稳定性

最终收口时必须同步以下结论：

- 固定安装参数与 `coverage_note`
- 主工作分辨率是否继续 `preview`
- controls 分类表
- 最终推荐 preset
- 最终 `300` 秒压力测试结果

## 8. 推荐执行顺序

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

最终输出应能回答以下问题:

- 主相机是否已固定且视野稳定
- 主工作分辨率是否已冻结
- 哪些 controls 真实可用
- 哪个 preset 适合作为固定工位主候选
- 当前图像是否已足够给后续检测和定位任务供数

当前自动化会话结论:

- `auto_baseline_stable = yes`
- `preview_still_usable_as_main_profile = yes`
- `effective_controls_found = no`
- `recommended_preset_after_this_session = auto_baseline`
- `next_session_required = yes`
- `next_session_type = resolution_compare`

## 9. 板端 Auto Baseline 取证会话

本节定义下一次 `RV1126B` 板端会话的唯一目标: 补齐 `auto_baseline` 的 runtime evidence。

本轮不做:

- `PCA9685`
- `uart_receiver.py`
- `inverse_kinematics.py`
- `workbench_balanced` 二轮对比
- 更高分辨率 candidate 的正式对比

### 9.1 会话前检查

进入板端 shell 后，先确认:

- 当前 shell 运行在 `RV1126B` 上，而不是 Fedora 主机
- `v4l2-ctl`、`media-ctl`、`gst-launch-1.0` 可用
- 固定工位在本轮中途不会发生 mount / ROI 变化
- 已准备实测 `height_mm`、`tilt_deg`、`work_distance_mm` 的方式
- 已决定旧的 validation 产物如何归档，避免与本轮证据混杂

### 9.2 Mount Freeze

先在 `configs/ov13855.yaml` 中补齐:

- `mount_baseline.height_mm`
- `mount_baseline.tilt_deg`
- `mount_baseline.work_distance_mm`
- `mount_baseline.coverage_note`

`coverage_note` 至少描述:

- 工位中心区覆盖情况
- 四边 / 四角覆盖情况
- 未来抓取 ROI 是否完整落在视野内

写回后立即执行:

```bash
bash scripts/camera_capture.sh info preview
```

通过条件:

- 输出含 `phase2a_mount_gate: ready`
- 上述 `mount_baseline` 字段不再是占位值

### 9.3 Auto Baseline 主会话

按以下固定顺序执行，不跳步:

```bash
bash scripts/camera_capture.sh info preview
bash scripts/camera_capture.sh oneshot preview
bash scripts/camera_capture.sh stress preview frames 300
bash scripts/camera_capture.sh controls preview
bash scripts/camera_capture.sh baseline-series preview empty_workbench auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview center_marker auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview bright_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview dark_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview reflective_object auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview edge_coverage auto_baseline 3
bash scripts/camera_capture.sh stress preview seconds 300
```

执行规则:

- 任一步报错、超时或出现明显异常 kernel / camera log，则本轮结论记为 `inconclusive`
- `controls preview` 的 stdout 与 `controls_*.log` 必须保留
- 六组场景必须全部完成，每组固定 `3` 张
- 一旦中途 mount / ROI / 光照布置发生变化，本轮全部作废，重新开始

## 10. 结果回填模板

以下模板先用于会话内人工记录，取证完成后再回填到现有文档。

### 10.1 Mount Baseline

```text
mount_id: workbench_main_v1
status: fixed
orientation: landscape
height_mm:
tilt_deg:
work_distance_mm:
coverage_note:
mount_change_during_session: yes / no
```

### 10.2 Auto Baseline 运行结果

```text
board:
os:
kernel:
video_node:
profile: preview
format: 1920x1080 NV12 @ 30fps

oneshot: pass / fail
stress_300_frames: pass / fail
stress_300_seconds: pass / fail

unexpected_kernel_or_camera_errors: yes / no
error_summary:
```

### 10.3 Controls Survey

```text
supported_and_effective:
supported_but_ineffective:
unsupported:
notes:
```

建议至少覆盖:

- `exposure_auto`
- `exposure_absolute`
- `gain`
- `white_balance_temperature_auto`
- `white_balance_temperature`
- `brightness`
- `contrast`
- `saturation`
- `sharpness`

### 10.4 六场景观察记录

```text
scene: empty_workbench
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:

scene: center_marker
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:

scene: bright_object
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:

scene: dark_object
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:

scene: reflective_object
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:

scene: edge_coverage
count: 3
center_clarity:
edge_visibility:
highlight_contour:
dark_boundary:
reflective_stability:
ae_awb_recovery:
notes:
```

### 10.5 本轮结论

```text
auto_baseline_stable: yes / no
preview_still_usable_as_main_profile: yes / no
effective_controls_found: yes / no
recommended_preset_after_this_session: auto_baseline / inconclusive
next_session_required: yes / no
next_session_type: resolution_compare / balanced_compare / issue_fix
```

### 10.6 会后分支

- 若 `auto_baseline_stable = no`:
  - 下一个会话只做故障定位，不做 candidate 分辨率或 balanced 对比
- 若 `auto_baseline_stable = yes` 且 `effective_controls_found = no`:
  - 下一个会话做单一更高分辨率 candidate 的正式对比
  - `workbench_balanced` 继续保持空
- 若 `auto_baseline_stable = yes` 且 `effective_controls_found = yes`:
  - 下一个会话仍先做单一更高分辨率 candidate 的正式对比
  - `workbench_balanced` 只能排在 candidate 结论之后
