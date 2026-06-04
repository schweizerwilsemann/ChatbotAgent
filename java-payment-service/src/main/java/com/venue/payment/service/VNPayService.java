package com.venue.payment.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.text.Normalizer;
import java.time.Duration;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class VNPayService {

    private static final DateTimeFormatter VNPAY_DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private static final ZoneId VNPAY_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final String VNPAY_VERSION = "2.1.0";
    private static final Duration PAYMENT_EXPIRY = Duration.ofMinutes(15);

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${vnpay.tmn-code}")
    private String tmnCode;

    @Value("${vnpay.hash-secret}")
    private String hashSecret;

    @Value("${vnpay.payment-url}")
    private String paymentUrl;

    @Value("${vnpay.query-url}")
    private String queryUrl;

    public String createPaymentUrl(String orderId, long amount,
                                   String orderInfo, String returnUrl,
                                   String ipAddress, String orderType) {
        validateCreatePaymentInput(orderId, amount, orderInfo, returnUrl, ipAddress);

        Map<String, String> params = new TreeMap<>();
        params.put("vnp_Version", VNPAY_VERSION);
        params.put("vnp_Command", "pay");
        params.put("vnp_TmnCode", tmnCode);
        params.put("vnp_Amount", String.valueOf(Math.multiplyExact(amount, 100)));
        params.put("vnp_CurrCode", "VND");
        params.put("vnp_TxnRef", orderId);
        ZonedDateTime now = ZonedDateTime.now(VNPAY_ZONE);

        params.put("vnp_OrderInfo", normalizeOrderInfo(orderInfo, orderId));
        params.put("vnp_OrderType", toVnPayOrderType(orderType));
        params.put("vnp_Locale", "vn");
        params.put("vnp_ReturnUrl", returnUrl);
        params.put("vnp_IpAddr", ipAddress);
        params.put("vnp_CreateDate", formatVnPayDateTime(now));
        params.put("vnp_ExpireDate", formatVnPayDateTime(now.plus(PAYMENT_EXPIRY)));

        String hashData = buildHashData(params);
        String queryString = buildQueryString(params);
        String secureHash = hmacSHA512(hashSecret, hashData);
        return paymentUrl + "?" + queryString + "&vnp_SecureHash=" + secureHash;
    }

    public QueryResult queryTransaction(String orderId, String transactionDate, String ipAddress) {
        requireConfigured();
        requireText(queryUrl, "vnpay.query-url");
        requireText(orderId, "orderId");
        requireText(transactionDate, "transactionDate");
        requireText(ipAddress, "ipAddress");

        try {
            String requestId = UUID.randomUUID().toString().replace("-", "");
            String command = "querydr";
            String createDate = getCurrentDateTime();
            String orderInfo = "Query transaction " + orderId;

            Map<String, String> requestBody = new LinkedHashMap<>();
            requestBody.put("vnp_RequestId", requestId);
            requestBody.put("vnp_Version", VNPAY_VERSION);
            requestBody.put("vnp_Command", command);
            requestBody.put("vnp_TmnCode", tmnCode);
            requestBody.put("vnp_TxnRef", orderId);
            requestBody.put("vnp_OrderInfo", orderInfo);
            requestBody.put("vnp_TransactionDate", transactionDate);
            requestBody.put("vnp_CreateDate", createDate);
            requestBody.put("vnp_IpAddr", ipAddress);

            String checksumData = String.join("|",
                    requestId,
                    VNPAY_VERSION,
                    command,
                    tmnCode,
                    orderId,
                    transactionDate,
                    createDate,
                    ipAddress,
                    orderInfo
            );
            requestBody.put("vnp_SecureHash", hmacSHA512(hashSecret, checksumData));

            HttpRequest httpRequest = HttpRequest.newBuilder(URI.create(queryUrl))
                    .timeout(Duration.ofSeconds(10))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(requestBody)))
                    .build();

            HttpResponse<String> httpResponse = httpClient.send(
                    httpRequest,
                    HttpResponse.BodyHandlers.ofString()
            );
            if (httpResponse.statusCode() < 200 || httpResponse.statusCode() >= 300) {
                return new QueryResult(false, "", "", "", "",
                        "VNPay query returned HTTP " + httpResponse.statusCode());
            }

            Map<String, String> response = parseJsonMap(httpResponse.body());
            if (!verifyQueryResponseSignature(response)) {
                return new QueryResult(false, "", "", "",
                        response.getOrDefault("vnp_ResponseCode", "97"),
                        "Invalid VNPay query response signature");
            }

            String responseCode = response.getOrDefault("vnp_ResponseCode", "");
            return new QueryResult(
                    "00".equals(responseCode),
                    response.getOrDefault("vnp_TransactionNo", ""),
                    response.getOrDefault("vnp_TransactionType", ""),
                    response.getOrDefault("vnp_PayDate", ""),
                    responseCode,
                    response.getOrDefault("vnp_Message", "")
            );
        } catch (Exception e) {
            throw new RuntimeException("VNPay transaction query failed", e);
        }
    }

    public boolean verifySignature(Map<String, String> params) {
        requireConfigured();
        String receivedHash = params.get("vnp_SecureHash");
        if (isBlank(receivedHash)) return false;

        Map<String, String> filtered = params.entrySet().stream()
                .filter(e -> !e.getKey().equals("vnp_SecureHash")
                        && !e.getKey().equals("vnp_SecureHashType"))
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        Map.Entry::getValue,
                        (a, b) -> b,
                        TreeMap::new
                ));

        String calculatedHash = hmacSHA512(hashSecret, buildHashData(filtered));
        return secureHashEquals(calculatedHash, receivedHash);
    }

    private String buildQueryString(Map<String, String> params) {
        return params.entrySet().stream()
                .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8)
                        + "=" + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
    }

    private String buildHashData(Map<String, String> params) {
        return params.entrySet().stream()
                .map(e -> e.getKey()
                        + "=" + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
    }

    private String hmacSHA512(String key, String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA512");
            SecretKeySpec secretKey = new SecretKeySpec(
                    key.getBytes(StandardCharsets.UTF_8), "HmacSHA512");
            mac.init(secretKey);
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("HMAC-SHA512 failed", e);
        }
    }

    private String getCurrentDateTime() {
        return formatVnPayDateTime(ZonedDateTime.now(VNPAY_ZONE));
    }

    private String formatVnPayDateTime(ZonedDateTime dateTime) {
        return dateTime.format(VNPAY_DATE_FORMAT);
    }

    private String normalizeOrderInfo(String orderInfo, String orderId) {
        String normalized = Normalizer.normalize(orderInfo, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .replace('đ', 'd')
                .replace('Đ', 'D')
                .replaceAll("[^A-Za-z0-9 .,:_-]", " ")
                .replaceAll("\\s+", " ")
                .trim();
        if (normalized.isBlank()) {
            normalized = "Thanh toan don hang " + orderId;
        }
        return normalized.length() <= 255 ? normalized : normalized.substring(0, 255).trim();
    }

    private boolean verifyQueryResponseSignature(Map<String, String> params) {
        String receivedHash = params.get("vnp_SecureHash");
        if (isBlank(receivedHash)) return false;

        String checksumData = String.join("|",
                value(params, "vnp_ResponseId"),
                value(params, "vnp_Command"),
                value(params, "vnp_ResponseCode"),
                value(params, "vnp_Message"),
                value(params, "vnp_TmnCode"),
                value(params, "vnp_TxnRef"),
                value(params, "vnp_Amount"),
                value(params, "vnp_BankCode"),
                value(params, "vnp_PayDate"),
                value(params, "vnp_TransactionNo"),
                value(params, "vnp_TransactionType"),
                value(params, "vnp_TransactionStatus"),
                value(params, "vnp_OrderInfo"),
                value(params, "vnp_PromotionCode"),
                value(params, "vnp_PromotionAmount")
        );
        String calculatedHash = hmacSHA512(hashSecret, checksumData);
        return secureHashEquals(calculatedHash, receivedHash);
    }

    private Map<String, String> parseJsonMap(String json) throws Exception {
        Map<String, Object> raw = objectMapper.readValue(
                json,
                new TypeReference<>() {
                }
        );
        return raw.entrySet().stream()
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        entry -> entry.getValue() == null ? "" : String.valueOf(entry.getValue()),
                        (a, b) -> b,
                        LinkedHashMap::new
                ));
    }

    private boolean secureHashEquals(String calculatedHash, String receivedHash) {
        return MessageDigest.isEqual(
                calculatedHash.toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8),
                receivedHash.toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8)
        );
    }

    private void validateCreatePaymentInput(
            String orderId,
            long amount,
            String orderInfo,
            String returnUrl,
            String ipAddress
    ) {
        requireConfigured();
        requireText(orderId, "orderId");
        requireText(orderInfo, "orderInfo");
        requireText(returnUrl, "returnUrl");
        requireText(ipAddress, "ipAddress");
        if (amount <= 0) {
            throw new IllegalArgumentException("amount must be positive");
        }
    }

    private void requireConfigured() {
        requireText(tmnCode, "vnpay.tmn-code");
        requireText(hashSecret, "vnpay.hash-secret");
        requireText(paymentUrl, "vnpay.payment-url");
    }

    private void requireText(String value, String fieldName) {
        if (isBlank(value)) {
            throw new IllegalArgumentException(fieldName + " is required");
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private String value(Map<String, String> params, String key) {
        return params.getOrDefault(key, "");
    }

    private String toVnPayOrderType(String orderType) {
        if ("food".equalsIgnoreCase(orderType)) {
            return "billpayment";
        }
        return "other";
    }

    public record QueryResult(
            boolean success,
            String transactionNo,
            String transactionType,
            String payDate,
            String responseCode,
            String message
    ) {
    }
}
