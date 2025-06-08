package com.example.application;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

@RestController
class ApiController {
    @GetMapping("/")
    public Map<String, Object> root() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Welcome to your Spring Boot application");
        response.put("version", "1.0.0");
        response.put("status", "running");
        return response;
    }
    
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
    
    @GetMapping("/api/data")
    public List<Map<String, Object>> getData() {
        return Arrays.asList(
            Map.of("id", 1, "name", "Item 1"),
            Map.of("id", 2, "name", "Item 2"),
            Map.of("id", 3, "name", "Item 3")
        );
    }
}
