package com.howmuch.service;

/** 요청한 영수증 인증 문서가 존재하지 않을 때 사용합니다. */
public class ReceiptVerificationNotFoundException extends IllegalArgumentException {
    public ReceiptVerificationNotFoundException(String message) {
        super(message);
    }
}
