package com.venue.payment.grpc;

import com.venue.payment.proto.CreatePaymentRequest;
import com.venue.payment.proto.CreatePaymentResponse;
import com.venue.payment.proto.PaymentServiceGrpc;
import com.venue.payment.proto.QueryTransactionRequest;
import com.venue.payment.proto.QueryTransactionResponse;
import com.venue.payment.proto.VerifyCallbackRequest;
import com.venue.payment.proto.VerifyCallbackResponse;
import com.venue.payment.service.VNPayService;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

@GrpcService
public class PaymentGrpcService extends PaymentServiceGrpc.PaymentServiceImplBase {

    private static final Logger log = LoggerFactory.getLogger(PaymentGrpcService.class);

    private final VNPayService vnPayService;

    public PaymentGrpcService(VNPayService vnPayService) {
        this.vnPayService = vnPayService;
    }

    @Override
    public void createPayment(CreatePaymentRequest request,
                              StreamObserver<CreatePaymentResponse> observer) {
        try {
            String url = vnPayService.createPaymentUrl(
                    request.getOrderId(),
                    request.getAmount(),
                    request.getOrderInfo(),
                    request.getReturnUrl(),
                    request.getIpAddress(),
                    request.getOrderType()
            );
            observer.onNext(CreatePaymentResponse.newBuilder()
                    .setSuccess(true)
                    .setPaymentUrl(url)
                    .build());
        } catch (Exception e) {
            log.error("Failed to create payment URL", e);
            observer.onNext(CreatePaymentResponse.newBuilder()
                    .setSuccess(false)
                    .setErrorMessage(e.getMessage())
                    .build());
        }
        observer.onCompleted();
    }

    @Override
    public void verifyCallback(VerifyCallbackRequest request,
                               StreamObserver<VerifyCallbackResponse> observer) {
        try {
            Map<String, String> params = request.getVnpayParamsMap();
            boolean isValid = vnPayService.verifySignature(params);
            boolean isSuccess = isValid && "00".equals(params.get("vnp_ResponseCode"))
                    && "00".equals(params.get("vnp_TransactionStatus"));

            observer.onNext(VerifyCallbackResponse.newBuilder()
                    .setIsValid(isValid)
                    .setIsSuccess(isSuccess)
                    .setTransactionNo(params.getOrDefault("vnp_TransactionNo", ""))
                    .setOrderId(params.getOrDefault("vnp_TxnRef", ""))
                    .setAmount(parseVnPayAmount(params.getOrDefault("vnp_Amount", "0")))
                    .setResponseCode(params.getOrDefault("vnp_ResponseCode", ""))
                    .setBankCode(params.getOrDefault("vnp_BankCode", ""))
                    .build());
            observer.onCompleted();
        } catch (Exception e) {
            log.error("Failed to verify payment callback", e);
            observer.onNext(VerifyCallbackResponse.newBuilder()
                    .setIsValid(false)
                    .setIsSuccess(false)
                    .setResponseCode("99")
                    .build());
            observer.onCompleted();
        }
    }

    @Override
    public void queryTransaction(QueryTransactionRequest request,
                                 StreamObserver<QueryTransactionResponse> observer) {
        try {
            VNPayService.QueryResult result = vnPayService.queryTransaction(
                    request.getOrderId(),
                    request.getCreateDate(),
                    request.getIpAddress()
            );
            observer.onNext(QueryTransactionResponse.newBuilder()
                    .setSuccess(result.success())
                    .setTransactionNo(result.transactionNo())
                    .setTransactionType(result.transactionType())
                    .setPayDate(result.payDate())
                    .setResponseCode(result.responseCode())
                    .setMessage(result.message())
                    .build());
        } catch (Exception e) {
            log.error("Failed to query VNPay transaction", e);
            observer.onNext(QueryTransactionResponse.newBuilder()
                    .setSuccess(false)
                    .setResponseCode("99")
                    .setMessage(e.getMessage())
                    .build());
        }
        observer.onCompleted();
    }

    private long parseVnPayAmount(String rawAmount) {
        try {
            return Long.parseLong(rawAmount) / 100;
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
