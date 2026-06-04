from datetime import datetime

from pydantic import BaseModel, Field


class CreatePaymentRequest(BaseModel):
    order_id: str = Field(..., description="Booking ID or Order ID")
    amount: int = Field(..., gt=0, description="Amount in VND")
    description: str = Field("", max_length=255, description="Payment description")
    order_type: str = Field("booking", description="'booking' or 'food'")


class CreatePaymentResponse(BaseModel):
    success: bool
    payment_url: str | None = None
    error: str | None = None


class PaymentCallbackResponse(BaseModel):
    is_valid: bool
    is_success: bool
    transaction_no: str | None = None
    order_id: str | None = None
    amount: int | None = None
    response_code: str | None = None
    bank_code: str | None = None


class QueryPaymentResponse(BaseModel):
    success: bool
    transaction_no: str | None = None
    transaction_type: str | None = None
    pay_date: str | None = None
    response_code: str | None = None
    message: str | None = None


class PaymentTransactionResponse(BaseModel):
    id: str
    order_id: str
    vnp_transaction_no: str | None = None
    amount: int
    order_type: str
    status: str
    response_code: str | None = None
    bank_code: str | None = None
    paid_at: datetime | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True
