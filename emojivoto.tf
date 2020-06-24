terraform {

  backend "remote" {
    organization = "Smallstep"

    workspaces {
      name = "step-aws-emojivoto"
    }
  }
}

# Define the provider that we are going to use
provider "aws" {
  region = "us-east-1"
}

# Create an SSH key pair to connect to our instances
resource "aws_key_pair" "terraform" {
  key_name   = "terraform-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCneX75UCGIDI2jibfaRAJGTEkT6K8DkbM1Z1n7GDOu0xexcUN8HHmyns90pEbNmR7PDjxyxfCHm7PCRRSDTJLuNcALqwN9sWiwqOoua/bKuvwMGMv+0hIJbSC9VhlZgRP6vQehhEGK+wgoouDwXiXizfvVPzKyrgbNm799Z9UoZEPMQOxOrxQp5tTtlhlUjlHsRbVlQaM025HvifxdZIEj/CtJ6dslS8Go2Joma3GIJZskCX/3K0vomOmWTq4n6MSqvGeL+rn7XgcKvs78AZGEtHhEU+3yIIz94e0mK0jC2ADyOlsVotN56RrXWf/OL5cyLvnxJZAOfvPuXLBCTudB unitrininc\\usgbxc@KPIJAX81787"
}

variable "key_name" {
  type    = string
  default = "terraform-key"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

output "puppet_ip" {
  value = aws_instance.puppet.public_ip
}

output "ca_ip" {
  value = aws_instance.ca.public_ip
}

output "web_ip" {
  value = aws_instance.web.public_ip
}

output "emoji_ip" {
  value = aws_instance.emoji.public_ip
}

output "voting_ip" {
  value = aws_instance.voting.public_ip
}
