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

# 获取本地网络的子网
local_subnet=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n1)
if [ -z "$local_subnet" ]; then
    echo "Error: Unable to find the local subnet!"
    exit 1
fi

# 生成 route 命令
route_command="route ${local_subnet%/*} 255.255.255.255 $default_gateway"

# 输出需要添加的内容并清理多余行
echo "Generated route command:"
route_command_cleaned=$(echo "$route_command" | awk 'NR==1')
echo "$route_command_cleaned"

# 定义要遍历的目录
directories=("/etc/openvpn/tcp" "/etc/openvpn/udp")

# 遍历每个目录
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        # 查找目录中的所有 .ovpn 文件
        for file in "$dir"/*.ovpn; do
            # 检查文件是否存在
            if [[ -f "$file" ]]; then
                echo "Processing file: $file"
                
                # 删除现有的 'route' 行
                sed -i "/^route .* 255.255.255.255 $default_gateway$/d" "$file"

                # 添加新的路由命令
                echo "$route_command_cleaned" >> "$file"

                # 删除多余的 'route' 行，只保留最后一行
                awk '!/^route / || !x++' "$file" > temp && mv temp "$file"

                # 确保文件中没有多余的内容
                # 删除所有单独一行的 default_gateway
                sed -i "/^$default_gateway$/d" "$file"

                # 更新 auth-user-pass 行
                CREDENTIALS_LINE="auth-user-pass /etc/openvpn/credentials.txt"
                if grep -q "^auth-user-pass" "$file"; then
                    sed -i "s|^auth-user-pass.*|$CREDENTIALS_LINE|" "$file"
                else
                    echo "$CREDENTIALS_LINE" >> "$file"
                fi

                # 添加 route-nopull 行
                if ! grep -q "^route-nopull" "$file"; then
                    echo "route-nopull" >> "$file"
                fi
                
                echo "Updated file: $file"
            else
                echo "File not found: $file"
                exit 1
            fi
        done
    else
        echo "Directory not found: $dir"
        exit 1
    fi
done

echo "All files processed."

# 复制credentials文件到 /etc/openvpn
if ! cp credentials.txt /etc/openvpn/credentials.txt; then
    echo "Error: Failed to copy credentials.txt to /etc/openvpn!"
    exit 1
fi
chmod 600 /etc/openvpn/credentials.txt

# 启动Flask应用程序
if ! sudo FLASK_APP=app.py flask run --host=0.0.0.0 --port=5000; then
    echo "Error: Failed to start the Flask app!"
    exit 1
fi
