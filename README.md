# Vpn_switcher  
web控制 Linux 系统上的 网口 连接。它允许用户远程启动、停止和切换不同的网口配置，并通过获取当前的公网 IP 地址来验证当前网口的连接状态。
![image](https://github.com/user-attachments/assets/cd1f9e90-6216-43be-9512-6f81e1083cb7)
## 功能

- 远程控制启动和停止 网口 连接。
- 在不同的 网口 配置之间切换。
- 获取当前公网 IP 地址。
- 检查 网口 连接状态。
## 安装

1. 克隆仓库：
    ```sh
    git clone https://github.com/zhuchangyi/vpn_switcher.git
    cd vpn_switcher
    ```
2. 安装所需的库：
   ```sh
   sudo apt update
   sudo apt install python3-pip
   pip install --no-cache-dir -r requirements.txt
   apt-get update && apt-get install -y openvpn unzip wget curl procps && rm -rf /var/lib/apt/lists/*
    ```
3. 安装网口配置文件 这里用的配置来源于[Namecheap](https://www.namecheap.com/vpn/vpn-for-linux/)，没有aff 💔
   ```sh
   wget -O /etc/openvpn/groupedServerList.zip https://vpn.ncapi.io/groupedServerList.zip && \ 
   unzip /etc/openvpn/groupedServerList.zip -d /etc/openvpn && \
   rm /etc/openvpn/groupedServerList.zip && \
   ```sh
4. 运行
   ```sh
   chmod + x setup.sh
   ./setup.sh
   ```
   在 ` http://server-ip:5000`  查看网口控制器
    

