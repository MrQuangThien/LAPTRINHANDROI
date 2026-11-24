# Restaurant Management

Ứng dụng quản lý nhà hàng/quán cà phê: Flutter Android, SQLite cache/offline queue, ASP.NET Core Web API .NET 10 và SQL Server làm nguồn dữ liệu chính.

## Trạng thái triển khai

- Giai đoạn 1: khởi tạo Flutter, API .NET 10, thư mục, package nền tảng và giao diện khởi đầu.
- Giai đoạn 2: entity, Fluent API, seed role, EF Core migration `InitialCreate`; đã áp dụng lên SQL Server `DESKTOP-73Q6JO8`, database `RestaurantManagement`.
- Giai đoạn 3: JWT authentication, role authorization, CRUD cơ bản cho thành viên/danh mục/món/khu vực/bàn, upload ảnh, order idempotency, kitchen, checkout/payment/invoice và reports.
- Giai đoạn 4: Flutter đăng ký/đăng nhập JWT, dashboard theo role, thực đơn, bàn, SQLite cache/offline drafts, queue idempotent và đồng bộ order.
- Giai đoạn 5: Flutter có màn hình order/bếp/thu ngân/hóa đơn/báo cáo, CRUD danh mục/món/khu vực/bàn, quản lý nhân viên và trang khách hàng để xem menu, đặt bàn, order, theo dõi thanh toán và hóa đơn.

## Môi trường

- .NET SDK 10 và `dotnet-ef` 10
- Flutter stable, Android SDK
- SQL Server 2022
- VS Code với C# Dev Kit và Flutter extensions

## Cấu hình và chạy backend

Không lưu credentials trong source hoặc appsettings. Thiết lập biến môi trường trong PowerShell:

```powershell
cd backend/RestaurantManagement.API
dotnet user-secrets init
dotnet user-secrets set ConnectionStrings:DefaultConnection 'Server=tcp:YOUR_SERVER,1433;Database=RestaurantManagement;User Id=YOUR_SQL_USER;Password=YOUR_PASSWORD;Encrypt=True;TrustServerCertificate=True;'
$jwt = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
dotnet user-secrets set Jwt:Key $jwt
dotnet user-secrets set Jwt:Issuer RestaurantManagement
dotnet user-secrets set Jwt:Audience RestaurantManagementApp
dotnet run --launch-profile http
```

API refuses to start without a JWT signing key of at least 32 bytes. Keep the same generated key private across API restarts so active tokens continue to validate. VAT is calculated server-side using `Payments:TaxRate` (percentage); default is 0 until configured with `$env:Payments__TaxRate`. Swagger/OpenAPI JSON is available at `/openapi/v1.json` in Development; health endpoint: `/api/health`.

The HTTP launch profile listens on `0.0.0.0:5000` for emulator/LAN access. This workstation already has its SQL Server connection and JWT values in the .NET User Secrets store; no secret is committed to the repository. Database has already been created. Apply later schema migrations with:

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet ef database update --project backend/RestaurantManagement.API
```

### Optional first Admin account

Set all bootstrap values before starting the API. Email and password are required; password must have at least 12 characters. The bootstrapper creates an Admin only if that email does not exist and hashes its password with `PasswordHasher<Member>`. The configured short username is accepted as a sign-in alias for that bootstrap Admin; other members continue to sign in with email.

```powershell
$env:AdminBootstrap__Name = 'System Administrator'
$env:AdminBootstrap__Username = 'admin'
$env:AdminBootstrap__Email = 'admin@your-domain.local'
$env:AdminBootstrap__Phone = 'YOUR_ADMIN_PHONE'
$env:AdminBootstrap__Password = 'A_UNIQUE_LONG_PASSWORD'
```

Public registration always assigns the `Staff` role; it cannot create an Admin. Admin endpoints require a valid bearer token with the Admin role.

On this workstation, the Admin bootstrap values are already stored in .NET User Secrets and the initial Admin has been created in the SQL Server database. Keep those values private; the password is stored as a one-way hash in SQL Server.

## Implemented API routes

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`, `POST /api/auth/change-password`, `POST /api/auth/logout`
- `GET/POST/PUT/DELETE /api/categories` plus `POST /api/categories/{id}/image`
- `GET/POST/PUT/DELETE /api/products`, `GET /api/products/{id}`, plus `POST /api/products/{id}/image`
- `GET/POST/PUT/DELETE /api/areas`
- `GET/POST/PUT/DELETE /api/tables`
- `POST /api/tables/{id}/cleaned`, `/transfer`, `/merge` (chuyển order sang bàn trống hoặc gộp chỗ ngồi; giữ riêng từng order và hóa đơn)
- `GET/POST /api/orders`, `GET /api/orders/{id}`, `POST /api/orders/{id}/items|confirm|cancel|served` (ClientRequestId unique chống gửi lặp)
- Customer portal: `GET /api/customer/tables`, `POST /api/customer/reservations`, `GET /api/customer/reservations/{code}`, `POST /api/customer/orders`, `GET /api/customer/orders/{trackingCode}`, `POST /api/customer/orders/{trackingCode}/payment-request`
- Nhân viên phục vụ: `GET /api/customer/reservations`, `PATCH /api/customer/reservations/{id}/status`
- Khách xem hóa đơn đã thanh toán: `GET /api/invoices/guest/{trackingCode}` (tracking UUID đóng vai trò mã bí mật; cần giữ riêng)
- Kitchen: `GET /api/kitchen/orders`, start/ready/served actions
- Payment: pending orders, checkout, payment history; checkout creates one invoice transactionally and moves table to Cleaning
- `GET /api/invoices/{id}` and `/api/invoices/by-order/{orderId}`
- `GET /api/reports/dashboard|revenue|order-statuses`
- Admin-only `GET/POST /api/members`, `PUT /api/members/{id}`, `PATCH /api/members/{id}/active`, `GET /api/roles`

