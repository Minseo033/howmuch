package com.howmuch.service;

/** OCR 공급자가 실제 판독 증거를 만들지 못한 영수증의 승인을 차단합니다. */
public class ReceiptOcrEvidenceException extends IllegalArgumentException {
    public ReceiptOcrEvidenceException(String message) {
        super(message);
    }
}
