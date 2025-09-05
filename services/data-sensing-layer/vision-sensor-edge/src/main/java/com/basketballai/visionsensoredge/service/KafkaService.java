package com.basketballai.visionsensoredge.service;

import com.basketballai.visionsensoredge.config.VisionSensorProperties;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.util.HashMap;
import java.util.Map;

@Service
public class KafkaService {
    
    private static final Logger logger = LoggerFactory.getLogger(KafkaService.class);
    
    private final VisionSensorProperties properties;
    private KafkaTemplate<String, String> kafkaTemplate;
    
    @Autowired
    public KafkaService(VisionSensorProperties properties) {
        this.properties = properties;
    }
    
    @PostConstruct
    public void init() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, properties.getKafka().getBrokers());
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.ACKS_CONFIG, "1");
        props.put(ProducerConfig.RETRIES_CONFIG, 3);
        
        ProducerFactory<String, String> producerFactory = new DefaultKafkaProducerFactory<>(props);
        this.kafkaTemplate = new KafkaTemplate<>(producerFactory);
        
        logger.info("Kafka service initialized with brokers: {}", properties.getKafka().getBrokers());
    }
    
    public void send(String topic, String message) {
        try {
            kafkaTemplate.send(topic, message);
        } catch (Exception e) {
            logger.error("Error sending message to Kafka topic {}: {}", topic, e.getMessage(), e);
        }
    }
    
    @PreDestroy
    public void close() {
        if (kafkaTemplate != null) {
            kafkaTemplate.destroy();
        }
    }
}
