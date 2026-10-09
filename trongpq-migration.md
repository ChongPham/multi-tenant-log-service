# Ghi chú đổi tên dự án sang trongpq

Thay đổi chỉ áp dụng cho source và tên file trong repository. Chưa chạy plan/apply, đổi GitHub Environment, sửa IAM hay di chuyển Terraform state.

## Trước khi triển khai lại môi trường đang tồn tại

- Workflow mới: `.github/workflows/trongpq.yml`; environment: `trongpq-qa` và `trongpq-prod`. Thiết lập các GitHub Environment tương ứng và chuyển đủ variables, secrets, protection rules. Cập nhật OIDC trust subject theo environment/repository thực tế. Prod vẫn đang bị comment như trước.
- Tên repository trong Terraform tags là `trongpq/trongpq`; thay đổi tag không đổi repository thật trên GitHub.
- Tên state bucket trong collectors tfvars đã đổi theo tên dự án. Backend của workflow vẫn lấy từ GitHub variable `TF_STATE_BUCKET_PREFIX`. Hai bên phải trỏ tới cùng core state. Không dùng state trống để triển khai chồng lên resource cũ; giữ backend đang quản lý chúng hoặc migration state có kế hoạch trước.
- Tên S3 bucket, Secrets Manager secret, ECS cluster, IAM query role, KMS alias và các tên hiển thị đã đổi. Review plan cho các thao tác replacement/deletion; đây không phải migration hạ tầng tự động.
- Các IAM ARN chứa tên dự án đã được đổi trong tfvars nhưng CHƯA xác minh resource đích tồn tại. Đặc biệt ARN `AWSReservedSSO_TrongpqAdmin_...` phải lấy từ AWS thực tế; không giữ suffix cũ chỉ vì đã đổi tên permission set. Principal không tồn tại có thể khiến cập nhật KMS policy thất bại. Không apply trước khi xác minh quyền admin và CI.
- KMS key ARN trong `.sops.yaml` và toàn bộ nội dung file SOPS được giữ nguyên. File chỉ đổi thành `core/deployment/secrets/trongpq-qa.enc.yaml`. Việc này không re-encrypt và không cần tạo KMS key mới. Rule SOPS đã đổi theo tên file. Prod chưa có encrypted secret file.
- CloudFormation đã đổi tên parameters và logical ID của ingestion secret. Khi update stack cũ, dùng change set để kiểm tra replacement và cập nhật parameter overrides bên ngoài repo.
- Metadata định tuyến đã đổi đồng bộ thành `trongpq-source-system` ở onboarding, Vector source và tenant filter. Phải phối hợp rollout producer/consumer; sender còn gửi metadata cũ sẽ không qua tenant gate mới.

## Thông tin còn cần xem xét trước khi chia sẻ source

- `core/deployment/secrets/chromeleon-key.txt` đang được Git theo dõi. Chưa mở hoặc in nội dung để xác nhận giá trị; nếu chứa access key thật, cần bỏ theo dõi file và rotate key đã lộ. Thêm `.gitignore` không xóa file đã tracked hoặc lịch sử Git.
- Đã thêm ignore cho `core/deployment/secrets/*.txt` và `*.tfplan` để tránh thêm mới các file tương tự.
- AWS account ID, KMS ARN, Organization ID, VPC/subnet ID và IAM ARN còn trong cấu hình. Đây là thông tin định danh hạ tầng, không tự nó cấp quyền truy cập. Chưa thay bằng giá trị giả để tránh làm sai cấu hình đang dùng.
- Tên ứng dụng/tenant `Chromeleon` và các metric tương ứng vẫn còn. Chưa đổi vì yêu cầu đổi tên dự án không xác định tên tenant thay thế; đổi metric sẽ ảnh hưởng dashboard/query.
- Ciphertext SOPS vẫn mang metadata KMS cần thiết để giải mã. Không sửa trực tiếp ciphertext hoặc metadata để ẩn danh.
- Thư mục workspace, Git history, cấu hình Git, Terraform cache/state và AWS credentials không nằm trong phạm vi đổi tên source.

## Kiểm tra

- Terraform validate: core và collectors đều đạt.
- Kiểm tra định dạng Terraform và git diff whitespace được thực hiện sau đổi tên.
- Chưa chạy AWS plan/apply hoặc kiểm thử end-to-end. Validate không xác nhận IAM ARN, bucket hay GitHub Environment tồn tại.
