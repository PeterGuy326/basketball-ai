package com.basketballai.visionsensoredge.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class IngestRequest {
    
    private String frame;
    
    private Double timestamp;
    
    public IngestRequest() {
    }
    
    public IngestRequest(String frame, Double timestamp) {
        this.frame = frame;
        this.timestamp = timestamp;
    }
    
    public String getFrame() {
        return frame;
    }
    
    public void setFrame(String frame) {
        this.frame = frame;
    }
    
    public Double getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(Double timestamp) {
        this.timestamp = timestamp;
    }
}
