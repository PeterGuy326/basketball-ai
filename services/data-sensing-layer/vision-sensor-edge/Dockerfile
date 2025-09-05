FROM openjdk:11-jre-slim

# 使用精简版基础镜像，仅安装必要运行时
WORKDIR /workspace

# 复制Maven构建的应用程序
COPY target/vision-sensor-edge-1.0.0.jar app.jar

# 设置JVM参数并启动应用
ENV JAVA_OPTS="-Xmx512m -Xms256m"

EXPOSE 8080

WORKDIR /workspace

CMD ["java", "-jar", "app.jar"]
