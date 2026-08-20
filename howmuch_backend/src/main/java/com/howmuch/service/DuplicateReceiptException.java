package com.howmuch.service;

public class DuplicateReceiptException extends RuntimeException {
    public DuplicateReceiptException(String message) {
        super(message);
    }
}
