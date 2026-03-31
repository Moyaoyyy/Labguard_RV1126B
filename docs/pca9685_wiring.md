# PCA9685 Wiring And Bring-up Notes

## 1. 当前范围

本文件只定义 PCA9685 与 RV1126B 的默认接线和 bring-up 顺序。

当前不做多舵机联动，不做机械臂动作编排。

## 2. 默认接线假设

- RV1126B 使用 `40-pin GPIO`
- 40-pin 按树莓派兼容定义处理
- PCA9685 逻辑侧使用 `3.3V`
- 舵机电源侧使用独立 `5V`

## 3. 默认接线表

| RV1126B | PCA9685 | 说明 |
|---|---|---|
| 3.3V | VCC | 逻辑供电 |
| GND | GND | 公共地 |
| SDA | SDA | I2C 数据 |
| SCL | SCL | I2C 时钟 |
| GND | OE | 默认拉低使能输出 |
| 外部 5V + | V+ | 舵机电源 |
| 外部 5V GND | GND | 与板端共地 |
| 舵机信号线 | CH0 | 单舵机 bring-up 默认通道 |
| 舵机电源线 | 外部 5V | 不走板载 3.3V |
| 舵机地线 | 公共 GND | 必须共地 |

## 4. 若 40-pin 与树莓派标准一致

优先使用以下物理针脚:

- `Pin 1 = 3.3V`
- `Pin 3 = SDA`
- `Pin 5 = SCL`
- `Pin 6 = GND`

## 5. 接线约束

- 不把舵机直接接到 RV1126B 的 `3.3V`
- 不把 `PCA9685 VCC` 接到 `5V`
- 必须共地，否则 I2C 与 PWM 都可能异常
- 初次测试只接一个舵机到 `CH0`

## 6. bring-up 顺序

1. 先完成接线
2. 上电后执行 `i2cdetect -l`
3. 确认目标 I2C bus
4. 执行 `i2cdetect -y <bus>` 确认 `0x40`
5. 执行 `scripts/pca9685_probe.sh`
6. 执行 `tests/test_pca9685.sh`

## 7. 参考命令

```bash
i2cdetect -l
i2cdetect -y <bus>
bash scripts/pca9685_probe.sh
bash tests/test_pca9685.sh
```

## 8. 参考资料

- ELF-RV1126B / ELF 2 资料说明 40-pin 提供 GPIO、SPI、I2C、UART 及 5V/3.3V 电源
- Forlinx RV1126B/OK1126Bx-S 官方说明提到 40-pin GPIO 与树莓派标准兼容
