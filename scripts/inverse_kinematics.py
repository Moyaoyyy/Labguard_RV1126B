import math
from dataclasses import dataclass
from typing import Tuple, Optional

# 机械臂参数（根据你的实际值调整）
L1 = 9.0   # 基座高度(cm)
L2 = 10.0   # 大臂长度(cm)
L3 = 16.0   # 小臂长度(cm)

RAD2DEG = 180.0 / math.pi
DEG2RAD = math.pi / 180.0

@dataclass
class Point3D:
    """三维点坐标"""
    x: float
    y: float
    z: float
    gripper_state: int = 0  # 夹爪状态：0-关闭，1-打开

@dataclass
class JointAngle:
    """关节角度（度）"""
    theta1: float = 0.0  # 基座
    theta2: float = 0.0  # 大臂
    theta3: float = 0.0  # 小臂
    theta4: float = 0.0  # 腕部/夹爪

def is_reachable(target: Point3D) -> bool:
    """判断目标点是否可达"""
    dx = target.x
    dy = target.y
    dz = target.z - L1  # 减去基座高度
    
    r = math.sqrt(dx*dx + dy*dy + dz*dz)
    
    # 最大伸展距离
    max_reach = L2 + L3
    # 最小收缩距离
    min_reach = abs(L2 - L3)
    
    if r > max_reach or r < min_reach:
        print(f"距离检查: {r:.2f} (范围: {min_reach:.2f} - {max_reach:.2f})")
        return False
    
    return True

def inverse_kinematics(target: Point3D) -> Optional[JointAngle]:
    """逆运动学求解"""
    x = float(target.x)
    y = float(target.y)
    z = float(target.z)
    state = target.gripper_state
    
    print(f"目标坐标: ({state}, {x:.2f}, {y:.2f}, {z:.2f})")
    
    # 首先检查目标点是否可达
    if not is_reachable(target):
        print("错误：目标点不可达！")
        return None
    
    angles = JointAngle()
    
    # 计算theta1（基座旋转角度）
    if x == 0 and y == 0:
        # 目标点在正上方，保持当前位置
        angles.theta1 = 0
    else:
        angles.theta1 = math.atan2(y, x) * RAD2DEG
    print(f"theta1 (基座): {angles.theta1:.2f}°")
    
    # 计算臂部角度
    r1 = math.sqrt(x*x + y*y)  # XY平面投影距离
    print(f"r1: {r1:.2f}")
    dz = z - L1  # 相对于肩关节的高度
    print(f"DZ: {dz:.2f}")
    
    r = math.sqrt(r1*r1 + dz*dz)  # 底座中心到目标的距离
    print(f"r: {r:.2f}")
    
    alpha = math.atan2(dz, r1)  # XY平面投影与底座中心到达目标距离的夹角
    print(f"alpha: {alpha:.2f} rad ({alpha*RAD2DEG:.2f}°)")
    
    # 余弦定理计算角度b
    cos_b = (L2*L2 + r*r - L3*L3) / (2 * L2 * r)
    # 防止浮点误差导致acos参数超出[-1,1]
    cos_b = max(-1.0, min(1.0, cos_b))
    
    b = math.acos(cos_b)
    print(f"b: {b:.2f} rad ({b*RAD2DEG:.2f}°)")
    
    # 余弦定理计算角度c
    cos_c = (L2*L2 + L3*L3 - r*r) / (2 * L2 * L3)
    cos_c = max(-1.0, min(1.0, cos_c))
    
    c = math.acos(cos_c)
    print(f"c: {c:.2f} rad ({c*RAD2DEG:.2f}°)")
    
    # 计算theta2和theta3
    if z > L1:  # 判断物体是否超出底座的高度
        angles.theta2 = 180 - (alpha + b) * RAD2DEG
        angles.theta3 = c * RAD2DEG
    else:
        angles.theta2 = 180 - (b + alpha) * RAD2DEG
        angles.theta3 = c * RAD2DEG
    
    # 计算theta4（夹爪）
    if state == 0:
        angles.theta4 = 0
    else:
        angles.theta4 = 90
    
    # 标准化角度到合理范围
    angles.theta2 = max(0.0, min(180.0, angles.theta2))
    angles.theta3 = max(0.0, min(180.0, angles.theta3))
    
    print("\n计算结果:")
    print(f"θ1(基座): {angles.theta1:.2f}°")
    print(f"θ2(大臂): {angles.theta2:.2f}°")
    print(f"θ3(小臂): {angles.theta3:.2f}°")
    print(f"θ4(腕部): {angles.theta4:.2f}°")
    
    return angles

