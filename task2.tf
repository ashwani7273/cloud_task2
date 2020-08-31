provider "aws" {
  region = "ap-south-1"
  profile = "ashwani"
}
resource "aws_security_group" "my_firewall" {
  name        = "my_firewall"
  description = "My Customised Security Group"
  ingress {
    description = "SSH "
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP Protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my_firewall"
  }
}
resource "tls_private_key" "task_keypair" {
  algorithm   = "RSA"
  
}
output "ssh_key" {
    value = tls_private_key.task_keypair.public_key_openssh
}

output "pem_key" {
     value = tls_private_key.task_keypair.public_key_pem
}

resource "aws_key_pair" "task_keypair"{
      key_name = "task_keypair"
      public_key = tls_private_key.task_keypair.public_key_openssh
}

resource "aws_s3_bucket" "task2bucket1" {
  bucket = "task2bucket1"
  acl    = "public-read"
  versioning {
    enabled = true
  }
  tags = {
    Name        = "task2bucket1"
    Environment = "Personal"
  }
}

resource "null_resource" "local-me"  {
	depends_on = [aws_s3_bucket.task2bucket1,]
	provisioner "local-exec" {
		command = "git clone https://github.com/ashwani7273/cloud_task1.git"
  	}
}



resource "aws_s3_bucket_object" "file_upload1" {
	depends_on = [aws_s3_bucket.task2bucket1 , null_resource.local-me]
	bucket = aws_s3_bucket.task2bucket1.id
    key = "aws.png"    
	  source = "E:/NIIT & SPI & LW/Hybrid Multi Cloud/Task 2/aws.png"
    acl = "public-read"
}

output "Image" {
  value = aws_s3_bucket_object.file_upload1
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [aws_s3_bucket.task2bucket1,null_resource.local-me]
          enabled = true
          is_ipv6_enabled = true

   origin {
    domain_name = "${aws_s3_bucket.task2bucket1.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.task2bucket1.id}"
     }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.task2bucket1.id}"
   
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

  viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_instance" "task_os" {
     ami = "ami-0447a12f28fddb066"
     instance_type = "t2.micro"
     availability_zone = "ap-south-1a"
     key_name = aws_key_pair.task_keypair.key_name
     security_groups = ["${aws_security_group.my_firewall.tags.Name}"]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_keypair.private_key_pem
    host     = aws_instance.task_os.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo yum install  git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
     
 
     tags = {
              Name= "task_os" 
            }
}




resource "aws_efs_file_system" "task2-nfs"{
  depends_on = [aws_security_group.my_firewall , aws_instance.task_os , ]
  creation_token = "task2-nfs"

  tags = {
    Name = "task2-nfs"
  }
}


resource "aws_efs_mount_target" "alpha" { 
  depends_on = [aws_efs_file_system.task2-nfs,]
  file_system_id = aws_efs_file_system.task2-nfs.id
  subnet_id      = aws_instance.task_os.subnet_id
  security_groups = ["${aws_security_group.my_firewall.id}"]
}

  output "myos_ip" {
    value = aws_instance.task_os.public_ip
}

resource "null_resource" "os_ip" {
  provisioner "local-exec" {
   command = "echo  ${aws_instance.task_os.public_ip} > publicip.txt"
  	}
}
