package com.basketballai.visionsensoredge.service;

import com.basketballai.visionsensoredge.config.VisionSensorProperties;
import org.apache.commons.codec.binary.Hex;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;

@Service
public class AuthService {
    
    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);
    private static final String HMAC_SHA256_ALGORITHM = "HmacSHA256";
    
    private final VisionSensorProperties properties;
    
    @Autowired
    public AuthService(VisionSensorProperties properties) {
        this.properties = properties;
    }
    
    /**
     * 验证请求鉴权
     * @param token X-Auth-Token header值
     * @param timestamp X-Timestamp header值
     * @param signature X-Signature header值
     * @param body 请求体
     * @return 鉴权是否通过
     */
    public boolean validateAuth(String token, String timestamp, String signature, String body) {
        String secret = properties.getIngestAuthToken();
        
        // 如果没有配置secret，则不需要鉴权
        if (StringUtils.isEmpty(secret)) {
            return true;
        }
        
        // Token鉴权
        if (StringUtils.isNotEmpty(token) && secret.equals(token)) {
            return true;
        }
        
        // HMAC签名鉴权
        if (StringUtils.isNotEmpty(timestamp) && StringUtils.isNotEmpty(signature)) {
            // 可选：限制时间窗口5分钟，避免重放攻击
            try {
                double ts = Double.parseDouble(timestamp);
                if (Math.abs(System.currentTimeMillis() / 1000.0 - ts) > 300) {
                    logger.warn("Request timestamp expired: {}", timestamp);
                    return false;
                }
            } catch (NumberFormatException e) {
                logger.warn("Invalid timestamp format: {}", timestamp);
                return false;
            }
            
            // 验证签名
            String expectedSignature = generateHmacSignature(secret, timestamp, body);
            return expectedSignature != null && expectedSignature.equals(signature);
        }
        
        return false;
    }
    
    /**
     * 生成HMAC签名
     * @param secret 密钥
     * @param timestamp 时间戳
     * @param body 请求体
     * @return 签名或null（如果出错）
     */
    private String generateHmacSignature(String secret, String timestamp, String body) {
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256_ALGORITHM);
            SecretKeySpec secretKeySpec = new SecretKeySpec(secret.getBytes(), HMAC_SHA256_ALGORITHM);
            mac.init(secretKeySpec);
            
            String data = timestamp + "\n" + body;
            byte[] rawHmac = mac.doFinal(data.getBytes());
            return Hex.encodeHexString(rawHmac);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            logger.error("Error generating HMAC signature: {}", e.getMessage(), e);
            return null;
        }
    }
}
