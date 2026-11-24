using System.ComponentModel.DataAnnotations;

namespace RestaurantManagement.API.DTOs;

public sealed record RegisterRequest([Required, StringLength(120, MinimumLength = 2)] string FullName,
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, Phone, StringLength(30, MinimumLength = 7)] string Phone,
    [Required, MinLength(10), StringLength(100)] string Password,
    string? Role = null);
public sealed record BlogPostRequest([Required, StringLength(200, MinimumLength = 4)] string Title,
    [Required, StringLength(80, MinimumLength = 2)] string Category,
    [Required, StringLength(500, MinimumLength = 10)] string Summary,
    [Required, StringLength(8000, MinimumLength = 20)] string Content,
    [StringLength(500)] string? ImageUrl = null,
    [StringLength(120)] string? AuthorName = null,
    [Range(1, 60)] int ReadingMinutes = 3,
    bool IsFeatured = false);
public sealed record LoginRequest([Required, StringLength(256)] string Identifier, [Required] string Password);
public sealed record ChangePasswordRequest([Required] string CurrentPassword,
    [Required, MinLength(10), StringLength(100)] string NewPassword);
public sealed record AuthResponse(string Token, DateTime ExpiresAt, int Id, string FullName, string Email, string Role, bool IsEmailVerified = false);
public sealed record SendVerificationRequest([Required, EmailAddress, StringLength(256)] string Email);
public sealed record VerifyEmailRequest([Required, EmailAddress, StringLength(256)] string Email, [Required, StringLength(12, MinimumLength = 4)] string Code);
public sealed record ForgotPasswordRequest([Required, EmailAddress, StringLength(256)] string Email);
public sealed record ResetPasswordRequest([Required, EmailAddress, StringLength(256)] string Email,
    [Required, StringLength(12, MinimumLength = 4)] string Code,
    [Required, MinLength(6), StringLength(100)] string NewPassword);
public sealed record SocialLoginRequest([Required, RegularExpression("Google|Facebook|Zalo")] string Provider,
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, StringLength(120, MinimumLength = 2)] string FullName,
    [StringLength(30)] string? Phone = null);
public sealed record MemberResponse(int Id, string FullName, string Email, string Phone, string Role, bool IsActive, DateTime CreatedAt);
public sealed record CreateMemberRequest([Required, StringLength(120, MinimumLength = 2)] string FullName,
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, Phone, StringLength(30, MinimumLength = 7)] string Phone,
    [Required, MinLength(10), StringLength(100)] string Password,
    [Required] string Role);
public sealed record UpdateMemberRequest([Required, StringLength(120, MinimumLength = 2)] string FullName,
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, Phone, StringLength(30, MinimumLength = 7)] string Phone,
    string? Role = null,
    [StringLength(100)] string? Password = null);
public sealed record CategoryRequest([Required, StringLength(100, MinimumLength = 2)] string Name,
    [StringLength(500)] string? Description, bool IsActive = true);
public sealed record ProductRequest([Required, StringLength(150, MinimumLength = 2)] string Name,
    int CategoryId, [Range(typeof(decimal), "0.01", "9999999999999999")] decimal Price,
    [StringLength(1000)] string? Description, bool IsAvailable = true);
public sealed record AreaRequest([Required, StringLength(100, MinimumLength = 2)] string Name, [StringLength(300)] string? Description);
public sealed record TableRequest(int AreaId, [Required, StringLength(50)] string TableName,
    [Range(1, 100)] int Capacity, [Required, RegularExpression("Available|Occupied|Reserved|Cleaning")] string Status);
public sealed record TransferTableRequest([Range(1, int.MaxValue)] int TargetTableId);
public sealed record CustomerReservationRequest(int TableId,
    [Required, StringLength(120, MinimumLength = 2)] string CustomerName,
    [Required, Phone, StringLength(30, MinimumLength = 7)] string CustomerPhone,
    [Range(1, 100)] int PartySize, DateTimeOffset StartsAt,
    [StringLength(500)] string? Note);
public sealed record CustomerOrderRequest(int TableId, Guid ClientRequestId,
    [Required, StringLength(120, MinimumLength = 2)] string CustomerName,
    [Required, Phone, StringLength(30, MinimumLength = 7)] string CustomerPhone,
    [Range(1, 100)] int PartySize,
    [Required, MinLength(1)] List<OrderLineRequest> Items,
    [StringLength(1000)] string? Note,
    [StringLength(64)] string? ReservationCode = null);
public sealed record UpdateReservationStatusRequest([Required] string Status);
public sealed record CustomerPaymentRequest([Required, RegularExpression("Cash|BankTransfer|VietQR")] string PaymentMethod,
    [StringLength(100)] string? TransactionCode);
public sealed record PageResponse<T>(IReadOnlyList<T> Items, int PageNumber, int PageSize, int TotalCount);
public sealed record OrderLineRequest(int ProductId, [System.ComponentModel.DataAnnotations.Range(1, 99)] int Quantity,
    [System.ComponentModel.DataAnnotations.StringLength(500)] string? Note = null);
public sealed record CreateOrderRequest(int TableId, Guid ClientRequestId, [System.ComponentModel.DataAnnotations.StringLength(1000)] string? Note,
    [System.ComponentModel.DataAnnotations.Required, System.ComponentModel.DataAnnotations.MinLength(1)] List<OrderLineRequest> Items);
public sealed record AddOrderItemsRequest([System.ComponentModel.DataAnnotations.Required, System.ComponentModel.DataAnnotations.MinLength(1)] List<OrderLineRequest> Items,
    [System.ComponentModel.DataAnnotations.StringLength(500)] string? Note = null);
public sealed record PaymentRequest([System.ComponentModel.DataAnnotations.RegularExpression("Cash|BankTransfer|VietQR")] string PaymentMethod,
    [System.ComponentModel.DataAnnotations.Range(typeof(decimal), "0", "9999999999999999")] decimal Discount = 0,
    [System.ComponentModel.DataAnnotations.StringLength(100)] string? TransactionCode = null);
public sealed record OrderDetailResponse(int Id, int ProductId, string ProductName, int Quantity,
    decimal UnitPrice, decimal TotalPrice, string? Note, string Status);
public sealed record OrderResponse(int Id, string OrderCode, int TableId, string TableName, string MemberName,
    DateTime OrderDate, string Status, decimal SubTotal, decimal Discount, decimal Tax, decimal TotalAmount,
    string? Note, IReadOnlyList<OrderDetailResponse> Items);
public sealed record OAuthExchangeRequest([Required] string ExchangeCode);




