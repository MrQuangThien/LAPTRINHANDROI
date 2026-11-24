$ErrorActionPreference = 'Stop'

Write-Host "=== Bếp Nhà Coffee & Kitchen - Triển khai với ngrok ===" -ForegroundColor Cyan

# 1. Kiểm tra Backend trên cổng 5000
$conn5000 = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
if (-not $conn5000) {
    Write-Host "Đang khởi động Backend ASP.NET Core trên cổng 5000..." -ForegroundColor Yellow
    Start-Process -FilePath "dotnet" -ArgumentList "run --launch-profile http --project `"$PSScriptRoot\backend\RestaurantManagement.API\RestaurantManagement.API.csproj`"" -WindowStyle Minimized
    Start-Sleep -Seconds 5
} else {
    Write-Host "Backend đang chạy sẵn trên cổng 5000." -ForegroundColor Green
}

# 2. Mở ngrok tunnel cho cổng 5000
$existingNgrok = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if (-not $existingNgrok) {
    Write-Host "Đang mở ngrok http 5000..." -ForegroundColor Yellow
    Start-Process -FilePath "ngrok" -ArgumentList "http 5000" -WindowStyle Minimized
    Start-Sleep -Seconds 3
}

# 3. Lấy URL public từ ngrok API cục bộ (127.0.0.1:4040)
try {
    $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 5
    $httpsUrl = ($tunnels.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1).public_url
    if (-not $httpsUrl) {
        $httpsUrl = ($tunnels.tunnels | Select-Object -First 1).public_url
    }
    Write-Host ""
    Write-Host "NGROK PUBLIC URL: $httpsUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "Lệnh build APK Android trỏ vào ngrok:" -ForegroundColor Cyan
    Write-Host "  cd frontend\restaurant_app"
    Write-Host "  flutter build apk --release --dart-define=API_BASE_URL=$httpsUrl"
    Write-Host ""
    Write-Host "Hoặc chạy trực tiếp trên điện thoại / máy ảo / Windows:" -ForegroundColor Cyan
    Write-Host "  flutter run --dart-define=API_BASE_URL=$httpsUrl"
} catch {
    Write-Host "Không kết nối được tới ngrok (http://127.0.0.1:4040)." -ForegroundColor Red
    Write-Host "Vui lòng cấu hình authtoken trước bằng lệnh:" -ForegroundColor Yellow
    Write-Host "  ngrok config add-authtoken <TOKEN_CUA_BAN>"
}
