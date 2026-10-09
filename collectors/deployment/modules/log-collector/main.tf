## chuẩn bị nơi lưu log và IAM execution role để ECS khởi động hai container Vector, SigV4 proxy

# lấy region mà AWS provider đang sử dụng.
data "aws_region" "current" {}

# --- CloudWatch Log Groups ---

# Tạo hai CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vector" {
  name              = "/ecs/${var.service_name}/vector"
  retention_in_days = 30 # log được giữ trong 30 ngày, sau đó bị xóa.
}

resource "aws_cloudwatch_log_group" "sigv4_proxy" {
  name              = "/ecs/${var.service_name}/sigv4-proxy"
  retention_in_days = 30
}

# --- IAM: Task Execution Role (pull images, read secrets, write logs) ---
# Tạo trust policy: ai được sử dụng role?
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#  Tạo execution role và gắn trust policy
resource "aws_iam_role" "task_execution" {
  name               = "${var.service_name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

# Gắn policy có sẵn vào role
# ECS agent các quyền cơ bản cần thiết để quản lý và chuẩn bị cho Task chạy.
# - Đẩy Log: Cho phép ghi log của container lên CloudWatch (thông qua các hành động logs:CreateLogStream và logs:PutLogEvents).
# - Kéo Image: Cho phép gọi sang Amazon ECR (ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer) để tải các Docker image về chạy.
#  - Đọc Secrets/Parameters: Cho phép đọc các giá trị bảo mật từ AWS Secrets Manager hoặc AWS Systems Manager (SSM) Parameter Store 
#             (nếu bạn dùng tính năng secrets hoặc environment trỏ vào Secrets Manager/Parameter Store như trong cấu hình Task Definition của bạn).
resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Tạo và gán 1 policy tùy chình cho ứng dụng (task execution role) để đọc secret từ Secrets Manager (chromeleon access key) và đọc config từ S3 (vector.yaml).
# bỏ qqua và đưa vào task role
# data "aws_iam_policy_document" "task_execution_extra" {
#   statement {
#     sid       = "ReadChromeleonAccessKey"
#     actions   = ["secretsmanager:GetSecretValue"]
#     resources = [var.access_key_secret_arn]
#   }
# }

# resource "aws_iam_role_policy" "task_execution_extra" {
#   name   = "read-secrets"
#   role   = aws_iam_role.task_execution.id
#   policy = data.aws_iam_policy_document.task_execution_extra.json
# }

# --- IAM: Task Role (AMP remote-write, S3 config read) ---

resource "aws_iam_role" "task" {
  name               = "${var.service_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

# Dựng policy cho task role
data "aws_iam_policy_document" "task" {
  statement {
    sid = "AMPRemoteWrite"
    actions = [
      "aps:RemoteWrite",       # Gửi metrics vào AMP
      "aps:GetSeries",         # Đọc thông tin các time series
      "aps:GetLabels",         #  Đọc tên/giá trị label
      "aps:GetMetricMetadata", # ọc metadata của metrics
    ]
    # Giới hạn các quyền trên vào AMP workspace có ARN được truyền từ core
    resources = [var.amp_workspace_arn]
    # Vector tạo metrics
    #   → gửi request tới SigV4 proxy
    #   → proxy dùng credentials của task role để ký request
    #   → AMP kiểm tra quyền aps:RemoteWrite
    #   → tiếp nhận metrics
  }

  statement {
    sid       = "S3ReadConfig"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.config_bucket_name}/*", "arn:aws:s3:::${var.config_bucket_name}"]
  }
  statement {
    sid       = "ReadAccessKey"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.access_key_secret_arn]
  }
}


resource "aws_iam_role_policy" "task" {
  name   = "task-permissions"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

# --- Security Groups ---
# Firehose → NLB:443 → ECS task / Vector:8888


resource "aws_security_group" "nlb" {
  name        = "${var.service_name}-nlb"
  description = "Security group for the log collector NLB"
  vpc_id      = var.vpc_id
}

# Cho phép mọi địa chỉ IPv4 kết nối TCP tới cổng 443 của NLB
# SG chỉ cho phép TCP 443; việc xử lý TLS/HTTPS do listener của NLB cấu hình ở phần sau.
resource "aws_vpc_security_group_ingress_rule" "nlb_https" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Cho phép NLB gửi traffic ra mọi địa chỉ IPv4, với mọi giao thức và cổng, bao gồm chuyển tiếp tới Vector và kiểm tra health check.
resource "aws_vpc_security_group_egress_rule" "nlb_all" {
  security_group_id = aws_security_group.nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "task" {
  name        = "${var.service_name}-task"
  description = "Security group for the log collector ECS task"
  vpc_id      = var.vpc_id
}

#  Cho phép task nhận TCP cổng 8888 từ NLB mang SG được tham chiếu.
resource "aws_vpc_security_group_ingress_rule" "task_from_nlb" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.nlb.id # SG nguồn được phép — phía NLB.
  from_port                    = 8888
  to_port                      = 8888
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "task_all" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- TLS: Self-signed certificate for NLB (Firehose requires HTTPS) ---
#  tạo khóa riêng, tạo chứng chỉ TLS tự ký, rồi import vào AWS Certificate Manager (ACM) để NLB sử dụng cho kết nối HTTPS.
#  Tạo private key → Tạo certificate tự ký → Import ACM → Gắn vào listener NLB

resource "tls_private_key" "nlb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "nlb" {
  private_key_pem = tls_private_key.nlb.private_key_pem

  subject {
    common_name  = "${var.service_name}.internal"
    organization = "TRONGPQ"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",  #  Cho phép sử dụng khóa để mã hóa vật liệu khóa trong cơ chế trao đổi khóa phù hợp
    "digital_signature", # Cho phép ký số, phục vụ xác thực trong TLS
    "server_auth",       # Chứng chỉ dùng để xác thực phía server
  ]
}

# import chứng chỉ vào ACM để NLB sử dụng cho HTTPS
resource "aws_acm_certificate" "nlb" {
  private_key      = tls_private_key.nlb.private_key_pem
  certificate_body = tls_self_signed_cert.nlb.cert_pem
}

# --- NLB (internet-facing) ---

# Tạo Network Load Balancer
resource "aws_lb" "this" {
  name               = var.service_name
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  tags = {
    "cov:internet-facing" = "true"
  }
}

# Cấu hình target group đích nhận traffic
# Sau khi NLB nhận request ở cổng 443 và giải mã xong, nó sẽ chuyển tiếp (forward) gói tin thô qua giao thức TCP tới cổng 8888 
# của các container bên trong. (Đây chính là cổng mà container lắng nghe).
#  Firehose
#      │ HTTPS:443
#      ▼
#   NLB — kết thúc TLS
#      │ HTTP:8888
#      ▼
#   Vector — xác thực access key, chuyển log thành metrics
#      │ HTTP localhost:8005
#      ▼
#   SigV4 proxy — ký request bằng AWS credentials của task role
#      │ HTTPS:443
#      ▼
#     AMP
resource "aws_lb_target_group" "this" {
  name        = var.service_name
  port        = 8888
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip" # cho phép NLB định tuyến thẳng traffic đến IP của từng Task (Container) thay vì định tuyến qua EC2 instance.

  health_check {
    protocol = "TCP"
    port     = "8888"
  }
}

# Nơi gắn Chứng chỉ và xử lý HTTPS/TLS
resource "aws_lb_listener" "tls" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # Cấu hình các chuẩn mã hóa (cipher suites) hiện đại, ưu tiên TLS 1.3 và 1.2 để chặn các lỗ hổng bảo mật cũ.
  certificate_arn   = aws_acm_certificate.nlb.arn           # Khi client/firehose gửi request đến cổng 443, NLB sẽ lôi cái chứng chỉ tự ký (tls_self_signed_cert) từ ACM ra để bắt tay mã hóa.

  # Sau khi bắt tay TLS thành công và giải mã xong lớp vỏ bảo mật ở cổng 443, NLB sẽ chuyển dữ liệu sang Target Group đã định nghĩa ở trên (port 8888).
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# --- S3: Vector config ---
# upload cấu hình Vector lên S3, để container tải về khi khởi động. Cấu hình Vector được render từ core/deployment/modules/storage/main.tf 
# và truyền vào module này qua biến vector_config_files.
resource "aws_s3_object" "vector_config" {
  for_each = var.vector_config_files

  bucket       = var.config_bucket_name
  key          = "${var.config_prefix}/${each.key}"
  content      = each.value
  content_type = "application/yaml"
  etag         = md5(each.value)
}

# Cấu hình ECS cluster, service, task definition, và các container Vector + SigV4 proxy được triển khai trong phần tiếp theo.

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name # tên nhóm cho Task Definition
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Mỗi Task sẽ được cấp một IP riêng trong VPC, giúp các container bên trong gọi qua lại qua localhost và dễ dàng gắn Security Group riêng.
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "vector"
      image     = "timberio/vector:${var.vector_image_tag}" # Kéo image chính thức của Vector từ Docker Hub theo tag bạn chỉ định.
      essential = true
      portMappings = [{
        containerPort = 8888
        protocol      = "tcp"
      }]
      # Syncs the whole config_prefix down and launches Vector with
      # --config-dir so it merges every uploaded file (base.yaml + one per
      # tenant) into one runtime topology.
      entryPoint = ["sh", "-c"]
      command = [
        "apt-get update -qq && apt-get install -y -qq awscli > /dev/null 2>&1 && mkdir -p /tmp/vector-config && aws s3 sync s3://${var.config_bucket_name}/${var.config_prefix}/ /tmp/vector-config/ && vector --config-dir /tmp/vector-config/" #  Cập nhật hệ thống => cài nhanh AWS CLI => tải file vector.yaml mà chúng ta đã đẩy lên S3 ở bước trước về thư mục tạm /tmp/vector.yaml => khởi động Vector với file cấu hình đó.
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.vector.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      } # Đẩy toàn bộ log hoạt động của riêng container Vector vào đúng cái CloudWatch Log Group aws_cloudwatch_log_group.vector đã tạo trước đó.
    },
    {
      # Vector của bạn không cần tự viết code phức tạp để ký, mà chỉ cần gửi request dạng HTTP thông thường tới localhost:8005 của container sigv4-proxy. 
      # Proxy này sẽ tự động nhận request, gắn chữ ký SigV4 hợp lệ của AWS vào, rồi chuyển tiếp lên endpoint chính thức của Prometheus (aps-workspaces...amazonaws.com)  
      name      = "sigv4-proxy"
      image     = "public.ecr.aws/aws-observability/aws-sigv4-proxy:latest" # Lấy từ kho chính thức của AWS trên Amazon ECR Public
      essential = true
      portMappings = [{
        containerPort = 8005
        protocol      = "tcp"
      }]
      command = [
        "--name", "aps",
        "--region", data.aws_region.current.region,
        "--host", "aps-workspaces.${data.aws_region.current.region}.amazonaws.com",
        "--port", ":8005",
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.sigv4_proxy.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
  ])
}


# --- ECS Service ---
# AWS ECS Service – người quản lý và điều phối trực tiếp các Task (Container) đang chạy trong hệ thống của bạn.

#  - ECS Service sẽ đảm bảo rằng luôn có đúng số lượng Task mà bạn mong muốn (desired_count) đang chạy.
#  Nếu một Task bị lỗi hoặc bị dừng, ECS Service sẽ tự động khởi tạo một Task mới để thay thế.
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  # Hashes the *combined* content of every tenant/base file (sorted keys
  # for determinism) -- a change to any single file redeploys the whole
  # shared task, since there's only one Vector process merging all of
  # them. There's no smaller redeploy unit than "the whole fleet" with
  # this design; see the POC's blast-radius test for what that implies.
  #
  # force_new_deployment is required for `triggers` to actually force a
  # fresh task launch -- without it, AWS provider stores triggers but does
  # not act on a change (confirmed empirically: state showed triggers={}
  # even after the value changed, and the S3 content update alone did not
  # cause ECS to pull it, since the container only syncs from S3 at boot).

  force_new_deployment = true
  triggers = {
    config_hash = md5(join("", [for k in sort(keys(var.vector_config_files)) : var.vector_config_files[k]]))
  }
  # Khối triggers dùng mã băm MD5 của nội dung config làm chìa khóa. Nếu bạn sửa đổi file cấu hình vector.yaml, 
  # mã MD5 thay đổi => Terraform phát hiện sự khác biệt => Nó sẽ tự động ép ECS Service tạo mới lại task (rolling update) 
  # để container Vector khởi động lại và tải ngay file cấu hình mới nhất từ S3 về!

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }
  # Nó ra lệnh cho ECS Service: “Hãy lấy traffic từ cái Target Group của NLB chuyển vào... và định tuyến thẳng đến container có tên là vector tại cổng 8888”.
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "vector"
    container_port   = 8888
  }

  depends_on = [aws_s3_object.vector_config, aws_lb_listener.tls]
  # Đảm bảo rằng Terraform sẽ không dựng ECS Service lên trước khi:
  # File cấu hình vector.yaml đã được đẩy lên S3 (aws_s3_object.vector_config).
  # Cổng lắng nghe TLS của NLB đã sẵn sàng (aws_lb_listener.tls).
}
