using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RestaurantManagement.API.Models;

namespace RestaurantManagement.API.Data;

public static class AdminBootstrapper
{
    // Optional one-time bootstrap. Secrets are read from environment-backed configuration only.
    public static async Task EnsureAdminAsync(IServiceProvider services, IConfiguration configuration)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<RestaurantDbContext>();
        await db.Database.MigrateAsync();
        await db.Database.ExecuteSqlRawAsync("""
            IF OBJECT_ID(N'BlogPosts', N'U') IS NULL
            BEGIN
                CREATE TABLE [BlogPosts] (
                    [Id] int NOT NULL IDENTITY,
                    [Title] nvarchar(200) NOT NULL,
                    [Category] nvarchar(80) NOT NULL,
                    [Summary] nvarchar(500) NOT NULL,
                    [Content] nvarchar(max) NOT NULL,
                    [ImageUrl] nvarchar(500) NULL,
                    [AuthorName] nvarchar(120) NOT NULL,
                    [ReadingMinutes] int NOT NULL,
                    [IsFeatured] bit NOT NULL,
                    [IsPublished] bit NOT NULL,
                    [PublishedAtUtc] datetime2 NOT NULL,
                    CONSTRAINT [PK_BlogPosts] PRIMARY KEY ([Id])
                );
            END
            IF COL_LENGTH('Members', 'IsEmailVerified') IS NULL
                ALTER TABLE [Members] ADD [IsEmailVerified] bit NOT NULL CONSTRAINT [DF_Members_IsEmailVerified] DEFAULT 0;
            IF COL_LENGTH('Members', 'EmailVerificationCode') IS NULL
                ALTER TABLE [Members] ADD [EmailVerificationCode] nvarchar(12) NULL;
            IF COL_LENGTH('Members', 'EmailVerificationExpiryUtc') IS NULL
                ALTER TABLE [Members] ADD [EmailVerificationExpiryUtc] datetime2 NULL;
            IF COL_LENGTH('Members', 'PasswordResetCode') IS NULL
                ALTER TABLE [Members] ADD [PasswordResetCode] nvarchar(12) NULL;
            IF COL_LENGTH('Members', 'PasswordResetExpiryUtc') IS NULL
                ALTER TABLE [Members] ADD [PasswordResetExpiryUtc] datetime2 NULL;
            IF COL_LENGTH('Members', 'AuthProvider') IS NULL
                ALTER TABLE [Members] ADD [AuthProvider] nvarchar(30) NULL;
            """);

        if (!await db.Roles.AnyAsync(r => r.Name == "Customer"))
        {
            db.Roles.Add(new Role { Name = "Customer", Description = "Customer account" });
            await db.SaveChangesAsync();
        }

