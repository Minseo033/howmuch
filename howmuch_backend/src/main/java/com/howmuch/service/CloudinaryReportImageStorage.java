package com.howmuch.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.regex.Pattern;

@Service
public class CloudinaryReportImageStorage implements ReportImageStorage {

    private static final Pattern SAFE_FOLDER = Pattern.compile(
            "[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*");
    private static final Pattern SAFE_PUBLIC_ID = Pattern.compile(
            "[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*");
    private static final Pattern VERSION_SEGMENT = Pattern.compile("v[0-9]+");
    private static final Pattern SUPPORTED_EXTENSION = Pattern.compile(
            "(?i)jpe?g|png|webp");

    private final Cloudinary cloudinary;
    private final String cloudName;
    private final String reportFolder;

    public CloudinaryReportImageStorage(
            @Value("${cloudinary.url:}") String cloudinaryUrl,
            @Value("${cloudinary.report-folder:howmuch/report-images}") String reportFolder) {
        this.reportFolder = normalizeFolder(reportFolder);
        if (cloudinaryUrl == null || cloudinaryUrl.isBlank()) {
            this.cloudinary = null;
            this.cloudName = "";
            return;
        }

        this.cloudinary = new Cloudinary(cloudinaryUrl.trim());
        this.cloudName = Objects.toString(this.cloudinary.config.cloudName, "");
    }

    @Override
    public String upload(String ownerUid, byte[] bytes, String contentType) throws Exception {
        Cloudinary client = requireConfigured();
        String publicId = ownerPrefix(ownerUid) + "/" + UUID.randomUUID();
        Map<?, ?> response = client.uploader().upload(bytes, ObjectUtils.asMap(
                "public_id", publicId,
                "resource_type", "image",
                "type", "upload",
                "format", formatFor(contentType),
                "overwrite", false));

        String uploadedPublicId = Objects.toString(response.get("public_id"), "");
        String secureUrl = Objects.toString(response.get("secure_url"), "");
        if (!publicId.equals(uploadedPublicId)
                || !publicId.equals(publicIdFromOwnedUrl(ownerUid, secureUrl))) {
            destroyQuietly(client, publicId);
            throw new IllegalStateException("Cloudinary returned an invalid image response.");
        }
        return secureUrl;
    }

    @Override
    public boolean isOwnedBy(String ownerUid, String imageUrl) {
        return publicIdFromOwnedUrl(ownerUid, imageUrl) != null;
    }

    @Override
    public int deleteOwned(String ownerUid, Collection<String> imageUrls) throws Exception {
        if (imageUrls == null || imageUrls.isEmpty()) return 0;
        Cloudinary client = requireConfigured();
        int deleted = 0;
        for (String imageUrl : imageUrls) {
            String publicId = publicIdFromOwnedUrl(ownerUid, imageUrl);
            if (publicId == null) continue;
            Map<?, ?> response = client.uploader().destroy(publicId, ObjectUtils.asMap(
                    "resource_type", "image",
                    "type", "upload",
                    "invalidate", true));
            if ("ok".equals(response.get("result"))) deleted++;
        }
        return deleted;
    }

    @Override
    public int deleteAllOwned(String ownerUid) throws Exception {
        Cloudinary client = requireConfigured();
        String prefix = ownerPrefix(ownerUid) + "/";
        String nextCursor = null;
        int deleted = 0;
        do {
            Map<String, Object> options = new HashMap<>();
            options.put("resource_type", "image");
            options.put("type", "upload");
            options.put("invalidate", true);
            if (nextCursor != null) options.put("next_cursor", nextCursor);

            Map<?, ?> response = client.api().deleteResourcesByPrefix(prefix, options);
            Object deletedItems = response.get("deleted");
            if (deletedItems instanceof Map<?, ?> items) {
                deleted += (int) items.values().stream()
                        .filter("deleted"::equals)
                        .count();
            }
            nextCursor = stringOrNull(response.get("next_cursor"));
        } while (nextCursor != null);
        return deleted;
    }

    String publicIdFromOwnedUrl(String ownerUid, String imageUrl) {
        if (cloudName.isBlank() || ownerUid == null || ownerUid.isBlank()
                || imageUrl == null || imageUrl.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(imageUrl);
            if (!"https".equalsIgnoreCase(uri.getScheme())
                    || !"res.cloudinary.com".equalsIgnoreCase(uri.getHost())
                    || uri.getPort() != -1
                    || uri.getUserInfo() != null
                    || uri.getRawQuery() != null
                    || uri.getRawFragment() != null) {
                return null;
            }

            String rawPath = uri.getRawPath();
            String pathPrefix = "/" + cloudName + "/image/upload/";
            if (rawPath == null || rawPath.contains("%") || !rawPath.startsWith(pathPrefix)) {
                return null;
            }

            String remainder = rawPath.substring(pathPrefix.length());
            int versionEnd = remainder.indexOf('/');
            if (versionEnd <= 0
                    || !VERSION_SEGMENT.matcher(remainder.substring(0, versionEnd)).matches()) {
                return null;
            }

            String pathWithExtension = remainder.substring(versionEnd + 1);
            int lastSlash = pathWithExtension.lastIndexOf('/');
            int extensionStart = pathWithExtension.lastIndexOf('.');
            if (extensionStart <= lastSlash
                    || !SUPPORTED_EXTENSION.matcher(
                            pathWithExtension.substring(extensionStart + 1)).matches()) {
                return null;
            }

            String publicId = pathWithExtension.substring(0, extensionStart);
            String ownerPrefix = ownerPrefix(ownerUid) + "/";
            return SAFE_PUBLIC_ID.matcher(publicId).matches()
                    && publicId.startsWith(ownerPrefix)
                    ? publicId
                    : null;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    String ownerPrefix(String ownerUid) {
        if (ownerUid == null || ownerUid.isBlank()) {
            throw new SecurityException("로그인이 필요합니다.");
        }
        return reportFolder + "/" + sha256(ownerUid);
    }

    private Cloudinary requireConfigured() {
        if (cloudinary == null
                || cloudName.isBlank()
                || cloudinary.config.apiKey == null
                || cloudinary.config.apiKey.isBlank()
                || cloudinary.config.apiSecret == null
                || cloudinary.config.apiSecret.isBlank()) {
            throw new IllegalStateException("Cloudinary image storage is not configured.");
        }
        return cloudinary;
    }

    private void destroyQuietly(Cloudinary client, String publicId) {
        try {
            client.uploader().destroy(publicId, ObjectUtils.asMap(
                    "resource_type", "image",
                    "type", "upload",
                    "invalidate", true));
        } catch (Exception ignored) {
            // The original upload error is more useful to the caller.
        }
    }

    private String formatFor(String contentType) {
        return switch (contentType) {
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            case "image/jpeg" -> "jpg";
            default -> throw new IllegalArgumentException("Unsupported report image type.");
        };
    }

    private static String normalizeFolder(String value) {
        String folder = value == null || value.isBlank()
                ? "howmuch/report-images"
                : value.trim().replaceAll("^/+|/+$", "");
        if (!SAFE_FOLDER.matcher(folder).matches()) {
            throw new IllegalArgumentException("Invalid Cloudinary report image folder.");
        }
        return folder;
    }

    private static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is unavailable.", e);
        }
    }

    private static String stringOrNull(Object value) {
        if (value == null || value.toString().isBlank()) return null;
        return value.toString();
    }
}
