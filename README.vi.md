<p align="center">
  <img src="docs/images/app-icon.png" width="132" alt="Biểu tượng ứng dụng 3105">
</p>

<h1 align="center">3105</h1>

<p align="center">
  Trình quản lý dữ liệu ứng dụng, patch theo bundle, dọn dẹp giới hạn và hình nền PosterBoard dành cho iOS.
</p>

<p align="center">
  <img alt="Phiên bản" src="https://img.shields.io/badge/phiên%20bản-1.0.1-E6753A?style=flat-square">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-Mọi%20phiên%20bản%2016.0%2B-222222?style=flat-square">
  <img alt="Ngôn ngữ" src="https://img.shields.io/badge/ngôn%20ngữ-English%20%7C%20Tiếng%20Việt%20%7C%20简体中文-E6753A?style=flat-square">
</p>

<p align="center"><a href="README.md">English</a> · <a href="docs/PATCH_GUIDE.vi.md">Hướng dẫn Patch</a> · <a href="#giấy-phép">Giấy phép</a></p>

> [!WARNING]
> 3105 là phần mềm nghiên cứu để quản lý thiết bị cá nhân. Chỉ sử dụng trên thiết bị và dữ liệu thuộc quyền sở hữu của bạn, đồng thời luôn sao lưu trước khi thay đổi dữ liệu ứng dụng.

## Giao diện

<p align="center">
  <img src="docs/images/home.png" width="245" alt="Trang chủ 3105">
  &nbsp;
  <img src="docs/images/patches.png" width="245" alt="Patch 3105">
  &nbsp;
  <img src="docs/images/cleaner.png" width="245" alt="Dọn dẹp 3105">
</p>

## Có gì mới trong bản hiện tại

- **Mọi phiên bản iOS** — đã bỏ danh sách phiên bản và build beta được xác minh. Mọi iOS có thể cài app (từ 16.0) đều được bật, kể cả iOS 27 chính thức, các beta sau này và phiên bản lớn hơn trong tương lai.
- **Không còn dừng đột ngột** — `offsets_init` dùng bộ offsets mới nhất làm dự phòng và ghi log `offsets: ... unverified` thay vì kết thúc exploit.
- **Nhận diện kernel cho iOS 27+** — chấp nhận cả khi magic word thứ hai khác iOS 26.
- **Wallpaper Lab trên mọi iOS** — tab Hình nền không còn giới hạn ở iOS 17/18/26/27.

## Có gì mới trong 1.0.1

- **Patch workspace v2** — tạo patch bằng cây thư mục theo bundle trong `Trên iPhone của tôi/3105/Patches`; khi Áp dụng hoặc Xuất, app tự đồng bộ toàn bộ workspace.
- **Khôi phục an toàn hơn** — file gốc được ghi nhật ký và sao lưu trước khi thay; Khôi phục sẽ trả lại file cũ, xóa file do patch thêm và dọn các thư mục mới nếu đã rỗng.
- **Tab Tệp đầy đủ hơn** — nhiều tab độc lập, giữ nguyên vị trí thư mục, chọn nhiều file, nén/giải nén ZIP và giao diện nhóm cân đối hơn.
- **Giao diện thích ứng** — hỗ trợ iPad dạng split view/landscape, cho phép ẩn Dọn dẹp hoặc Hình nền, giữ ổn định ô tìm kiếm và cân lại kích thước icon/hàng.
- **Hướng dẫn Hình nền chính xác** — bổ sung đúng bước đóng PosterBoard và lưu ý nhận hình nền Bộ Sưu Tập trước trên iOS 27.

Xem [hướng dẫn Patch workspace đầy đủ](docs/PATCH_GUIDE.vi.md).

## Tính năng chính

- Duyệt dữ liệu ứng dụng theo **bundle identifier**, không phụ thuộc UUID container của từng máy.
- Trình quản lý tệp có tìm kiếm, xem trước, chia sẻ, nhập nhiều tệp, sao chép, di chuyển, dán, đổi tên, xóa, tạo tệp/thư mục, nén ZIP và xử lý trùng tên.
- Tạo và nhập dự án patch `.3105` theo bundle, hỗ trợ nhiều quy tắc, tệp/thư mục, mật khẩu tùy chọn và nhập từ Files hoặc liên kết website bảo mật.
- Dọn dẹp giới hạn trong `Library/Caches` và `tmp`, hỗ trợ sắp xếp dung lượng và chọn nhiều ứng dụng, luôn hiển thị cảnh báo trước khi xóa.
- Nhập gói hình nền `.tendies`, xác thực payload và chỉ reset nội dung do 3105 cài đặt.
- 3105 không cài jailbreak, bootstrap hay daemon thường trú và không inject mã vào ứng dụng bên thứ ba. Do ứng dụng vẫn dùng khai thác thiết bị và có thể sửa dữ liệu app, không thể bảo đảm vượt qua mọi cơ chế kiểm tra tính toàn vẹn hoặc phát hiện jailbreak.
- Hỗ trợ tiếng Anh, tiếng Việt và tiếng Trung giản thể.

## Phiên bản iOS được hỗ trợ

3105 không còn chặn tính năng theo phiên bản iOS hay build. Mọi phiên bản có thể cài đặt ứng dụng đều được bật:

| Mục | Trạng thái |
| --- | --- |
| Phiên bản hỗ trợ | Mọi iOS từ 16.0 trở lên (chính thức, beta và các bản lớn hơn trong tương lai) |
| Danh sách build | Đã xóa — không còn danh sách build beta |
| Deployment target | iOS 16.0 |
| Offset dự phòng | Dùng bộ iOS 26.0 cho bản 26.1+ chưa xác minh; bộ iOS 17.0 cho bản dưới 17.0 |

> [!NOTE]
> Kernel exploit vẫn cần offsets khớp với kernel đang chạy. Với phiên bản iOS chưa có trong bảng offsets, exploit có thể thất bại; app sẽ ghi log `offsets: ... unverified` và dùng bộ offsets mới nhất thay vì thoát ngay. Một lần exploit thất bại có thể khiến app khởi động lại.

## Lưu ý cài đặt

- Các chức năng trên thiết bị yêu cầu ứng dụng được ký bằng **chứng chỉ doanh nghiệp**.
- Không hỗ trợ SideStore, AltStore, 3uTools hoặc LiveContainer.
- Bundle ID `com.apple.mobile.MobileHouseArrest` được giữ có chủ đích cho luồng MHA-C2.
- Cây mã nguồn không chứa chứng chỉ, provisioning profile, ứng dụng đã ký hoặc IPA; phần Release có thể cung cấp IPA unsigned.

## Tác giả và ghi công

3105 được phát triển và thiết kế bởi [YangJiii](https://x.com/duongduong0908). Xem [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) để biết các dự án và nhà phát triển nền tảng đã được sử dụng/tham khảo.

## Giấy phép

Phần mã gốc của 3105 được phát hành theo [GNU General Public License v3.0](LICENSE). Thành phần của bên thứ ba vẫn tuân theo bản quyền và điều khoản của dự án nguồn tương ứng; xem [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
