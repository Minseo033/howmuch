package com.howmuch.service;

public class DuplicateVisitException extends RuntimeException {
    public DuplicateVisitException(String message) {
        super(message);
    }
}
