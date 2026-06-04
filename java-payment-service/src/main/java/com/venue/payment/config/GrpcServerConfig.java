package com.venue.payment.config;

import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import io.grpc.Status;
import net.devh.boot.grpc.server.interceptor.GrpcGlobalServerInterceptor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Configuration
public class GrpcServerConfig {

    private static final Metadata.Key<String> INTERNAL_API_KEY_HEADER =
            Metadata.Key.of("x-internal-api-key", Metadata.ASCII_STRING_MARSHALLER);

    @Value("${internal.api-key}")
    private String internalApiKey;

    @GrpcGlobalServerInterceptor
    public ServerInterceptor internalApiKeyInterceptor() {
        return new ServerInterceptor() {
            @Override
            public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
                    ServerCall<ReqT, RespT> call,
                    Metadata headers,
                    ServerCallHandler<ReqT, RespT> next
            ) {
                String configuredKey = normalize(internalApiKey);
                if (configuredKey.isEmpty()) {
                    call.close(
                            Status.UNAUTHENTICATED
                                    .withDescription("Internal API key is not configured"),
                            new Metadata()
                    );
                    return new ServerCall.Listener<>() {
                    };
                }

                String receivedKey = normalize(headers.get(INTERNAL_API_KEY_HEADER));
                if (!constantTimeEquals(configuredKey, receivedKey)) {
                    call.close(
                            Status.UNAUTHENTICATED
                                    .withDescription("Invalid internal API key"),
                            new Metadata()
                    );
                    return new ServerCall.Listener<>() {
                    };
                }
                return next.startCall(call, headers);
            }
        };
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    private static boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                actual.getBytes(StandardCharsets.UTF_8)
        );
    }
}
