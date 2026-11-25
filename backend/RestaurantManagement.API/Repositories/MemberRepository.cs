using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Repositories;

public interface IMemberRepository
{
    Task<PageResponse<MemberResponse>> ListAsync(int pageNumber, int pageSize, string? search, string? role);
    Task<bool> ExistsEmailOrPhoneAsync(string email, string phone, int? excludeId = null);
    Task<Role?> FindRoleByNameAsync(string roleName);
    Task<Member?> FindByIdAsync(int id);
    Task<Member?> FindWithRoleAsync(int id);
    void Add(Member member);
    Task SaveChangesAsync();
}

public sealed class MemberRepository(RestaurantDbContext db) : IMemberRepository
{
    public async Task<PageResponse<MemberResponse>> ListAsync(int pageNumber, int pageSize, string? search, string? role)
    {
        var query = db.Members.AsNoTracking().Include(m => m.Role).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(m => m.FullName.Contains(search) || m.Email.Contains(search) || m.Phone.Contains(search));
        if (!string.IsNullOrWhiteSpace(role))
        {
            if (string.Equals(role, "StaffGroup", StringComparison.OrdinalIgnoreCase))
                query = query.Where(m => m.Role.Name != "Customer");
            else
                query = query.Where(m => m.Role.Name == role);
        }
        var count = await query.CountAsync();
        var items = await query.OrderBy(m => m.FullName).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(m => new MemberResponse(m.Id, m.FullName, m.Email, m.Phone, m.Role.Name, m.IsActive, m.CreatedAt))
            .ToListAsync();
        return new PageResponse<MemberResponse>(items, pageNumber, pageSize, count);
    }

    public Task<bool> ExistsEmailOrPhoneAsync(string email, string phone, int? excludeId = null) =>
        excludeId is null
            ? db.Members.AnyAsync(m => m.Email == email || m.Phone == phone)
            : db.Members.AnyAsync(m => m.Id != excludeId && (m.Email == email || m.Phone == phone));

    public Task<Role?> FindRoleByNameAsync(string roleName) => db.Roles.SingleOrDefaultAsync(r => r.Name == roleName);
    public Task<Member?> FindByIdAsync(int id) => db.Members.FindAsync(id).AsTask();
    public Task<Member?> FindWithRoleAsync(int id) => db.Members.Include(m => m.Role).SingleOrDefaultAsync(m => m.Id == id);
    public void Add(Member member) => db.Members.Add(member);
    public Task SaveChangesAsync() => db.SaveChangesAsync();
}