List APIs support page number, page size and search/filter as applicable. Image uploads accept JPEG, PNG or WebP up to 5 MB. Product records used by historical orders are set unavailable instead of being hard-deleted.

### Luồng phục vụ và tính tiền

1. Nhân viên mở bàn trống hoặc tiếp tục order của bàn đang phục vụ. Order giữ giá tại thời điểm tạo và có mã idempotency để retry offline không tạo trùng.
2. Nhân viên xác nhận order; bếp nhận và chuyển món qua Preparing rồi Ready. Món gọi thêm được thêm vào order đang chế biến dưới dạng dòng Pending riêng để bếp nhận tiếp.
3. Nhân viên phục vụ đánh dấu order Ready là Served. Thu ngân có thể thanh toán ngay khi order Ready hoặc Served; backend tính lại giảm giá/VAT, tạo Payment và Invoice trong cùng transaction, đồng thời chặn thanh toán lần hai.
4. Sau thanh toán hoặc hủy order cuối cùng, bàn chuyển sang Cleaning. Nếu bàn gộp vẫn còn order mở, bàn tiếp tục Occupied. Nhân viên xác nhận dọn xong mới đưa bàn về Available. Chuyển bàn chỉ nhận bàn trống; gộp bàn chuyển các order mở sang bàn đang phục vụ nhưng giữ riêng ticket, thanh toán và hóa đơn.

Thanh toán chuyển khoản/VietQR hiện lưu mã tham chiếu giao dịch do thu ngân nhập; hệ thống chưa kết nối ngân hàng để tự xác thực tiền vào. VAT mặc định 0% và cần cấu hình theo chính sách thuế của cơ sở trước khi vận hành thật.

Khách không cần đăng nhập để duyệt menu, đặt bàn và order. Đơn khách được gửi vào hàng đợi phục vụ/bếp; thu ngân xác nhận tiền đã nhận rồi hệ thống mới tạo hóa đơn. Mã tracking UUID được lưu trên thiết bị sau khi order và có thể dùng trên thiết bị khác để tra cứu; ai có mã này đều có thể xem trạng thái và hóa đơn của đơn đó. Đặt bàn được xác nhận ngay nếu bàn còn trống trong khung 90 phút; nhân viên có thể đánh dấu khách đã đến, hủy hoặc không đến.

## Chạy Flutter

### Windows desktop

Mở API trước trong terminal thứ nhất, sau đó chạy ứng dụng desktop trong terminal thứ hai:

```powershell
cd backend/RestaurantManagement.API
dotnet run --launch-profile http

# Terminal thứ hai
cd frontend/restaurant_app
flutter pub get
flutter run -d windows
```

Trên Windows, ứng dụng tự dùng `http://localhost:5000` và SQLite FFI. Trên Android emulator, địa chỉ mặc định vẫn là `http://10.0.2.2:5000`. Có thể ghi đè bằng `--dart-define=API_BASE_URL=...`.

### Android

```powershell
cd frontend/restaurant_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Android emulator truy cập máy host qua `10.0.2.2`. Thiết bị thật cần dùng IP LAN của máy chạy API (ví dụ `http://192.168.x.x:5000`) và cùng mạng. Chạy API bind `0.0.0.0:5000` để thiết bị trong LAN truy cập. Debug manifest cho phép HTTP; bản production cần cấu hình HTTPS. `API_BASE_URL` có thể truyền qua `--dart-define`. JWT/session metadata được lưu bằng flutter_secure_storage; cache, bản nháp và hàng đợi order offline dùng SQLite. Khi mở lại order nháp chưa gửi, ứng dụng khôi phục số lượng và ghi chú theo bàn.

## Database boundaries

SQL Server is the source of truth. SQLite on Flutter stores cached catalog/table data, local order drafts and an idempotent offline order queue. The queue retries through the REST API and removes successfully synchronized operations. It does not overwrite server records from cache. If an offline request remains unresolved, it stays queued for retry and is visible from the dashboard.

## Bảo mật

Không commit mật khẩu SQL Server, JWT secret, token hoặc tài khoản bootstrap. Mật khẩu `sa` đã được chia sẻ trong trao đổi; nên đổi sang mật khẩu mạnh trước khi dùng môi trường thật. Logout hiện là stateless ở API; client phải xóa token. Token đã phát hành sẽ hết hạn sau 8 giờ.




