# Latest Amazon Linux 2023 image published by Amazon.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] # excludes the "minimal" variant
  }
}

# One web server in each public subnet (so one per AZ).
resource "aws_instance" "web" {
  count = length(aws_subnet.public)

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>pragya-s19 web-${count.index + 1} in ${var.azs[count.index]}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  tags = { Name = "${var.project}-web-${count.index + 1}" }
}

# A backend instance in the first private subnet. It gets no public IP
# because that subnet has map_public_ip_on_launch = false (the default).
# I first also set associate_public_ip_address = false here: redundant, and on
# LocalStack it made the provider pass the SG inside a network-interface spec,
# which LocalStack does not report back -> a permanent diff (see README).
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = { Name = "${var.project}-app-1" }
}
