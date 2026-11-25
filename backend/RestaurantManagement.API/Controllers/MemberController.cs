using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RestaurantManagement.API.DTOs;
using RestaurantManagement.API.Models;
using RestaurantManagement.API.Repositories;

namespace RestaurantManagement.API.Controllers;

[ApiController, Route("api/members"), Authorize(Roles = "Admin")]
public sealed class MemberController(IMemberRepository members) : ControllerBase
{
    private readonly PasswordHasher<Member> _hasher = new();

    [HttpGet]
    public async Task<ActionResult<PageResponse<MemberResponse>>> List([FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20, [FromQuery] string? search = null, [FromQuery] string? role = null)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return Ok(await members.ListAsync(pageNumber, pageSize, search, role));
    }

    [HttpPost]
    public async Task<ActionResult<MemberResponse>> Create(CreateMemberRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var phone = request.Phone.Trim();
        if (await members.ExistsEmailOrPhoneAsync(email, phone))
            return Conflict(new { message = "Email or phone number already exists." });
        var role = await members.FindRoleByNameAsync(request.Role);
        if (role is null || role.Name == "Admin")
            return BadRequest(new { message = "A valid non-admin role is required." });
        var member = new Member { FullName = request.FullName.Trim(), Email = email, Phone = phone, RoleId = role.Id, IsActive = true };
        member.PasswordHash = _hasher.HashPassword(member, request.Password);
        members.Add(member);
        await members.SaveChangesAsync();
        return CreatedAtAction(nameof(List), new { id = member.Id }, new MemberResponse(member.Id, member.FullName, member.Email, member.Phone, role.Name, true, member.CreatedAt));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, UpdateMemberRequest request)
    {
        var member = await members.FindWithRoleAsync(id);
        if (member is null) return NotFound();
        var email = request.Email.Trim().ToLowerInvariant();
        var phone = request.Phone.Trim();
        if (await members.ExistsEmailOrPhoneAsync(email, phone, id))
            return Conflict(new { message = "Email or phone number already exists." });
        if (!string.IsNullOrWhiteSpace(request.Role) && member.Role.Name != "Admin")
        {
            var role = await members.FindRoleByNameAsync(request.Role);
            if (role is null || role.Name == "Admin")
                return BadRequest(new { message = "A valid non-admin role is required." });
            member.RoleId = role.Id;
        }
        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            if (request.Password.Length < 10) return BadRequest(new { message = "Password must be at least 10 characters." });
            member.PasswordHash = _hasher.HashPassword(member, request.Password);
        }
        member.FullName = request.FullName.Trim();
        member.Email = email;
        member.Phone = phone;
        await members.SaveChangesAsync();
        return NoContent();
    }

    [HttpPatch("{id:int}/active")]
    public async Task<IActionResult> SetActive(int id, [FromQuery] bool active)
    {
        var member = await members.FindByIdAsync(id);
        if (member is null) return NotFound();
        if (member.Id == int.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value) && !active)
            return BadRequest(new { message = "You cannot deactivate your own account." });
        member.IsActive = active;
        await members.SaveChangesAsync();
        return NoContent();
    }
}
