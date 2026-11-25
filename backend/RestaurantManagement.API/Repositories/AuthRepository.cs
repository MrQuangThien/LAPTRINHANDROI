using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IAuthRepository
{
    Task<bool> ExistsEmailOrPhoneAsync(string email, string phone);
    Task<bool> ExistsPhoneAsync(string phone);
    Task<Role> GetOrCreateCustomerRoleAsync();
    Task<Member?> FindActiveByEmailWithRoleAsync(string email);
    Task<Member?> FindByEmailOrPhoneWithRoleAsync(string normalizedEmail, string rawIdentifier);
    Task<Member?> FindByIdAsync(int id);
    Task<MemberResponse?> GetProfileAsync(int id);
    void AddMember(Member member);
    Task SaveChangesAsync();
}

public sealed class AuthRepository(RestaurantDbContext db) : IAuthRepository
{
    public Task<bool> ExistsEmailOrPhoneAsync(string email, string phone) =>
        db.Members.AnyAsync(m => m.Email == email || m.Phone == phone);

    public Task<bool> ExistsPhoneAsync(string phone) =>
        db.Members.AnyAsync(m => m.Phone == phone);

    public async Task<Role> GetOrCreateCustomerRoleAsync()
    {
        var role = await db.Roles.SingleOrDefaultAsync(r => r.Name == "Customer");
        if (role is not null) return role;
        role = new Role { Name = "Customer", Description = "Customer account" };
        db.Roles.Add(role);
        await db.SaveChangesAsync();
        return role;
    }

    public Task<Member?> FindActiveByEmailWithRoleAsync(string email) =>
        db.Members.Include(m => m.Role).SingleOrDefaultAsync(m => m.Email == email && m.IsActive);

    public Task<Member?> FindByEmailOrPhoneWithRoleAsync(string normalizedEmail, string rawIdentifier) =>
        db.Members.Include(m => m.Role).SingleOrDefaultAsync(m => m.Email == normalizedEmail || m.Phone == rawIdentifier);

    public Task<Member?> FindByIdAsync(int id) => db.Members.FindAsync(id).AsTask();

    public Task<MemberResponse?> GetProfileAsync(int id) =>
        db.Members.AsNoTracking().Include(m => m.Role).Where(m => m.Id == id)
            .Select(m => new MemberResponse(m.Id, m.FullName, m.Email, m.Phone, m.Role.Name, m.IsActive, m.CreatedAt))
            .SingleOrDefaultAsync();

    public void AddMember(Member member) => db.Members.Add(member);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
