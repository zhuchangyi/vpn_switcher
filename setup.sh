#!/bin/bash

# 读取VPN用户名和密码
read -p "Enter VPN username: " VPN_USERNAME
read -sp "Enter VPN password: " VPN_PASSWORD
echo

# 将用户名和密码写入credentials.txt文件
echo "$VPN_USERNAME" > credentials.txt
echo "$VPN_PASSWORD" >> credentials.txt
echo "credentials.txt file created with your VPN credentials."

# 检查 /etc/openvpn 目录
echo "Checking /etc/openvpn directory..."
if ! ls -l /etc/openvpn; then
    echo "Error: /etc/openvpn directory not found!"
    exit 1
fi

# 检查 /etc/openvpn/tcp 目录
echo "Checking /etc/openvpn/tcp directory..."
if ! ls -l /etc/openvpn/tcp; then
    echo "Error: /etc/openvpn/tcp directory not found!"
    exit 1
fi

# 检查 /etc/openvpn/udp 目录
echo "Checking /etc/openvpn/udp directory..."
if ! ls -l /etc/openvpn/udp; then
    echo "Error: /etc/openvpn/udp directory not found!"
    exit 1
fi

# 获取默认网关
default_gateway=$(ip route | grep default | awk '{print $3}')
if [ -z "$default_gateway" ]; then
    echo "Error: Unable to find the default gateway!"
    exit 1
fi

# 获取本地网络的子网和子网掩码
local_subnet=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')
if [ -z "$local_subnet" ]; then
    echo "Error: Unable to find the local subnet!"
    exit 1
fi

# 定义要遍历的目录
directories=("/etc/openvpn/tcp" "/etc/openvpn/udp")

# 遍历每个目录
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        # 查找目录中的所有 .ovpn 文件
        for file in "$dir"/*.ovpn; do
            # 检查文件是否存在
            if [[ -f "$file" ]]; then
                # 检查并添加 route-nopull 和 route 指令
                if ! grep -q "route-nopull" "$file"; then
                    echo "route-nopull" >> "$file"
                fi
                # 将本地子网和默认网关添加到路由
                if ! grep -q "route $local_subnet net_gateway" "$file"; then
                    echo "route $local_subnet $default_gateway" >> "$file"
                fi
                echo "已更新文件: $file"
            else
                echo "文件不存在: $file"
                exit 1
            fi
        done
    else
        echo "目录不存在: $dir"
        exit 1
    fi
done

echo "所有文件处理完毕。"

# 复制credentials文件到 /etc/openvpn
if ! cp /app/credentials.txt /etc/openvpn/credentials.txt; then
    echo "Error: Failed to copy credentials.txt to /etc/openvpn!"
    exit 1
fi
chmod 600 /etc/openvpn/credentials.txt

# 更新所有 .ovpn 文件以使用凭证文件
CREDENTIALS_LINE="auth-user-pass /etc/openvpn/credentials.txt"

for dir in /etc/openvpn/tcp /etc/openvpn/udp; do
    if [ -d "$dir" ]; then
        for ovpn_file in "$dir"/*.ovpn; do
            if grep -q "auth-user-pass" "$ovpn_file"; then
                # 替换现有的auth-user-pass行
                echo "Replacing credentials line in $ovpn_file"
                sed -i "s|auth-user-pass.*|$CREDENTIALS_LINE|" "$ovpn_file"
            else
                # 如果auth-user-pass行不存在，则添加
                echo "Adding credentials line to $ovpn_file"
                echo "$CREDENTIALS_LINE" >> "$ovpn_file"
            fi
        done
    else
        echo "目录不存在: $dir"
        exit 1
    fi
done

# 启动Flask应用程序
if ! sudo FLASK_APP=app.py flask run --host=0.0.0.0 --port=5000; then
    echo "Error: Failed to start the Flask app!"
    exit 1
fi

