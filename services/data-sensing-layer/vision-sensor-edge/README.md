# Vision Sensor Edge Service (Java版本)

这是篮球AI系统的边缘计算服务，负责接收来自iOS设备的视频流数据并将其转发到Kafka消息队列。

## 功能特性

- HTTP端点接收视频帧数据（POST /ingest）
- 支持Token和HMAC签名两种鉴权方式
- 速率限制（RPS）
- Kafka集成
- 配置管理

## 技术栈

- Java 11
- Spring Boot 2.7.0
- Spring Kafka
- Maven 3.6+

## 构建和运行

### 使用Maven构建

```bash
# 克隆项目后，进入项目根目录
cd basketball-ai

# 构建项目
./build.sh
```

或者手动构建：

```bash
# 构建项目
mvn clean package

# 运行服务
java -jar target/vision-sensor-edge-1.0.0.jar
```

### 使用Docker构建和运行

```bash
# 构建Docker镜像
docker build -t vision-sensor-edge services/data-sensing-layer/vision-sensor-edge

# 运行容器
docker run -p 8080:8080 vision-sensor-edge
```

## 配置

服务配置在 `src/main/resources/application.yml` 文件中：

```yaml
server:
  port: 8080
  address: 0.0.0.0

vision:
  sensor:
    input-mode: http_receiver
    http-port: "8080"
    ingest-auth-token: ""  # 鉴权token，留空则不启用鉴权
    ingest-rps-limit: 100  # 每秒请求数限制
    kafka:
      brokers: localhost:9092  # Kafka broker地址
      video-topic: video.data   # 视频数据主题
    service:
      host: 0.0.0.0

spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
      acks: 1
      retries: 3
```

## API端点

### POST /ingest

接收视频帧数据。

#### 请求头

- `Content-Type`: 
  - `application/json` - JSON格式
  - `image/*` - 图像二进制格式
- `X-Auth-Token`: 鉴权token（可选，如果配置了鉴权）
- `X-Timestamp`: 时间戳（可选）
- `X-Signature`: HMAC签名（可选，如果使用签名鉴权）

#### 请求体

JSON格式：
```json
{
  "frame": "base64_encoded_image_data",
  "timestamp": 1623456789.123
}
```

或者图像二进制格式（需要设置相应的Content-Type）。

#### 响应

- `200 OK`: 成功
- `400 Bad Request`: 请求格式错误
- `401 Unauthorized`: 鉴权失败
- `429 Too Many Requests`: 速率限制
- `500 Internal Server Error`: 服务器内部错误

## 鉴权

支持两种鉴权方式：

1. **Token鉴权**：在请求头中设置 `X-Auth-Token` 字段，值为配置文件中的 `ingest-auth-token`。
2. **HMAC签名鉴权**：
   - 在请求头中设置 `X-Timestamp` 字段（时间戳）。
   - 在请求头中设置 `X-Signature` 字段，值为HMAC-SHA256签名。
   - 签名计算方式：`HMAC-SHA256(secret, timestamp + "\n" + body)`

## 速率限制

通过 `ingest-rps-limit` 配置每秒请求数限制。设置为0或负数则不限制。

## 与Python版本的差异

| 特性 | Python版本 | Java版本 |
|------|------------|----------|
| 性能 | 较低 | 高 |
| 内存占用 | 较高 | 低 |
| 启动时间 | 快 | 较慢 |
| 并发处理 | 受GIL限制 | 优秀 |
| 部署 | 简单 | 需要JVM |

## 开发

### 项目结构

```
src/main/java/com/basketballai/visionsensoredge/
├── VisionSensorEdgeApplication.java  # 主应用类
├── config/
│   └── VisionSensorProperties.java    # 配置属性类
├── controller/
│   └── IngestController.java          # HTTP控制器
├── service/
│   ├── AuthService.java               # 鉴权服务
│   ├── KafkaService.java              # Kafka服务
│   └── RateLimitService.java          # 速率限制服务
└── dto/
    └── IngestRequest.java             # 数据传输对象
```

### 添加新功能

1. 在 `service` 包中创建新的服务类
2. 在 `controller` 包中添加相应的端点
3. 如需要，在 `dto` 包中创建数据传输对象
4. 更新 `application.yml` 中的配置

## 许可证

[待定]
