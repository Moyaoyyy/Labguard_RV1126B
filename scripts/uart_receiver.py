import threading
import time
import sys
import json
import os

try:
    import serial
except ImportError:
    serial = None

class UartReceiver:
    """串口接收器 - 解析cx, cy，cz坐标"""
    
    def __init__(self, port='/dev/ttyS5', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_port = None
        self.running = False
        self.receive_thread = None
        
        # 统计
        self.frame_count = 0
        self.cx=0
        self.cy=0
        self.cz=0
        
    def init_serial(self):
        """初始化串口"""
        if serial is None:
            print("✗ 串口初始化失败: 缺少 pyserial 模块")
            print("  请安装: pip install pyserial")
            return False

        try:
            self.serial_port = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.01
            )
            print(f"✓ 串口初始化成功: {self.port} @ {self.baudrate}bps")
            return True
        except Exception as e:
            print(f"✗ 串口初始化失败: {e}")
            print(f"  请运行: sudo chmod 666 {self.port}")
            return False
    
    def parse_data(self, data_str):
        """解析JSON数据，提取cx, cy,cz"""
        try:
            # 解析JSON
            data = json.loads(data_str)
            
            # 提取cx和cy,cz
            cx = data.get('cx')
            cy = data.get('cy')
            cz=data.get('cz')
            
            if cx is not None and cy is not None and cz is not None:
                self.cx = cx
                self.cy = cy
                self.cz = cz
                return {'cx': cx, 'cy': cy ,'cz':cz }
            else:
                print(f"  警告: JSON中缺少cx或cy字段或cz字段")
                return None
                
        except json.JSONDecodeError:
            print(f"  警告: 不是有效的JSON格式")
            return None
        except Exception as e:
            print(f"  解析错误: {e}")
            return None
    
    def _receive_task(self):
        """接收线程"""
        buffer = bytearray()
        
        print("\n等待接收数据...")
        print("期望格式: {\"event\":\"fixed_grab_stub\",\"frame_id\":123,\"cx\":960,\"cy\":540,\"action\":\"trigger_fixed_grab_stub\"}\n")
        
        while self.running:
            try:
                # 读取一个字节
                byte_data = self.serial_port.read(1)
                
                if byte_data:
                    buffer.extend(byte_data)
                    
                    # 持续读取直到超时
                    while True:
                        next_byte = self.serial_port.read(1)
                        if next_byte:
                            buffer.extend(next_byte)
                        else:
                            break
                    

                    # 处理这一帧数据
                    if len(buffer) > 0:
                        try:
                            data_str = buffer.decode('utf-8').strip()
                            if data_str:
                                # 解析坐标
                                coords = self.parse_data(data_str)
                                
                                if coords:
                                    self.frame_count += 1
                                    print("=" * 60)
                                    print(f"[帧 {self.frame_count}] 收到坐标:")
                                    print(f"  原始数据: {data_str}")
                                    print(f"  解析结果: cx={coords['cx']}, cy={coords['cy']}")
                                    print("=" * 60)
                                    print()
                                else:
                                    print(f"收到无效数据: {data_str[:100]}\n")
                        except Exception as e:
                            print(f"处理错误: {e}")
                        
                        buffer = bytearray()
                        
                else:
                    time.sleep(0.001)
                    
            except Exception as e:
                print(f"接收错误: {e}")
                time.sleep(0.1)
    
    def start(self):
        """启动接收"""
        if not self.init_serial():
            return False
        
        self.running = True
        self.receive_thread = threading.Thread(target=self._receive_task, daemon=True)
        self.receive_thread.start()
        return True
    
    def stop(self):
        """停止接收"""
        self.running = False
        if self.receive_thread:
            self.receive_thread.join(timeout=2)
        if self.serial_port:
            self.serial_port.close()
        print("\n串口已关闭")

    def get_coord(self):
        """获取最新的坐标"""
        return (self.cx, self.cy, self.cz)



if __name__ == "__main__":
    # 创建接收器
    receiver = UartReceiver(port='/dev/ttyS5', baudrate=115200)
    
    try:
        # 启动
        if receiver.start():
            print("\n" + "=" * 60)
            print("串口接收器运行中...")
            print("按 Ctrl+C 停止")
            print("=" * 60 + "\n")
            
            # 保持运行
            while True:
                time.sleep(1)
                
    except KeyboardInterrupt:
        print("\n正在停止...")
    finally:
        receiver.stop()
        print("程序退出")
