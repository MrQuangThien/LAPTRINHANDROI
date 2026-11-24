using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Data;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/members"), Authorize(Roles = "Admin")]
public sealed class MemberController(RestaurantDbContext db) : ControllerBase
{
    private readonly PasswordHasher<Member> _hasher = new();

    [HttpGet]
    public async Task<ActionResult<PageResponse<MemberResponse>>> List([FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20, [FromQuery] string? search = null, [FromQuery] string? role = null)
    {
        pageNumber = Math.Max(1, pageNumber); pageSize = Math.Clamp(pageSize, 1, 100);
        var query = db.Members.AsNoTracking().Include(m => m.Role).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search)) query = query.Where(m => m.FullName.Contains(search) || m.Email.Contains(search) || m.Phone.Contains(search));
        if (!string.IsNullOrWhiteSpace(role))
        {
            if (string.Equals(role, "StaffGroup", StringComparison.OrdinalIgnoreCase))
                query = query.Where(m => m.Role.Name != "Customer");
            else
                query = query.Where(m => m.Role.Name == role);
        }
        var count = await query.CountAsync();
        var items = await query.OrderBy(m => m.FullName).Skip((pageNumber - 1) * pageSize).Take(pageSize)
            .Select(m => new MemberResponse(m.Id, m.FullName, m.Email, m.Phone, m.Role.Name, m.IsActive, m.CreatedAt)).ToListAsync();
        return Ok(new PageResponse<MemberResponse>(items, pageNumber, pageSize, count));
    }

    [HttpPost]
    public async Task<ActionResult<MemberResponse>> Create(CreateMemberRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant(); var phone = request.Phone.Trim();
        if (await db.Members.AnyAsync(m => m.Email == email || m.Phone == phone)) return Conflict(new { message = "Email or phone number already exists." });
        var role = await db.Roles.SingleOrDefaultAsync(r => r.Name == request.Role);
        if (role is null || role.Name == "Admin") return BadRequest(new { message = "A valid non-admin role is required." });
        var member = new Member { FullName = request.FullName.Trim(), Email = email, Phone = phone, RoleId = role.Id, IsActive = true };
        member.PasswordHash = _hasher.HashPassword(member, request.Password);
        db.Members.Add(member); await db.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = member.Id }, new MemberResponse(member.Id, member.FullName, member.Email, member.Phone, role.Name, true, member.CreatedAt));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, UpdateMemberRequest request)
    {
        var member = await db.Members.Include(m => m.Role).SingleOrDefaultAsync(m => m.Id == id);
        if (member is null) return NotFound();
        var email = request.Email.Trim().ToLowerInvariant(); var phone = request.Phone.Trim();
        if (await db.Members.AnyAsync(m => m.Id != id && (m.Email == email || m.Phone == phone))) return Conflict(new { message = "Email or phone number already exists." });
        if (!string.IsNullOrWhiteSpace(request.Role) && member.Role.Name != "Admin")
        {
            var role = await db.Roles.SingleOrDefaultAsync(r => r.Name == request.Role);
            if (role is null || role.Name == "Admin") return BadRequest(new { message = "A valid non-admin role is required." });
            member.RoleId = role.Id;
        }
        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            if (request.Password.Length < 10) return BadRequest(new { message = "Password must be at least 10 characters." });
            member.PasswordHash = _hasher.HashPassword(member, request.Password);
        }
        member.FullName = request.FullName.Trim(); member.Email = email; member.Phone = phone;
        await db.SaveChangesAsync(); return NoContent();
    }

    [HttpPatch("{id:int}/active")]
    public async Task<IActionResult> SetActive(int id, [FromQuery] bool active)
    {
        var member = await db.Members.FindAsync(id); if (member is null) return NotFound();
        if (member.Id == int.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value) && !active)
            return BadRequest(new { message = "You cannot deactivate your own account." });
        member.IsActive = active; await db.SaveChangesAsync(); return NoContent();
    }
}
