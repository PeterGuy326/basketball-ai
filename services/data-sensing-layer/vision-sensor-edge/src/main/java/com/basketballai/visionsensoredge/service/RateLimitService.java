package com.basketballai.visionsensoredge.service;

import com.basketballai.visionsensoredge.config.VisionSensorProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class RateLimitService {
    
    private static final Logger logger = LoggerFactory.getLogger(RateLimitService.class);
    
    private final VisionSensorProperties properties;
    private final ConcurrentHashMap<Integer, AtomicInteger> requestCounts = new ConcurrentHashMap<>();
    
    @Autowired
    public RateLimitService(VisionSensorProperties properties) {
        this.properties = properties;
        
        // 启动一个线程定期清理过期的计数器
        Thread cleanupThread = new Thread(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    Thread.sleep(60000); // 每分钟清理一次
                    int currentSecond = (int) (System.currentTimeMillis() / 1000);
                    requestCounts.entrySet().removeIf(entry -> entry.getKey() < currentSecond - 60);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        });
        cleanupThread.setDaemon(true);
        cleanupThread.start();
    }
    
    /**
     * 检查是否超过速率限制
     * @return true表示超过限制，false表示未超过
     */
    public boolean isRateLimited() {
        int limit = properties.getIngestRpsLimit();
        
        // 如果限制为0或负数，则不限制
        if (limit <= 0) {
            return false;
        }
        
        int currentSecond = (int) (System.currentTimeMillis() / 1000);
        AtomicInteger count = requestCounts.computeIfAbsent(currentSecond, k -> new AtomicInteger(0));
        
        int currentCount = count.incrementAndGet();
        
        // 检查是否超过限制
        if (currentCount > limit) {
            logger.warn("Rate limit exceeded: {} requests in second {}, limit is {}", currentCount, currentSecond, limit);
            return true;
        }
        
        return false;
    }
}
