#!/bin/bash

# Vision Sensor Edge 网络连接检测和配置工具
# 合并了连接测试和网络分析功能

echo "🌐 Vision Sensor Edge 网络连接工具"
echo "=================================="
echo

# ===== 第一部分: 网络接口分析 =====
echo "📍 1. 本机网络接口分析"
echo "------------------------"

# 获取主要网络接口的IP
ACTIVE_IP=""
for interface in en0 en1 eth0; do
    if ifconfig "$interface" >/dev/null 2>&1; then
        IP=$(ifconfig "$interface" | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
        if [ ! -z "$IP" ]; then
            STATUS=$(ifconfig "$interface" | grep "status:" | awk '{print $2}')
            echo "🔗 $interface: $IP (状态: ${STATUS:-active})"
            if [ -z "$ACTIVE_IP" ]; then
                ACTIVE_IP="$IP"
            fi
        fi
    fi
done

# 如果没有找到活动IP，使用通用方法
if [ -z "$ACTIVE_IP" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ACTIVE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    else
        # Linux
        ACTIVE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    fi
fi

echo "主要IP地址: ${ACTIVE_IP:-未找到}"

# 获取网络信息
if [ ! -z "$ACTIVE_IP" ]; then
    NETMASK=$(ifconfig | grep "inet $ACTIVE_IP" | awk '{print $4}')
    echo "子网掩码: ${NETMASK:-未知}"
    
    # 计算网络段
    if command -v python3 >/dev/null 2>&1 && [ ! -z "$NETMASK" ]; then
        NETWORK_INFO=$(python3 -c "
import ipaddress
import sys
try:
    if '$NETMASK'.startswith('0x'):
        # 转换十六进制子网掩码为十进制
        mask_hex = '$NETMASK'
        mask_int = int(mask_hex, 16)
        # 计算前缀长度
        prefix_len = bin(mask_int).count('1')
        network = ipaddress.ip_network('$ACTIVE_IP/' + str(prefix_len), strict=False)
        print(f'网络段: {network}')
        hosts = list(network.hosts())
        if hosts:
            print(f'可用IP范围: {hosts[0]} - {hosts[-1]}')
        else:
            print('单主机网络')
    else:
        print('无法解析子网掩码格式')
except Exception as e:
    print(f'网络计算出错: {e}')
" 2>/dev/null)
        if [ ! -z "$NETWORK_INFO" ]; then
            echo "$NETWORK_INFO"
        fi
    fi
fi

echo

# ===== 第二部分: 服务连通性测试 =====
echo "🔍 2. Vision Sensor Edge 服务检测"
echo "-----------------------------------"

# 检查Java服务是否在运行
echo -n "检查本地服务 (localhost:8080) ... "
if curl -s --connect-timeout 3 http://localhost:8080/ingest > /dev/null 2>&1; then
    echo "✅ 运行正常"
    LOCAL_WORKS=true
else 
    echo "❌ 未运行"
    LOCAL_WORKS=false
fi

# 测试通过IP访问
if [ ! -z "$ACTIVE_IP" ] && [ "$ACTIVE_IP" != "127.0.0.1" ]; then
    echo -n "检查IP访问 ($ACTIVE_IP:8080) ... "
    if curl -s --connect-timeout 3 http://$ACTIVE_IP:8080/ingest > /dev/null 2>&1; then
        echo "✅ 可访问"
        IP_WORKS=true
        RECOMMENDED_URL="http://$ACTIVE_IP:8080/ingest"
    else
        echo "❌ 不可访问"
        IP_WORKS=false
        RECOMMENDED_URL="http://localhost:8080/ingest"
    fi
else
    echo "⚠️ 无有效IP地址，跳过IP测试"
    IP_WORKS=false
    RECOMMENDED_URL="http://localhost:8080/ingest"
fi

echo

# ===== 第三部分: 功能测试 =====
echo "🧪 3. 功能测试"
echo "---------------"

TEST_DATA='{"frame":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==","timestamp":1234567890}'

if [ "$LOCAL_WORKS" = true ]; then
    echo "发送测试数据到服务器..."
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Timestamp: $(date +%s)" \
        -d "$TEST_DATA" \
        -w "HTTP_CODE:%{http_code}" \
        http://localhost:8080/ingest 2>/dev/null)
    
    if [ ! -z "$RESPONSE" ]; then
        HTTP_CODE=$(echo $RESPONSE | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo $RESPONSE | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ 数据发送成功! 服务器响应: ${BODY:-ok}"
        else
            echo "❌ 数据发送失败! HTTP状态码: $HTTP_CODE, 响应: $BODY"
        fi
    else
        echo "⚠️ 无法获取服务器响应"
    fi
else
    echo "⏭️ 服务未运行，跳过功能测试"
fi

echo

# ===== 第四部分: 进程检查 =====
echo "⚙️ 4. 进程状态检查"
echo "-------------------"

JAVA_PID=$(ps aux | grep "vision-sensor-edge" | grep -v grep | awk '{print $2}')
if [ ! -z "$JAVA_PID" ]; then
    echo "✅ 找到vision-sensor-edge进程 (PID: $JAVA_PID)"
    
    # 显示Java进程信息
    JAVA_MEMORY=$(ps -o pid,rss,vsz,pcpu -p $JAVA_PID | tail -1 | awk '{print "内存: " $2/1024 "MB, CPU: " $4 "%"}')
    echo "   $JAVA_MEMORY"
else
    echo "❌ 未找到vision-sensor-edge进程"
    echo
    echo "启动服务的命令:"
    echo "  cd services/data-sensing-layer/vision-sensor-edge"
    echo "  mvn clean package"
    echo "  java -jar target/vision-sensor-edge-1.0.0.jar"
fi

echo

# ===== 第五部分: iOS配置建议 =====
echo "📱 5. iOS设备配置建议"
echo "----------------------"

if [ "$LOCAL_WORKS" = true ] || [ "$IP_WORKS" = true ]; then
    echo "根据检测结果，建议配置:"
    echo
    
    if [ "$IP_WORKS" = true ]; then
        echo "✅ iOS模拟器: http://localhost:8080/ingest"
        echo "✅ iOS真机: $RECOMMENDED_URL"
        echo
        echo "📋 配置步骤:"
        echo "   1. 确保iPhone和Mac连接同一WiFi网络"
        echo "   2. 在iOS应用中输入服务器地址: $RECOMMENDED_URL"
        echo "   3. 点击'测试连接'按钮验证连接"
        echo "   4. 点击录制按钮开始视频传输"
    else
        echo "🔶 iOS模拟器: http://localhost:8080/ingest"
        echo "🔶 iOS真机: 连接可能有问题，建议检查网络设置"
        echo
        echo "💡 解决真机连接问题:"
        echo "   1. 检查Mac防火墙设置"
        echo "   2. 确保iPhone和Mac在同一WiFi网络"
        echo "   3. 尝试重启WiFi连接"
    fi
else
    echo "❌ 服务未运行，请先启动vision-sensor-edge服务"
    echo
    echo "启动后重新运行此脚本进行测试"
fi

echo

# ===== 第六部分: 故障排除 =====
echo "🔧 6. 故障排除信息"
echo "-------------------"
echo "• 获取IP地址: ifconfig | grep 'inet ' | grep -v 127.0.0.1"
echo "• 检查端口: lsof -i :8080"
echo "• 查看服务日志: 检查Java服务控制台输出"
echo "• Mac网络设置: 系统偏好设置 > 网络 > Wi-Fi > 高级 > TCP/IP"
echo "• iPhone网络: 设置 > Wi-Fi > 点击网络名称查看IP信息"

echo

# ===== 第七部分: 总结 =====
echo "🎯 配置总结"
echo "============"
if [ ! -z "$ACTIVE_IP" ]; then
    echo "推荐服务器地址: $RECOMMENDED_URL"
    echo "网络IP地址: $ACTIVE_IP"
    echo "适用设备: iOS真机"
    echo "备用地址: http://localhost:8080/ingest (模拟器)"
else
    echo "推荐服务器地址: http://localhost:8080/ingest"
    echo "适用设备: iOS模拟器"
    echo "注意: 未检测到有效的网络IP地址"
fi

if [ "$LOCAL_WORKS" = true ]; then
    echo "服务状态: ✅ 正常运行"
else
    echo "服务状态: ❌ 需要启动"
fi