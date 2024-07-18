from flask import Flask, render_template, request, jsonify
import os
import subprocess
import socket
import threading
import time
import netifaces

app = Flask(__name__)

# VPN 配置文件路径
VPN_CONFIG_DIR_TCP = "/etc/openvpn/tcp"
VPN_CONFIG_DIR_UDP = "/etc/openvpn/udp"

# 当前VPN状态
vpn_status = "off"
current_ip = "Not connected"

def get_openvpn_interface():
    # 检查所有网络接口
    interfaces = netifaces.interfaces()
    
    # 首先检查环境变量
    env_interface = os.environ.get('OPENVPN_INTERFACE')
    if env_interface and env_interface in interfaces:
        return env_interface
    
    # 查找 tun 或 tap 接口
    for interface in interfaces:
        if interface.startswith(('tun', 'tap')):
            return interface
    
    # 如果没有找到，返回默认值 None
    return None

# 获取所有 VPN 配置文件
def get_vpn_configs(vpn_type):
    configs = []
    config_dir = VPN_CONFIG_DIR_TCP if vpn_type == "tcp" else VPN_CONFIG_DIR_UDP
    for file in os.listdir(config_dir):
        if file.endswith(".ovpn"):
            configs.append(file)
    return configs

# 添加路由到 ifconfig.me
def add_route_ifconfig_me():
    try:
        ip_address = socket.gethostbyname('ifconfig.me')
        interface = get_openvpn_interface()
        if not interface:
            print("Error: Unable to find OpenVPN interface")
            return
        
        subprocess.run(['ip', 'route', 'add', f'{ip_address}/32', 'dev', interface], check=True)
        print(f"Route added: {ip_address}/32 dev {interface}")
    except subprocess.CalledProcessError as e:
        if "File exists" in str(e):
            print(f"Route already exists: {ip_address}/32 dev {interface}")
        else:
            print(f"Error adding route: {e}")
    except socket.gaierror as e:
        print(f"Error resolving ifconfig.me: {e}")

# 获取当前的公网 IP 地址
def get_current_ip():
    max_retries = 3
    retry_delay = 5
    interface = get_openvpn_interface()

    if not interface:
        return "Error: Unable to find OpenVPN interface"

    for _ in range(max_retries):
        try:
            result = subprocess.run(
                ['curl', '--interface', interface, 'https://ifconfig.me'],
                capture_output=True,
                text=True,
                check=True,
                timeout=10
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error fetching IP: {e}")
        except subprocess.TimeoutExpired:
            print("Timeout while fetching IP")
        
        time.sleep(retry_delay)

    return "Error fetching IP"

# 停止当前的 VPN 连接
def stop_vpn():
    global vpn_status, current_ip
    vpn_status = "off"
    current_ip = "Not connected"
    subprocess.call(["pkill", "-SIGTERM", "openvpn"])
    time.sleep(2)
    subprocess.call(["pkill", "-9", "openvpn"])

# 异步启动指定的 VPN 连接
def start_vpn(config_file, vpn_type):
    def _start_vpn():
        global vpn_status, current_ip
        vpn_status = "connecting"
        config_dir = VPN_CONFIG_DIR_TCP if vpn_type == "tcp" else VPN_CONFIG_DIR_UDP
        config_path = os.path.join(config_dir, config_file)
        subprocess.Popen(["openvpn", "--config", config_path])
        
        # 等待VPN连接建立并获取新IP
        for _ in range(12):  # 尝试60秒
            time.sleep(5)
            new_ip = get_current_ip()
            if new_ip != "Error fetching IP" and new_ip != "Error: Unable to find OpenVPN interface":
                current_ip = new_ip
                vpn_status = "on"
                return
        
        vpn_status = "error"
        current_ip = "Connection failed"

    threading.Thread(target=_start_vpn).start()

@app.route('/')
def index():
    tcp_configs = get_vpn_configs("tcp")
    udp_configs = get_vpn_configs("udp")
    return render_template('index.html', tcp_configs=tcp_configs, udp_configs=udp_configs, vpn_status=vpn_status, current_ip=current_ip)

@app.route('/switch', methods=['POST'])
def switch():
    vpn_type = request.form['vpn_type']
    config_file = request.form['config']
    if not config_file or not vpn_type:
        return jsonify(success=False, message="Invalid configuration"), 400

    stop_vpn()
    start_vpn(config_file, vpn_type)
    return jsonify(success=True, message="VPN switching initiated")

@app.route('/toggle', methods=['POST'])
def toggle_vpn():
    global vpn_status
    if vpn_status == "on":
        stop_vpn()
        return jsonify(success=True, message="VPN turned off")
    else:
        # 启动默认的 VPN 配置文件
        start_vpn("default.ovpn", "tcp")  # 修改为你的默认配置文件和类型
        return jsonify(success=True, message="VPN turning on")

@app.route('/get_status', methods=['GET'])
def get_status():
    global current_ip, vpn_status
    if vpn_status == "on":
        current_ip = get_current_ip()
    return jsonify(vpn_status=vpn_status, current_ip=current_ip)

if __name__ == '__main__':
    add_route_ifconfig_me()
    app.run(host='0.0.0.0', port=5000)