        if (!await db.BlogPosts.AnyAsync())
        {
            db.BlogPosts.AddRange(
                new BlogPost
                {
                    Title = "Hành trình hạt cà phê Arabica Cầu Đất tại Bếp Nhà",
                    Category = "Cà phê & Pha chế",
                    Summary = "Từ những đồi cà phê chín đỏ ở độ cao 1.600m tại Cầu Đất đến ly cà phê thơm nồng mỗi sáng tại Bếp Nhà.",
                    Content = """
                        Tại Bếp Nhà, mỗi tách cà phê được bắt đầu từ những nông trại liên kết tại vùng Cầu Đất – Đà Lạt, nơi có độ cao hơn 1.600m cùng khí hậu sương mù quanh năm giúp hạt Arabica tích tụ hương thơm hoa trái tự nhiên và vị chua thanh tao.

                        1. Thu hái 100% trái chín đỏ:
                        Chúng tôi chỉ chọn những mẻ cà phê được hái lựa thủ công từng trái chín mọng, sơ chế theo phương pháp Washed và Honey để giữ trọn hậu vị ngọt sâu.

                        2. Rang mộc theo mẻ nhỏ mỗi tuần:
                        Không sử dụng hương liệu hay phụ gia, hạt cà phê tại Bếp Nhà được rang ở mức Medium-Light và Medium cho từng dòng pha máy Espresso và pha Phin truyền thống.

                        3. Thưởng thức trọn vẹn:
                        Dù bạn yêu thích một ly Bạc Xỉu béo thơm buổi sáng hay một ly Cold Brew ủ lạnh 18 giờ thanh mát buổi chiều, đội ngũ Barista của Bếp Nhà luôn sẵn sàng phục vụ tại bàn với sự tận tâm nhất.
                        """,
                    AuthorName = "Barista Trưởng • Bếp Nhà",
                    ReadingMinutes = 4,
                    IsFeatured = true,
                    IsPublished = true,
                    PublishedAtUtc = DateTime.UtcNow.AddDays(-5),
                },
                new BlogPost
                {
                    Title = "Bí quyết nước dùng ninh xương 12 giờ và nguyên liệu tươi mỗi ngày",
                    Category = "Ẩm thực Bếp Nhà",
                    Summary = "Khám phá gian bếp mở của Bếp Nhà – nơi các món ăn nóng hổi được chế biến từ rau củ hữu cơ Đà Lạt và gia vị truyền thống.",
                    Content = """
                        Bên cạnh quầy cà phê thủ công, gian bếp của Bếp Nhà được vận hành theo tiêu chuẩn tươi – sạch – nấu mới theo từng lượt gọi món (made-to-order).

                        • Nguyên liệu tuyển chọn mỗi sáng:
                        Rau xanh và nấm tươi được nhập trực tiếp mỗi ngày lúc 5h30 sáng. Thịt và hải sản đều có nguồn gốc kiểm định rõ ràng, bảo quản lạnh đúng chuẩn nhiệt độ.

                        • Nước dùng ngọt thanh tự nhiên:
                        Các món nước và sốt nền của Bếp Nhà được ninh chậm từ xương ống, củ cải trắng, hành tây nướng và thảo mộc tự nhiên suốt 12 giờ, hoàn toàn hạn chế bột ngọt công nghiệp.

                        • Phục vụ đồng bộ từ Bếp ra Bàn:
                        Nhờ hệ thống điều phối đơn trực tiếp từ bàn ăn xuống màn hình Bếp, món ăn luôn được trình bày và mang ra bàn ngay khi vừa hoàn tất chế biến để giữ độ nóng giòn.
                        """,
                    AuthorName = "Bếp Trưởng • Bếp Nhà",
                    ReadingMinutes = 3,
                    IsFeatured = true,
                    IsPublished = true,
                    PublishedAtUtc = DateTime.UtcNow.AddDays(-3),
                },
                new BlogPost
                {
                    Title = "Không gian sân vườn xanh mát & phòng lạnh yên tĩnh cho mọi cuộc hẹn",
                    Category = "Không gian quán",
                    Summary = "Gợi ý chọn khu vực bàn phù hợp cho buổi làm việc cá nhân, hẹn hò cuối tuần hay tiệc họp mặt gia đình ấm cúng.",
                    Content = """
                        Bếp Nhà được thiết kế với nhiều phân khu riêng biệt để đáp ứng trọn vẹn nhu cầu của từng thực khách:

                        1. Khu Sân Vườn Nhiệt Đới:
                        Rợp bóng cây xanh và ánh nắng tự nhiên, rất thích hợp cho những buổi cà phê sáng cuối tuần hoặc trò chuyện thư giãn cùng bạn bè.

                        2. Khu Phòng Lạnh & Bàn Làm Việc:
                        Trang bị máy lạnh mát mẻ, ổ cắm điện tại từng bàn, ánh sáng dịu mắt và đường truyền Wi-Fi tốc độ cao miễn phí – không gian lý tưởng để làm việc và học tập.

                        3. Khu Bàn Gia Đình & Nhóm Bạn:
                        Các bàn lớn từ 6–10 chỗ ngồi, hỗ trợ đặt bàn giữ chỗ trước tối đa 30 ngày ngay trên ứng dụng để bạn luôn có vị trí ưng ý nhất.
                        """,
                    AuthorName = "Đội ngũ Bếp Nhà",
                    ReadingMinutes = 3,
                    IsFeatured = false,
                    IsPublished = true,
                    PublishedAtUtc = DateTime.UtcNow.AddDays(-2),
                },
                new BlogPost
                {
                    Title = "Hướng dẫn đặt bàn trước, gọi món tại bàn và thanh toán nhanh bằng VietQR",
                    Category = "Tiện ích & Ưu đãi",
                    Summary = "Trải nghiệm quy trình phục vụ không chạm hiện đại tại Bếp Nhà: Đặt bàn giữ chỗ 90 phút, theo dõi tiến độ bếp và thanh toán 1 chạm.",
                    Content = """
                        Để mang lại trải nghiệm nhanh chóng và thuận tiện nhất cho thực khách, Bếp Nhà tích hợp quy trình tự phục vụ thông minh ngay trên ứng dụng:

                        • Bước 1 – Đặt bàn giữ chỗ trước:
                        Chọn ngày giờ, số lượng khách và vị trí bàn yêu thích. Hệ thống tự động giữ bàn cho bạn trong khung 90 phút.

                        • Bước 2 – Gọi món trực tiếp & ghi chú khẩu vị:
                        Xem thực đơn kèm hình ảnh thực tế, chọn món vào giỏ và ghi chú chi tiết (ít đá, giảm ngọt, không hành...) để gửi thẳng xuống Bếp.

                        • Bước 3 – Theo dõi trạng thái món theo thời gian thực:
                        Biết ngay đơn của bạn đang ở bước Chờ xác nhận, Đang chế biến hay Món sẵn sàng.

                        • Bước 4 – Yêu cầu thanh toán & nhận hóa đơn điện tử:
                        Chọn thanh toán Tiền mặt, Chuyển khoản hoặc VietQR ngay trên máy, thu ngân xác nhận và xuất hóa đơn chi tiết tức thì.
                        """,
                    AuthorName = "Chăm sóc khách hàng • Bếp Nhà",
                    ReadingMinutes = 3,
                    IsFeatured = false,
                    IsPublished = true,
                    PublishedAtUtc = DateTime.UtcNow.AddDays(-1),
                }
            );
            await db.SaveChangesAsync();
        }

        var email = configuration["AdminBootstrap:Email"];
        var password = configuration["AdminBootstrap:Password"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password)) return;
        if (password.Length < 12) throw new InvalidOperationException("Admin bootstrap password must be at least 12 characters.");

        var normalizedEmail = email.Trim().ToLowerInvariant();
        if (await db.Members.AnyAsync(x => x.Email == normalizedEmail)) return;
        var role = await db.Roles.SingleAsync(x => x.Name == "Admin");
        var member = new Member
        {
            FullName = configuration["AdminBootstrap:Name"] ?? "System Administrator",
            Email = normalizedEmail,
            Phone = configuration["AdminBootstrap:Phone"] ?? "0900000000",
            RoleId = role.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };
        member.PasswordHash = new PasswordHasher<Member>().HashPassword(member, password);
        db.Members.Add(member);
        await db.SaveChangesAsync();
    }
}
