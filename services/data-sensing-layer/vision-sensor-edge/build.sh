#!/bin/bash

# 构建Java项目
echo "Building Java project..."
mvn clean package

# 检查构建是否成功
if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "To run the application, use: java -jar target/vision-sensor-edge-1.0.0.jar"
    echo "To build and run with Docker, use: docker build -t vision-sensor-edge . && docker run -p 8080:8080 vision-sensor-edge"
else
    echo "Build failed!"
    exit 1
fi
