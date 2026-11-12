<p align="center">
  <img src="docs/images/app-icon.png" width="132" alt="Biểu tượng ứng dụng dekpop">
</p>

<h1 align="center">dekpop</h1>

<p align="center">
  Ứng dụng iOS chỉ có một chức năng: duyệt và quản lý tệp trong app container.
</p>

<p align="center">
  <img alt="Phiên bản" src="https://img.shields.io/badge/phiên%20bản-1.2.0-6C4CF1?style=flat-square">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-Mọi%20phiên%20bản%2016.0%2B-222222?style=flat-square">
  <img alt="Ngôn ngữ" src="https://img.shields.io/badge/ngôn%20ngữ-English%20%7C%20Tiếng%20Việt%20%7C%20简体中文-6C4CF1?style=flat-square">
</p>

<p align="center"><a href="README.md">English</a> · <a href="docs/QUICKSTART.th.md">คู่มือภาษาไทย</a> · <a href="#giấy-phép">Giấy phép</a></p>

> [!WARNING]
> dekpop là phần mềm nghiên cứu để quản lý thiết bị cá nhân. Chỉ sử dụng trên thiết bị và dữ liệu của bạn, và luôn sao lưu trước khi thay đổi dữ liệu ứng dụng.

## Có gì mới trong 1.2.0 — bản dekpop

- **Thiết kế lại hoàn toàn** — hệ màu tím → hồng, wordmark riêng, thẻ hero gradient hiển thị thiết bị / iOS / trạng thái truy cập, điều khiển bo tròn và icon 1024×1024 mới.
- **Chỉ còn tính năng Files** — đã bỏ tab bar, dashboard, patch, cleaner, Wallpaper Lab, onboarding, attribution, thông báo cập nhật và xử lý URL import patch. Ứng dụng mở thẳng vào trình duyệt tệp.
- **Định danh riêng** — tên hiển thị, `PRODUCT_NAME`, executable và bundle `.app` đều là `dekpop`; phiên bản `1.2.0` (build 8); chuỗi EN / VI / ZH đã cập nhật.
- **CI đổi tên** — artifact `dekpop-unsigned-ipa` chứa `dekpop-unsigned.ipa` (`Payload/dekpop.app/`).

> [!IMPORTANT]
> Bundle ID vẫn giữ `com.apple.mobile.MobileHouseArrest`. `mcm_bridge.m` kiểm tra identifier này trước khi kích hoạt MHA-C2; đổi đi sẽ làm hỏng tính năng Files. Chỉ phần định danh nhìn thấy được thay đổi.

Các tài liệu cũ trong `docs/PATCH_GUIDE*.md` mô tả tính năng của bản 1.0/1.1 và không còn dùng được trong dekpop.

## Tính năng chính

- Duyệt dữ liệu ứng dụng theo **bundle identifier**, không phụ thuộc UUID container.
- Quản lý tệp: tìm kiếm, xem trước, chia sẻ, nhập nhiều tệp, sao chép, di chuyển, dán, đổi tên, xóa, tạo tệp/thư mục, nén/giải nén ZIP, xử lý trùng tên.
- Nhiều tab độc lập, giữ nguyên vị trí thư mục (iPad có thanh tab).
- Workspace `dekpop` trong `Trên iPhone của tôi`.
- Không cài jailbreak, bootstrap hay daemon thường trú; không inject mã vào ứng dụng bên thứ ba.
- Hỗ trợ tiếng Anh, tiếng Việt và tiếng Trung giản thể.

## Phiên bản iOS được hỗ trợ

Mọi phiên bản iOS có thể cài đặt ứng dụng đều được bật — không còn danh sách phiên bản hay build:

| Mục | Trạng thái |
| --- | --- |
| Phiên bản hỗ trợ | Mọi iOS từ 16.0 trở lên |
| Danh sách build | Đã xóa |
| Deployment target | iOS 16.0 |
| Offset dự phòng | Bộ iOS 26.0 cho bản 26.1+ chưa xác minh; bộ iOS 17.0 cho bản dưới 17.0 |

> [!NOTE]
> Kernel exploit vẫn cần offsets khớp kernel đang chạy. Với iOS chưa có trong bảng offsets, app ghi log `offsets: ... unverified` và dùng bộ offsets mới nhất thay vì thoát ngay. Một lần exploit thất bại có thể khiến app khởi động lại.

## Lưu ý cài đặt

- Cần ký bằng **chứng chỉ doanh nghiệp**.
- Không hỗ trợ SideStore, AltStore, 3uTools hoặc LiveContainer.
- Bundle ID `com.apple.mobile.MobileHouseArrest` được giữ có chủ đích cho luồng MHA-C2.
- CI tạo IPA **unsigned**; bạn tự ký bằng certificate/profile của mình (ESign trên máy, hoặc `scripts/resign-windows-zsign.ps1`). Xem [README.md](README.md#build-sign--install) và [hướng dẫn tiếng Thái](docs/QUICKSTART.th.md).

## Tác giả và ghi công

dekpop là bản chỉnh sửa Files-only từ dự án 3105 của [YangJiii](https://x.com/duongduong0908). Xem [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) để biết các dự án nền tảng.

## Giấy phép

Phần mã gốc của dự án 3105 được phát hành theo [GNU General Public License v3.0](LICENSE). Thành phần bên thứ ba tuân theo điều khoản riêng; xem [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Phần branding và giao diện mới của dekpop đi cùng điều khoản đó.
