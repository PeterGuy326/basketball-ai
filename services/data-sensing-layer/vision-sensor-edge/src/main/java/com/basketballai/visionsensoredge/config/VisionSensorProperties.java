package com.basketballai.visionsensoredge.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "vision.sensor")
public class VisionSensorProperties {
    
    private String inputMode = "http_receiver";
    private String httpPort = "8080";
    private String ingestAuthToken = "";
    private int ingestRpsLimit = 100;
    private Kafka kafka = new Kafka();
    private Service service = new Service();
    
    public static class Kafka {
        private String brokers = "localhost:9092";
        private String videoTopic = "video.data";
        
        // Getters and setters
        public String getBrokers() {
            return brokers;
        }
        
        public void setBrokers(String brokers) {
            this.brokers = brokers;
        }
        
        public String getVideoTopic() {
            return videoTopic;
        }
        
        public void setVideoTopic(String videoTopic) {
            this.videoTopic = videoTopic;
        }
    }
    
    public static class Service {
        private String host = "0.0.0.0";
        
        // Getters and setters
        public String getHost() {
            return host;
        }
        
        public void setHost(String host) {
            this.host = host;
        }
    }
    
    // Getters and setters
    public String getInputMode() {
        return inputMode;
    }
    
    public void setInputMode(String inputMode) {
        this.inputMode = inputMode;
    }
    
    public String getHttpPort() {
        return httpPort;
    }
    
    public void setHttpPort(String httpPort) {
        this.httpPort = httpPort;
    }
    
    public String getIngestAuthToken() {
        return ingestAuthToken;
    }
    
    public void setIngestAuthToken(String ingestAuthToken) {
        this.ingestAuthToken = ingestAuthToken;
    }
    
    public int getIngestRpsLimit() {
        return ingestRpsLimit;
    }
    
    public void setIngestRpsLimit(int ingestRpsLimit) {
        this.ingestRpsLimit = ingestRpsLimit;
    }
    
    public Kafka getKafka() {
        return kafka;
    }
    
    public void setKafka(Kafka kafka) {
        this.kafka = kafka;
    }
    
    public Service getService() {
        return service;
    }
    
    public void setService(Service service) {
        this.service = service;
    }
}
