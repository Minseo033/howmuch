package com.howmuch;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class HowMuchApplication {

    public static void main(String[] args) {
        SpringApplication.run(HowMuchApplication.class, args);
    }

}
