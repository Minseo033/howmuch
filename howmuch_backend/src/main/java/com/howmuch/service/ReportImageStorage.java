package com.howmuch.service;

import java.util.Collection;

public interface ReportImageStorage {

    String upload(String ownerUid, byte[] bytes, String contentType) throws Exception;

    boolean isOwnedBy(String ownerUid, String imageUrl);

    int deleteOwned(String ownerUid, Collection<String> imageUrls) throws Exception;

    int deleteAllOwned(String ownerUid) throws Exception;
}
