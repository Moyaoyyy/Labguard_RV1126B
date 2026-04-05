# Camera Data Baseline

## 1. 固定安装形态确认

当前默认按固定工位场景建立主相机基线。

配置基线:

- `mount_id=workbench_main_v1`
- `status=fixed`
- `orientation=landscape`
- `height_mm=pending_measurement`
- `tilt_deg=pending_measurement`
- `work_distance_mm=pending_measurement`

执行要求:

- 在开发板现场补齐 `height_mm`、`tilt_deg`、`work_distance_mm`
- 一旦更换支架、角度、工作距离或视野覆盖范围，必须重新做控制项摸底与验证抓图
- 视野描述写入 `coverage_note`，至少说明工位中心区、边缘区和未来抓取 ROI 的覆盖情况

## 2. 主工作分辨率决策过程

### 2.1 当前默认起点

- `preview = 1920x1080 NV12 @ 30fps`
- `raw_debug = 4224x3136 BG10`

原因:

- `/dev/video23` 已通过真实取流和 300 帧短稳验证
- `1920x1080 NV12` 在带宽、调试成本和后续视觉处理成本之间更均衡
- `raw_debug` 仅保留给链路诊断，不作为日常输入

### 2.2 冻结规则

主工作分辨率必须按以下顺序决策:

1. 以 `preview` 作为默认基线执行一次单帧抓图和一次 `300` 帧压力测试
2. 从 `v4l2-ctl -d /dev/video23 --list-formats-ext` 中选择 1 个更高分辨率候选
3. 对候选执行同样的单帧抓图和 `300` 帧压力测试
4. 只有当候选同时满足以下条件时，才允许替换 `preview`

- 细节明显更好
- 无新增 unexpected kernel / camera errors
- 对后续检测与定位处理成本仍可接受

若任一条件不满足，则 `preview` 继续作为唯一正式主档。

## 3. 图像质量基线与判定口径

Phase 2A 的图像质量不是“风格最好看”，而是“足够稳定、足够可用”。

验收口径:

- 中心区域边缘清晰，无明显运动模糊
- 白色高亮目标保留轮廓，不出现大面积死白
- 深色目标仍能辨认边界，不出现整块死黑
- 反光目标不会让整个 ROI 曝光崩坏
- 画面四边缘仍能辨认容器或物体轮廓
- 同一场景连续 3 张图之间无明显亮度跳变或颜色失稳

建议在固定工位上记录以下观察项:

- 工位中心清晰度
- 工位边缘可见性
- 高亮物体轮廓
- 深色物体边界
- 反光表面曝光稳定性
- 自动曝光与自动白平衡恢复速度

## 4. 控制项摸底结果表

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
- `workbench_balanced` 只冻结少量真正有效的 controls
- `workbench_lowlight` 只在低照度场景确有收益时启用，否则保持禁用

## 5. 验证场景 Checklist

本阶段只做 6 组小样本验证，不扩成正式数据集。

| Scene Tag | 场景目的 | 重点观察 |
|---|---|---|
| `empty_workbench` | 空工位基线 | 曝光稳定、背景均匀性、边缘覆盖 |
| `center_marker` | 中心定位参照 | 中心清晰度、几何稳定性 |
| `bright_object` | 高亮目标 | 高光保留、轮廓是否发白溢出 |
| `dark_object` | 深色目标 | 暗部边界、噪声和欠曝 |
| `reflective_object` | 反光目标 | ROI 曝光是否崩坏、AWB 是否漂移 |
| `edge_coverage` | 边缘覆盖 | 四角和边缘区可见性 |

每组场景固定保存 `3` 张验证图，推荐命令:

```bash
bash scripts/camera_capture.sh baseline-series preview empty_workbench auto_baseline 3
bash scripts/camera_capture.sh baseline-series preview bright_object workbench_balanced 3
```

## 6. 最终推荐 preset 与实验 preset

### 6.1 `auto_baseline`

- 角色: 自动模式参考档
- 要求: 始终可用，可等价于 no-op
- 用途: 对比人工 preset 是否真的带来收益

### 6.2 `workbench_balanced`

- 角色: 固定工位主候选 preset
- 要求: 只保留少量有效控制项
- 验收: 应用后可立即取流，并通过最终 `300` 秒压力测试

### 6.3 `workbench_lowlight`

- 角色: 低照度实验 preset
- 默认: `enabled=false`
- 启用条件: 低照度下确有明显收益，且不会破坏主工位场景稳定性

## 7. 推荐执行顺序

```bash
bash scripts/camera_capture.sh info preview
bash scripts/camera_capture.sh controls preview
bash scripts/camera_capture.sh apply-preset preview auto_baseline
bash scripts/camera_capture.sh baseline-series preview empty_workbench auto_baseline 3
bash scripts/camera_capture.sh apply-preset preview workbench_balanced
bash scripts/camera_capture.sh baseline-series preview reflective_object workbench_balanced 3
bash scripts/camera_capture.sh stress preview seconds 300
```

最终输出应能回答以下问题:

- 主相机是否已固定且视野稳定
- 主工作分辨率是否已冻结
- 哪些 controls 真实可用
- 哪个 preset 适合作为固定工位主候选
- 当前图像是否已足够给后续检测和定位任务供数
