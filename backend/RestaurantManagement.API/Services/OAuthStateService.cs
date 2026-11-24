using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using RestaurantManagement.API.DTOs;

namespace RestaurantManagement.API.Services;

public sealed record OAuthPendingState(
    string Provider,
    string? CodeVerifier,
    string? ReturnUrl,
    string? DesktopSessionId,
    DateTime ExpiresAtUtc);

public sealed record OAuthExchangeEntry(
    AuthResponse Auth,
    DateTime ExpiresAtUtc);

public sealed class OAuthStateService
{
    private readonly ConcurrentDictionary<string, OAuthPendingState> _pending = new();
    private readonly ConcurrentDictionary<string, OAuthExchangeEntry> _exchanges = new();
    private readonly ConcurrentDictionary<string, OAuthExchangeEntry> _desktopResults = new();

    public (string State, string? CodeChallenge) CreateState(string provider, string? returnUrl, bool usePkce, string? desktopSessionId = null)
    {
        CleanupExpired();
        var state = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
        string? verifier = null;
        string? challenge = null;

        if (usePkce)
        {
            verifier = Base64UrlEncode(RandomNumberGenerator.GetBytes(48));
            var hash = SHA256.HashData(Encoding.ASCII.GetBytes(verifier));
            challenge = Base64UrlEncode(hash);
        }

        _pending[state] = new OAuthPendingState(provider, verifier, returnUrl, desktopSessionId, DateTime.UtcNow.AddMinutes(10));
        return (state, challenge);
    }

    public OAuthPendingState? ConsumeState(string state, string provider)
    {
        if (string.IsNullOrWhiteSpace(state)) return null;
        if (!_pending.TryRemove(state, out var entry)) return null;
        if (entry.ExpiresAtUtc < DateTime.UtcNow) return null;
        if (!string.Equals(entry.Provider, provider, StringComparison.OrdinalIgnoreCase)) return null;
        return entry;
    }

    public string CreateExchangeCode(AuthResponse auth)
    {
        CleanupExpired();
        var code = Convert.ToHexString(RandomNumberGenerator.GetBytes(20)).ToLowerInvariant();
        _exchanges[code] = new OAuthExchangeEntry(auth, DateTime.UtcNow.AddMinutes(3));
        return code;
    }

    public AuthResponse? ConsumeExchangeCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        if (!_exchanges.TryRemove(code.Trim(), out var entry)) return null;
        return entry.ExpiresAtUtc >= DateTime.UtcNow ? entry.Auth : null;
    }

    public void SetDesktopResult(string sessionId, AuthResponse auth)
    {
        CleanupExpired();
        _desktopResults[sessionId.Trim()] = new OAuthExchangeEntry(auth, DateTime.UtcNow.AddMinutes(5));
    }

    public AuthResponse? ConsumeDesktopResult(string sessionId)
    {
        if (string.IsNullOrWhiteSpace(sessionId)) return null;
        if (!_desktopResults.TryRemove(sessionId.Trim(), out var entry)) return null;
        return entry.ExpiresAtUtc >= DateTime.UtcNow ? entry.Auth : null;
    }

    private void CleanupExpired()
    {
        var now = DateTime.UtcNow;
        foreach (var kv in _pending)
        {
            if (kv.Value.ExpiresAtUtc < now) _pending.TryRemove(kv.Key, out _);
        }
        foreach (var kv in _exchanges)
        {
            if (kv.Value.ExpiresAtUtc < now) _exchanges.TryRemove(kv.Key, out _);
        }
        foreach (var kv in _desktopResults)
        {
            if (kv.Value.ExpiresAtUtc < now) _desktopResults.TryRemove(kv.Key, out _);
        }
    }

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
