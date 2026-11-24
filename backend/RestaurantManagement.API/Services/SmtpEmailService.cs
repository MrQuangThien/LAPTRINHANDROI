using System.Net;
using System.Net.Mail;

namespace RestaurantManagement.API.Services;

public sealed class SmtpEmailService(IConfiguration configuration, ILogger<SmtpEmailService> logger)
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(configuration["Smtp:User"]) &&
        !string.IsNullOrWhiteSpace(configuration["Smtp:Password"]);

    public async Task<(bool Sent, string? Error)> SendOtpEmailAsync(
        string toEmail,
        string subject,
        string heading,
        string otpCode,
        int expiresInMinutes,
        CancellationToken cancellationToken = default)
    {
        var host = configuration["Smtp:Host"] ?? "smtp.gmail.com";
        var port = int.TryParse(configuration["Smtp:Port"], out var p) ? p : 587;
        var user = configuration["Smtp:User"];
        var password = configuration["Smtp:Password"];
        var fromEmail = configuration["Smtp:FromEmail"];
        var fromName = configuration["Smtp:FromName"] ?? "Bếp Nhà Coffee & Kitchen";
        var enableSsl = !bool.TryParse(configuration["Smtp:EnableSsl"], out var ssl) || ssl;

        if (string.IsNullOrWhiteSpace(user) || string.IsNullOrWhiteSpace(password))
            return (false, "Chưa cấu hình tài khoản SMTP trong appsettings.json.");

        try
        {
            using var message = new MailMessage
            {
                From = new MailAddress(string.IsNullOrWhiteSpace(fromEmail) ? user : fromEmail, fromName),
                Subject = subject,
                IsBodyHtml = true,
                Body = $"""
                    <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 20px; border: 1px solid #eadfd5; border-radius: 12px;">
                        <h2 style="color: #6b3f23; margin-top: 0;">{WebUtility.HtmlEncode(heading)}</h2>
                        <p>Xin chào,</p>
                        <p>Mã xác thực OTP của bạn là:</p>
                        <div style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #8b4c2f; background: #faf4ef; padding: 14px 20px; border-radius: 10px; text-align: center; margin: 16px 0;">
                            {WebUtility.HtmlEncode(otpCode)}
                        </div>
                        <p>Mã có hiệu lực trong <strong>{expiresInMinutes} phút</strong>. Vui lòng không chia sẻ mã này cho người khác.</p>
                        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
                        <p style="font-size: 12px; color: #777;">Bếp Nhà Coffee & Kitchen</p>
                    </div>
                    """
            };
            message.To.Add(new MailAddress(toEmail));

            using var client = new SmtpClient(host, port)
            {
                EnableSsl = enableSsl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(user, password),
                DeliveryMethod = SmtpDeliveryMethod.Network,
                Timeout = 15000
            };
            cancellationToken.ThrowIfCancellationRequested();
            await client.SendMailAsync(message, cancellationToken);
            return (true, null);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Không thể gửi email OTP tới {Email} qua SMTP {Host}:{Port}", toEmail, host, port);
            return (false, ex.Message);
        }
    }
}