def angles_to_pwm(angles: JointAngle) -> Tuple[float, float, float, float]:
    """将角度转换为PWM值"""
    # 根据你的实际舵机参数调整映射关系
    # 示例：假设舵机0°对应500us，180°对应2500us
    def angle_to_pwm(angle, min_pwm=500, max_pwm=2500, min_angle=0, max_angle=180):
        return min_pwm + (angle - min_angle) * (max_pwm - min_pwm) / (max_angle - min_angle)
    
    t1_norm = 135.0 - angles.theta1  # 转换到-135到135范围
    
    pwm0 = angle_to_pwm(t1_norm, min_angle=-135, max_angle=135)
    pwm1 = angle_to_pwm(angles.theta2)
    pwm2 = angle_to_pwm(angles.theta3)
    pwm3 = angle_to_pwm(angles.theta4)
    
    return pwm0, pwm1, pwm2, pwm3

def print_servo_commands(angles: JointAngle):
    """打印舵机命令（模拟发送）"""
    pwm0, pwm1, pwm2, pwm3 = angles_to_pwm(angles)
    
    print(f"PWM0={pwm0:.0f}us (底座旋转)")
    print(f"PWM1={pwm1:.0f}us (大臂旋转)")
    print(f"PWM2={pwm2:.0f}us (小臂旋转)")
    print(f"PWM3={pwm3:.0f}us (夹爪状态)")
    
    # 这里添加实际的硬件控制代码
    # 例如使用serial、pigpio、或者你的PCB库
    # PCB_Set_Angle(0, t1_norm)
    # PCB_Set_Angle(1, angles.theta2)
    # PCB_Set_Angle(2, angles.theta3)
    # PCB_Set_Angle(3, angles.theta4)

def set_servo_angles(angles: JointAngle, pwm_func=None):
    """实际设置舵机角度（需要根据你的硬件实现）"""
    # 标准化theta1到你的舵机范围
    t1_norm = 135.0 - angles.theta1
    
    # 调用你的硬件控制函数
    # 方式1：直接使用你提供的函数
    # PCB_Set_Angle(0, t1_norm)
    # PCB_Set_Angle(1, angles.theta2)
    # PCB_Set_Angle(2, angles.theta3)
    # PCB_Set_Angle(3, angles.theta4)
    
    # 方式2：使用回调函数
    if pwm_func:
        pwm_func(0, t1_norm)
        pwm_func(1, angles.theta2)
        pwm_func(2, angles.theta3)
        pwm_func(3, angles.theta4)
    
    print(f"舵机已设置: θ1={t1_norm:.1f}°, θ2={angles.theta2:.1f}°, "
          f"θ3={angles.theta3:.1f}°, θ4={angles.theta4:.1f}°")

# 主程序示例
if __name__ == "__main__":
    # 测试目标点
    target = Point3D(x=150, y=100, z=150, gripper_state=1)
    
    # 求解逆运动学
    angles = inverse_kinematics(target)
    
    if angles:
        # 打印PWM命令
        print("\n--- PWM命令 ---")
        print_servo_commands(angles)
        
        # 实际控制舵机（需要硬件支持）
        # set_servo_angles(angles)
        
        # 或者只获取PWM值
        pwm_values = angles_to_pwm(angles)
        print(f"\n原始PWM值: {pwm_values}")
