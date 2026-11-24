using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Services;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/auth")]
public sealed class AuthController(
    RestaurantDbContext db,
    JwtTokenService tokens,
    IConfiguration configuration,
    SmtpEmailService emailService,
    OAuthStateService oauthStates,
    IHttpClientFactory httpFactory) : ControllerBase
{
    private readonly PasswordHasher<Member> _hasher = new();

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var phone = request.Phone.Trim();
        if (await db.Members.AnyAsync(m => m.Email == email || m.Phone == phone))
            return Conflict(new { message = "Email or phone number is already registered." });
        if (!string.IsNullOrWhiteSpace(request.Role) &&
            !string.Equals(request.Role.Trim(), "Customer", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = "Staff accounts can only be created by an Administrator." });
        var role = await db.Roles.SingleOrDefaultAsync(r => r.Name == "Customer");
        if (role is null)
        {
            role = new Role { Name = "Customer", Description = "Customer account" };
            db.Roles.Add(role);
            await db.SaveChangesAsync();
        }
        var verifyCode = Random.Shared.Next(100000, 999999).ToString();
        var member = new Member { FullName = request.FullName.Trim(), Email = email, Phone = phone,
            RoleId = role.Id, IsActive = true, IsEmailVerified = false,
            EmailVerificationCode = verifyCode, EmailVerificationExpiryUtc = DateTime.UtcNow.AddMinutes(15),
            CreatedAt = DateTime.UtcNow };
        member.PasswordHash = _hasher.HashPassword(member, request.Password);
        db.Members.Add(member);
        await db.SaveChangesAsync();
        member.Role = role;
        return Created("/api/members/" + member.Id, tokens.Create(member));
    }

    [HttpPost("send-verification")]
    public async Task<IActionResult> SendVerification(SendVerificationRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var member = await db.Members.SingleOrDefaultAsync(m => m.Email == email && m.IsActive);
        if (member is null) return NotFound(new { message = "Không tìm thấy tài khoản với email này." });
        if (member.IsEmailVerified) return Ok(new { message = "Email đã được xác thực trước đó.", isEmailVerified = true });
        var code = Random.Shared.Next(100000, 999999).ToString();
        member.EmailVerificationCode = code;
        member.EmailVerificationExpiryUtc = DateTime.UtcNow.AddMinutes(15);
        await db.SaveChangesAsync();
        var (sent, _) = await emailService.SendOtpEmailAsync(
            email,
            "Mã xác thực tài khoản - Bếp Nhà",
            "Xác thực địa chỉ Email",
            code,
            15);
        return Ok(new
        {
            message = sent
                ? $"Đã gửi mã xác thực 6 số tới hộp thư {email}. Vui lòng kiểm tra email."
                : $"Đã tạo mã xác thực 6 số cho {email} (chưa cấu hình SMTP nên hiển thị mã thử nghiệm).",
            emailSent = sent,
            devOtpCode = sent ? null : code,
            expiresInMinutes = 15
        });
    }

    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var code = request.Code.Trim();
        var member = await db.Members.SingleOrDefaultAsync(m => m.Email == email && m.IsActive);
        if (member is null) return NotFound(new { message = "Không tìm thấy tài khoản với email này." });
        if (member.IsEmailVerified) return Ok(new { message = "Email đã được xác thực.", isEmailVerified = true });
        if (string.IsNullOrEmpty(member.EmailVerificationCode) ||
            member.EmailVerificationExpiryUtc is null ||
            member.EmailVerificationExpiryUtc < DateTime.UtcNow ||
            !string.Equals(member.EmailVerificationCode, code, StringComparison.Ordinal))
        {
            return BadRequest(new { message = "Mã xác thực không đúng hoặc đã hết hạn." });
        }
        member.IsEmailVerified = true;
        member.EmailVerificationCode = null;
        member.EmailVerificationExpiryUtc = null;
        await db.SaveChangesAsync();
        return Ok(new { message = "Xác thực email thành công!", isEmailVerified = true });
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var member = await db.Members.SingleOrDefaultAsync(m => m.Email == email && m.IsActive);
        if (member is null) return NotFound(new { message = "Không tìm thấy tài khoản nào đăng ký bằng email này." });
        var code = Random.Shared.Next(100000, 999999).ToString();
        member.PasswordResetCode = code;
        member.PasswordResetExpiryUtc = DateTime.UtcNow.AddMinutes(15);
        await db.SaveChangesAsync();
        var (sent, _) = await emailService.SendOtpEmailAsync(
            email,
            "Mã khôi phục mật khẩu - Bếp Nhà",
            "Khôi phục mật khẩu tài khoản",
            code,
            15);
        return Ok(new
        {
            message = sent
                ? $"Đã gửi mã OTP khôi phục mật khẩu tới hộp thư {email}. Vui lòng kiểm tra email."
                : $"Đã tạo mã khôi phục mật khẩu cho {email} (chưa cấu hình SMTP nên hiển thị mã thử nghiệm).",
            emailSent = sent,
            devOtpCode = sent ? null : code,
            expiresInMinutes = 15
        });
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var code = request.Code.Trim();
        var member = await db.Members.SingleOrDefaultAsync(m => m.Email == email && m.IsActive);
        if (member is null) return NotFound(new { message = "Không tìm thấy tài khoản với email này." });
        if (string.IsNullOrEmpty(member.PasswordResetCode) ||
            member.PasswordResetExpiryUtc is null ||
            member.PasswordResetExpiryUtc < DateTime.UtcNow ||
            !string.Equals(member.PasswordResetCode, code, StringComparison.Ordinal))
        {
            return BadRequest(new { message = "Mã OTP khôi phục không đúng hoặc đã hết hạn." });
        }
        member.PasswordHash = _hasher.HashPassword(member, request.NewPassword);
        member.PasswordResetCode = null;
        member.PasswordResetExpiryUtc = null;
        await db.SaveChangesAsync();
        return Ok(new { message = "Đặt lại mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới." });
    }

    [HttpPost("social-login")]
    public async Task<ActionResult<AuthResponse>> SocialLogin(SocialLoginRequest request)
    {
        var (auth, err) = await FindOrCreateSocialMemberAsync(
            request.Provider.Trim(),
            request.Email.Trim().ToLowerInvariant(),
            request.FullName.Trim(),
            request.Phone);
        return err is not null ? Unauthorized(new { message = err }) : Ok(auth);
    }

    [HttpGet("oauth/providers")]
    public IActionResult OAuthProviders() => Ok(new
    {
        google = IsOAuthConfigured("google"),
        facebook = IsOAuthConfigured("facebook"),
        zalo = IsOAuthConfigured("zalo")
    });

    [HttpGet("oauth/{provider}/start")]
    public IActionResult OAuthStart(string provider, [FromQuery] string? returnUrl = null, [FromQuery] string? desktopSessionId = null)
    {
        var key = provider.Trim().ToLowerInvariant();
        if (!IsOAuthConfigured(key))
            return BadRequest(new { message = $"Chưa cấu hình khóa OAuth cho {provider} trong appsettings.json." });

        var callbackUrl = $"{ResolvePublicBaseUrl()}/api/auth/oauth/{key}/callback";
        var (state, codeChallenge) = oauthStates.CreateState(key, returnUrl, usePkce: key == "zalo", desktopSessionId: desktopSessionId);

        var url = key switch
        {
            "google" => $"https://accounts.google.com/o/oauth2/v2/auth?client_id={Uri.EscapeDataString(configuration["OAuth:Google:ClientId"]!)}&redirect_uri={Uri.EscapeDataString(callbackUrl)}&response_type=code&scope={Uri.EscapeDataString("openid email profile")}&state={state}",
            "facebook" => $"https://www.facebook.com/v19.0/dialog/oauth?client_id={Uri.EscapeDataString(configuration["OAuth:Facebook:AppId"]!)}&redirect_uri={Uri.EscapeDataString(callbackUrl)}&scope={Uri.EscapeDataString("email,public_profile")}&state={state}",
            "zalo" => $"https://oauth.zaloapp.com/v4/permission?app_id={Uri.EscapeDataString(configuration["OAuth:Zalo:AppId"]!)}&redirect_uri={Uri.EscapeDataString(callbackUrl)}&code_challenge={Uri.EscapeDataString(codeChallenge!)}&state={state}",
            _ => throw new InvalidOperationException("Unsupported provider")
        };
        return Redirect(url);
    }

    [HttpGet("oauth/{provider}/callback")]
    public async Task<IActionResult> OAuthCallback(string provider, [FromQuery] string? code = null, [FromQuery] string? state = null, [FromQuery] string? error = null, [FromQuery(Name = "error_description")] string? errorDescription = null)
    {
        var key = provider.Trim().ToLowerInvariant();
        if (!string.IsNullOrWhiteSpace(error) || string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(state))
            return OAuthErrorHtml(provider, $"Đăng nhập {provider} không thành công: {errorDescription ?? error ?? "thiếu mã xác thực"}.");

        var pending = oauthStates.ConsumeState(state, key);
        if (pending is null)
            return OAuthErrorHtml(provider, "Phiên đăng nhập OAuth đã hết hạn hoặc không hợp lệ. Vui lòng thử lại.");

        var callbackUrl = $"{ResolvePublicBaseUrl()}/api/auth/oauth/{key}/callback";
        var profile = await ExchangeOAuthProfileAsync(key, code, callbackUrl, pending.CodeVerifier);
        if (profile is null)
            return OAuthErrorHtml(provider, $"Không thể lấy thông tin người dùng từ {provider}. Kiểm tra lại App ID / Secret và Redirect URI ({callbackUrl}).");

        var (auth, err) = await FindOrCreateSocialMemberAsync(
            key switch { "google" => "Google", "facebook" => "Facebook", _ => "Zalo" },
            profile.Value.Email,
            profile.Value.FullName);
        if (err is not null || auth is null)
            return OAuthErrorHtml(provider, err ?? "Không thể đăng nhập tài khoản.");

        if (!string.IsNullOrWhiteSpace(pending.DesktopSessionId))
        {
            oauthStates.SetDesktopResult(pending.DesktopSessionId, auth);
            var successHtml = @"<!DOCTYPE html>
<html lang=""vi""><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1"">
<title>Đăng nhập thành công</title>
<style>body{font-family:Arial,sans-serif;background:#faf4ef;color:#2c1d12;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px;}.card{max-width:440px;background:#fff;padding:24px;border-radius:16px;border:1px solid #eadfd5;box-shadow:0 6px 20px rgba(0,0,0,.06);text-align:center;}h2{margin-top:0;color:#1e7e48;}</style>
</head><body><div class=""card""><h2>Đăng nhập thành công!</h2><p>Bạn đã xác thực tài khoản thành công. Vui lòng đóng tab trình duyệt này và quay lại ứng dụng Bếp Nhà.</p></div></body></html>";
            return Content(successHtml, "text/html; charset=utf-8");
        }

        var exchangeCode = oauthStates.CreateExchangeCode(auth);
        var targetBase = string.IsNullOrWhiteSpace(pending.ReturnUrl) ? ResolvePublicBaseUrl() : pending.ReturnUrl.TrimEnd('/');
        var sep = targetBase.Contains('?') ? '&' : '?';
        return Redirect($"{targetBase}{sep}oauthExchange={Uri.EscapeDataString(exchangeCode)}");
    }

    [HttpGet("oauth/desktop-poll/{sessionId}")]
    public IActionResult OAuthDesktopPoll(string sessionId)
    {
        var auth = oauthStates.ConsumeDesktopResult(sessionId);
        return auth is null
            ? Ok(new { completed = false })
            : Ok(new { completed = true, auth });
    }

    private ContentResult OAuthErrorHtml(string provider, string message)
    {
        var loginUrl = $"{ResolvePublicBaseUrl()}/#/login";
        var safeProvider = System.Net.WebUtility.HtmlEncode(provider);
        var safeMsg = System.Net.WebUtility.HtmlEncode(message);
        var html = @"<!DOCTYPE html>
<html lang=""vi""><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1"">
<title>Lỗi đăng nhập __PROVIDER__</title>
<style>body{font-family:Arial,sans-serif;background:#faf4ef;color:#2c1d12;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px;}.card{max-width:440px;background:#fff;padding:24px;border-radius:16px;border:1px solid #eadfd5;box-shadow:0 6px 20px rgba(0,0,0,.06);}h2{margin-top:0;color:#8b4c2f;}a{display:inline-block;margin-top:16px;padding:10px 18px;background:#8b4c2f;color:#fff;text-decoration:none;border-radius:10px;font-weight:bold;}</style>
</head><body><div class=""card""><h2>Không thể đăng nhập</h2><p>__MSG__</p><a href=""__URL__"">Quay lại trang đăng nhập</a></div></body></html>"
            .Replace("__PROVIDER__", safeProvider)
            .Replace("__MSG__", safeMsg)
            .Replace("__URL__", loginUrl);
        return Content(html, "text/html; charset=utf-8");
    }

    [HttpPost("oauth/exchange")]
    public ActionResult<AuthResponse> OAuthExchange(OAuthExchangeRequest request)
    {
        var auth = oauthStates.ConsumeExchangeCode(request.ExchangeCode);
        return auth is null
            ? BadRequest(new { message = "Mã phiên OAuth đã hết hạn hoặc không hợp lệ." })
            : Ok(auth);
    }

    private bool IsOAuthConfigured(string key) => key switch
    {
        "google" => !string.IsNullOrWhiteSpace(configuration["OAuth:Google:ClientId"]) && !string.IsNullOrWhiteSpace(configuration["OAuth:Google:ClientSecret"]),
        "facebook" => !string.IsNullOrWhiteSpace(configuration["OAuth:Facebook:AppId"]) && !string.IsNullOrWhiteSpace(configuration["OAuth:Facebook:AppSecret"]),
        "zalo" => !string.IsNullOrWhiteSpace(configuration["OAuth:Zalo:AppId"]) && !string.IsNullOrWhiteSpace(configuration["OAuth:Zalo:SecretKey"]),
        _ => false
    };

    private string ResolvePublicBaseUrl()
    {
        var configured = configuration["OAuth:PublicBaseUrl"]?.Trim().TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(configured)) return configured;
        var scheme = Request.Headers["X-Forwarded-Proto"].FirstOrDefault() ?? Request.Scheme;
        return $"{scheme}://{Request.Host}";
    }

    private async Task<(string Email, string FullName)?> ExchangeOAuthProfileAsync(string key, string code, string callbackUrl, string? codeVerifier)
    {
        var client = httpFactory.CreateClient();
        if (key == "google")
        {
            using var tokenRes = await client.PostAsync("https://oauth2.googleapis.com/token", new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["code"] = code,
                ["client_id"] = configuration["OAuth:Google:ClientId"]!,
                ["client_secret"] = configuration["OAuth:Google:ClientSecret"]!,
                ["redirect_uri"] = callbackUrl,
                ["grant_type"] = "authorization_code"
            }));
            if (!tokenRes.IsSuccessStatusCode) return null;
            using var tokenJson = JsonDocument.Parse(await tokenRes.Content.ReadAsStringAsync());
            var accessToken = tokenJson.RootElement.GetProperty("access_token").GetString();
            if (string.IsNullOrWhiteSpace(accessToken)) return null;

            using var userReq = new HttpRequestMessage(HttpMethod.Get, "https://www.googleapis.com/oauth2/v2/userinfo");
            userReq.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
            using var userRes = await client.SendAsync(userReq);
            if (!userRes.IsSuccessStatusCode) return null;
            using var userJson = JsonDocument.Parse(await userRes.Content.ReadAsStringAsync());
            var id = userJson.RootElement.TryGetProperty("id", out var idEl) ? idEl.GetString() : Guid.NewGuid().ToString("N");
            var email = userJson.RootElement.TryGetProperty("email", out var emEl) ? emEl.GetString() : $"google_{id}@local.app";
            var name = userJson.RootElement.TryGetProperty("name", out var nmEl) ? nmEl.GetString() : "Khách hàng Google";
            return ((email ?? $"google_{id}@local.app").ToLowerInvariant(), string.IsNullOrWhiteSpace(name) ? "Khách hàng Google" : name);
        }

        if (key == "facebook")
        {
            var tokenUrl = $"https://graph.facebook.com/v19.0/oauth/access_token?client_id={Uri.EscapeDataString(configuration["OAuth:Facebook:AppId"]!)}&redirect_uri={Uri.EscapeDataString(callbackUrl)}&client_secret={Uri.EscapeDataString(configuration["OAuth:Facebook:AppSecret"]!)}&code={Uri.EscapeDataString(code)}";
            using var tokenRes = await client.GetAsync(tokenUrl);
            if (!tokenRes.IsSuccessStatusCode) return null;
            using var tokenJson = JsonDocument.Parse(await tokenRes.Content.ReadAsStringAsync());
            var accessToken = tokenJson.RootElement.GetProperty("access_token").GetString();
            if (string.IsNullOrWhiteSpace(accessToken)) return null;

            using var userRes = await client.GetAsync($"https://graph.facebook.com/me?fields=id,name,email&access_token={Uri.EscapeDataString(accessToken)}");
            if (!userRes.IsSuccessStatusCode) return null;
            using var userJson = JsonDocument.Parse(await userRes.Content.ReadAsStringAsync());
            var id = userJson.RootElement.TryGetProperty("id", out var idEl) ? idEl.GetString() : Guid.NewGuid().ToString("N");
            var email = userJson.RootElement.TryGetProperty("email", out var emEl) ? emEl.GetString() : null;
            var name = userJson.RootElement.TryGetProperty("name", out var nmEl) ? nmEl.GetString() : "Khách hàng Facebook";
            return ((string.IsNullOrWhiteSpace(email) ? $"fb_{id}@local.app" : email).ToLowerInvariant(), string.IsNullOrWhiteSpace(name) ? "Khách hàng Facebook" : name);
        }

        if (key == "zalo")
        {
            using var tokenReq = new HttpRequestMessage(HttpMethod.Post, "https://oauth.zaloapp.com/v4/access_token");
            tokenReq.Headers.Add("secret_key", configuration["OAuth:Zalo:SecretKey"]!);
            tokenReq.Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["app_id"] = configuration["OAuth:Zalo:AppId"]!,
                ["code"] = code,
                ["grant_type"] = "authorization_code",
                ["code_verifier"] = codeVerifier ?? ""
            });
            using var tokenRes = await client.SendAsync(tokenReq);
            if (!tokenRes.IsSuccessStatusCode) return null;
            using var tokenJson = JsonDocument.Parse(await tokenRes.Content.ReadAsStringAsync());
            if (!tokenJson.RootElement.TryGetProperty("access_token", out var atEl)) return null;
            var accessToken = atEl.GetString();
            if (string.IsNullOrWhiteSpace(accessToken)) return null;

            using var userReq = new HttpRequestMessage(HttpMethod.Get, "https://graph.zalo.me/v2.0/me?fields=id,name");
            userReq.Headers.Add("access_token", accessToken);
            using var userRes = await client.SendAsync(userReq);
            if (!userRes.IsSuccessStatusCode) return null;
            using var userJson = JsonDocument.Parse(await userRes.Content.ReadAsStringAsync());
            var id = userJson.RootElement.TryGetProperty("id", out var idEl) ? idEl.GetString() : Guid.NewGuid().ToString("N");
            var name = userJson.RootElement.TryGetProperty("name", out var nmEl) ? nmEl.GetString() : "Khách hàng Zalo";
            return ($"zalo_{id}@local.app", string.IsNullOrWhiteSpace(name) ? "Khách hàng Zalo" : name);
        }

        return null;
    }

    private async Task<(AuthResponse? Auth, string? Error)> FindOrCreateSocialMemberAsync(string provider, string email, string fullName, string? phoneInput = null)
    {
        var member = await db.Members.Include(m => m.Role).SingleOrDefaultAsync(m => m.Email == email);
        if (member is not null)
        {
            if (!member.IsActive) return (null, "Tài khoản này đã bị khóa.");
            if (!member.IsEmailVerified)
            {
                member.IsEmailVerified = true;
                await db.SaveChangesAsync();
            }
            return (tokens.Create(member), null);
        }

        var role = await db.Roles.SingleOrDefaultAsync(r => r.Name == "Customer");
        if (role is null)
        {
            role = new Role { Name = "Customer", Description = "Customer account" };
            db.Roles.Add(role);
            await db.SaveChangesAsync();
        }
        var phone = string.IsNullOrWhiteSpace(phoneInput)
            ? $"09{Random.Shared.Next(10000000, 99999999)}"
            : phoneInput.Trim();
        while (await db.Members.AnyAsync(m => m.Phone == phone))
            phone = $"09{Random.Shared.Next(10000000, 99999999)}";

        member = new Member
        {
            FullName = fullName,
            Email = email,
            Phone = phone,
            RoleId = role.Id,
            IsActive = true,
            IsEmailVerified = true,
            AuthProvider = provider,
            CreatedAt = DateTime.UtcNow
        };
        member.PasswordHash = _hasher.HashPassword(member, Guid.NewGuid().ToString("N") + "!@#Aa1");
        db.Members.Add(member);
        await db.SaveChangesAsync();
        member.Role = role;
        return (tokens.Create(member), null);
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        var identifier = request.Identifier.Trim();
        // The bootstrap Admin has a normal email for data integrity and the
        // configured short username as a sign-in alias.
        var adminUsername = (configuration["AdminBootstrap:Username"] ?? "admin").Trim();
        var adminEmail = (configuration["AdminBootstrap:Email"] ?? "admin@restaurant.local").Trim().ToLowerInvariant();
        var member = await db.Members.Include(m => m.Role)
            .SingleOrDefaultAsync(m => m.Email == identifier.ToLowerInvariant() ||
                m.Phone == identifier ||
                (string.Equals(identifier, adminUsername, StringComparison.OrdinalIgnoreCase) &&
                 m.Email == adminEmail && m.Role.Name == "Admin"));
        if (member is null || !member.IsActive || _hasher.VerifyHashedPassword(member, member.PasswordHash, request.Password) == PasswordVerificationResult.Failed)
            return Unauthorized(new { message = "Invalid credentials or inactive account." });
        return Ok(tokens.Create(member));
    }

    [Authorize, HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request)
    {
        var id = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(id, out var memberId)) return Unauthorized();
        var member = await db.Members.FindAsync(memberId);
        if (member is null) return Unauthorized();
        if (_hasher.VerifyHashedPassword(member, member.PasswordHash, request.CurrentPassword) == PasswordVerificationResult.Failed)
            return BadRequest(new { message = "Current password is incorrect." });
        member.PasswordHash = _hasher.HashPassword(member, request.NewPassword);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [Authorize, HttpPost("logout")]
    public IActionResult Logout() => NoContent();

    [Authorize, HttpGet("me")]
    public async Task<ActionResult<MemberResponse>> Me()
    {
        if (!int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) return Unauthorized();
        var m = await db.Members.Include(x => x.Role).SingleOrDefaultAsync(x => x.Id == id && x.IsActive);
        return m is null ? Unauthorized() : Ok(new MemberResponse(m.Id, m.FullName, m.Email, m.Phone, m.Role.Name, m.IsActive, m.CreatedAt));
    }
}
