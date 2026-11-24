using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Services;

public sealed class JwtTokenService(IConfiguration configuration)
{
    public AuthResponse Create(Member member)
    {
        var keyText = configuration["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(keyText) || Encoding.UTF8.GetByteCount(keyText) < 32)
            throw new InvalidOperationException("Configure Jwt:Key with a random secret of at least 32 bytes.");
        var issuer = configuration["Jwt:Issuer"] ?? "RestaurantManagement";
        var audience = configuration["Jwt:Audience"] ?? "RestaurantManagementApp";
        var expires = DateTime.UtcNow.AddHours(8);
        var claims = new[] { new Claim(ClaimTypes.NameIdentifier, member.Id.ToString()),
            new Claim(ClaimTypes.Name, member.FullName), new Claim(ClaimTypes.Email, member.Email),
            new Claim(ClaimTypes.Role, member.Role.Name) };
        var credentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyText)), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(issuer, audience, claims, expires: expires, signingCredentials: credentials);
        return new AuthResponse(new JwtSecurityTokenHandler().WriteToken(token), expires,
            member.Id, member.FullName, member.Email, member.Role.Name, member.IsEmailVerified);
    }
}
