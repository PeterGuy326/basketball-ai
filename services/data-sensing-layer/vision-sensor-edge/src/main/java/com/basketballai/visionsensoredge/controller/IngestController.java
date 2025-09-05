package com.basketballai.visionsensoredge.controller;

import com.basketballai.visionsensoredge.dto.IngestRequest;
import com.basketballai.visionsensoredge.service.AuthService;
import com.basketballai.visionsensoredge.service.KafkaService;
import com.basketballai.visionsensoredge.service.RateLimitService;
import com.basketballai.visionsensoredge.config.VisionSensorProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.codec.binary.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

@RestController
public class IngestController {
    
    private static final Logger logger = LoggerFactory.getLogger(IngestController.class);
    
    private final KafkaService kafkaService;
    private final AuthService authService;
    private final RateLimitService rateLimitService;
    private final VisionSensorProperties properties;
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    @Autowired
    public IngestController(KafkaService kafkaService, AuthService authService, 
                           RateLimitService rateLimitService, VisionSensorProperties properties) {
        this.kafkaService = kafkaService;
        this.authService = authService;
        this.rateLimitService = rateLimitService;
        this.properties = properties;
    }
    
    @PostMapping("/ingest")
    public ResponseEntity<String> ingest(HttpServletRequest request, @RequestBody(required = false) String body) {
        try {
            // 检查速率限制
            if (rateLimitService.isRateLimited()) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body("rate limited");
            }
            
            // 鉴权验证
            String token = request.getHeader("X-Auth-Token");
            String timestamp = request.getHeader("X-Timestamp");
            String signature = request.getHeader("X-Signature");
            
            if (!authService.validateAuth(token, timestamp, signature, body)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("unauthorized");
            }
            
            // 解析请求体
            String frameBase64 = null;
            double timestampValue = System.currentTimeMillis() / 1000.0;
            
            String contentType = request.getContentType();
            if (contentType != null) {
                contentType = contentType.toLowerCase();
            }
            
            if (contentType != null && contentType.contains("application/json")) {
                // JSON格式
                if (body == null || body.isEmpty()) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("missing body");
                }
                
                try {
                    IngestRequest ingestRequest = objectMapper.readValue(body, IngestRequest.class);
                    frameBase64 = ingestRequest.getFrame();
                    if (ingestRequest.getTimestamp() != null) {
                        timestampValue = ingestRequest.getTimestamp();
                    }
                } catch (IOException e) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("invalid json");
                }
                
                if (frameBase64 == null || frameBase64.isEmpty()) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("missing frame");
                }
            } else if (contentType != null && contentType.startsWith("image/")) {
                // 图像二进制格式
                if (body == null || body.isEmpty()) {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("missing body");
                }
                
                // 编码为Base64
                frameBase64 = Base64.encodeBase64String(body.getBytes(StandardCharsets.ISO_8859_1));
                
                // 获取时间戳
                String tsHeader = request.getHeader("X-Timestamp");
                if (tsHeader != null && !tsHeader.isEmpty()) {
                    try {
                        timestampValue = Double.parseDouble(tsHeader);
                    } catch (NumberFormatException e) {
                        // 使用默认时间戳
                    }
                }
            } else {
                // 兜底处理：尝试按JSON解析，否则按二进制处理
                if (body != null && !body.isEmpty()) {
                    try {
                        IngestRequest ingestRequest = objectMapper.readValue(body, IngestRequest.class);
                        frameBase64 = ingestRequest.getFrame();
                        if (ingestRequest.getTimestamp() != null) {
                            timestampValue = ingestRequest.getTimestamp();
                        }
                    } catch (IOException e) {
                        // 按二进制处理
                        frameBase64 = Base64.encodeBase64String(body.getBytes(StandardCharsets.ISO_8859_1));
                        String tsHeader = request.getHeader("X-Timestamp");
                        if (tsHeader != null && !tsHeader.isEmpty()) {
                            try {
                                timestampValue = Double.parseDouble(tsHeader);
                            } catch (NumberFormatException e2) {
                                // 使用默认时间戳
                            }
                        }
                    }
                    
                    if (frameBase64 == null || frameBase64.isEmpty()) {
                        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("missing frame");
                    }
                } else {
                    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("missing body");
                }
            }
            
            // 验证Base64格式
            if (!Base64.isBase64(frameBase64)) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("invalid base64");
            }
            
            // 构造消息并发送到Kafka
            Map<String, Object> message = new HashMap<>();
            message.put("timestamp", timestampValue);
            message.put("frame", frameBase64);
            message.put("source", "vision-http-ingest");
            
            String jsonMessage = objectMapper.writeValueAsString(message);
            kafkaService.send(properties.getKafka().getVideoTopic(), jsonMessage);
            
            return ResponseEntity.ok("ok");
        } catch (Exception e) {
            logger.error("Error processing ingest request: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("error");
        }
    }
}
