data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"] # Canonical
}

resource "aws_instance" "puppet" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  depends_on = [
    aws_key_pair.terraform,
    aws_vpc.emojivoto,
    aws_subnet.emojivoto,
    aws_vpc_dhcp_options.emojivoto,
    aws_vpc_dhcp_options_association.emojivoto,
    aws_security_group.emojivoto,
    aws_internet_gateway.emojivoto,
    aws_route_table.emojivoto,
    aws_route_table_association.emojivoto,
  ]

  # VPC
  subnet_id              = aws_subnet.emojivoto.id
  vpc_security_group_ids = ["${aws_security_group.emojivoto.id}"]

  # Required to use remote-exec
  associate_public_ip_address = true

  # Set hostname using cloud-init
  user_data = "#cloud-config\nhostname: puppet\nfqdn: puppet.emojivoto.local"

  tags = {
    Name = "emojivoto-puppet"
  }

  # Install puppet-master
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }

    inline = [
      "set -x",
      # apt-get update fails often, sometimes writing the cache
      "sudo apt-get update || sudo apt-get update", "sudo apt-get update",
      "sudo apt-get -y install puppet-master puppet-module-puppetlabs-stdlib",
      "sudo puppet config set --section master autosign true",
      "sudo systemctl restart puppet-master",
      "sudo chown ubuntu:ubuntu /etc/puppet/code",
    ]
  }

  # Copy puppet/code folder to /etc/puppet/code
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }

    source      = "conf/puppet/code/environments"
    destination = "/etc/puppet/code"
  }
}

resource "aws_instance" "ca" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  depends_on = [
    aws_instance.puppet,
    aws_route53_record.puppet,
  ]

  # VPC
  subnet_id              = aws_subnet.emojivoto.id
  vpc_security_group_ids = ["${aws_security_group.emojivoto.id}"]

  # Required to use remote-exec
  associate_public_ip_address = true

  # Set hostname using cloud-init
  user_data = "#cloud-config\nhostname: ca\nfqdn: ca.emojivoto.local"

  tags = {
    Name = "emojivoto-ca"
  }

  # Provision with puppet
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.ca.public_ip
      private_key = file("terraform")
    }

    inline = [
      "set -x",
      # apt-get update fails often, sometimes writing the cache
      "sudo apt-get update || sudo apt-get update", "sudo apt-get update",
      "sudo apt-get -y install puppet",
      # Run once and daemonize, it will refresh every 30m
      "sudo puppet agent --server puppet.emojivoto.local --test",
      "sudo puppet agent --server puppet.emojivoto.local",
    ]
  }

  # Clean puppet certificate on destroy
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }
    inline = [
      "sudo rm /var/lib/puppet/ssl/ca/signed/ca.emojivoto.local.pem"
    ]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  depends_on = [
    aws_instance.ca,
    aws_instance.emoji,
    aws_instance.voting,
    aws_route53_record.ca,
    aws_route53_record.emoji,
    aws_route53_record.voting,
  ]

  # VPC
  subnet_id = aws_subnet.emojivoto.id
  vpc_security_group_ids = [
    "${aws_security_group.emojivoto.id}",
    "${aws_security_group.emojivoto_web.id}"
  ]

  # Required to use remote-exec
  associate_public_ip_address = true

  # Set hostname using cloud-init
  user_data = "#cloud-config\nhostname: web\nfqdn: web.emojivoto.local"

  tags = {
    Name = "emojivoto-web"
  }

  # Provision with puppet
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.web.public_ip
      private_key = file("terraform")
    }

    inline = [
      "set -x",
      # apt-get update fails often, sometimes writing the cache
      "sudo apt-get update || sudo apt-get update", "sudo apt-get update",
      "sudo apt-get -y install puppet",
      # Run once and daemonize, it will refresh every 30m
      "sudo puppet agent --server puppet.emojivoto.local --test",
      "sudo puppet agent --server puppet.emojivoto.local",
    ]
  }

  # Clean puppet certificate on destroy
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }
    inline = [
      "sudo rm /var/lib/puppet/ssl/ca/signed/web.emojivoto.local.pem"
    ]
  }
}

resource "aws_instance" "emoji" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  depends_on = [
    aws_instance.ca,
    aws_route53_record.ca,
  ]

  # VPC
  subnet_id              = aws_subnet.emojivoto.id
  vpc_security_group_ids = ["${aws_security_group.emojivoto.id}"]

  # Required to use remote-exec
  associate_public_ip_address = true

  # Set hostname using cloud-init
  user_data = "#cloud-config\nhostname: emoji\nfqdn: emoji.emojivoto.local"

  tags = {
    Name = "emojivoto-emoji"
  }

  # Provision with puppet
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.emoji.public_ip
      private_key = file("terraform")
    }

    inline = [
      "set -x",
      # apt-get update fails often, sometimes writing the cache
      "sudo apt-get update || sudo apt-get update", "sudo apt-get update",
      "sudo apt-get -y install puppet",
      # Run once and daemonize, it will refresh every 30m
      "sudo puppet agent --server puppet.emojivoto.local --test",
      "sudo puppet agent --server puppet.emojivoto.local",
    ]
  }

  # Clean puppet certificate on destroy
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }
    inline = [
      "sudo rm /var/lib/puppet/ssl/ca/signed/emoji.emojivoto.local.pem"
    ]
  }
}

resource "aws_instance" "voting" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  depends_on = [
    aws_instance.ca,
    aws_route53_record.ca,
  ]

  # VPC
  subnet_id              = aws_subnet.emojivoto.id
  vpc_security_group_ids = ["${aws_security_group.emojivoto.id}"]

  # Required to use remote-exec
  associate_public_ip_address = true

  # Set hostname using cloud-init
  user_data = "#cloud-config\nhostname: voting\nfqdn: voting.emojivoto.local"

  tags = {
    Name = "emojivoto-voting"
  }

  # Provision with puppet
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.voting.public_ip
      private_key = file("terraform")
    }

    inline = [
      "set -x",
      # apt-get update fails often, sometimes writing the cache
      "sudo apt-get update || sudo apt-get update", "sudo apt-get update",
      "sudo apt-get -y install puppet",
      # Run once and daemonize, it will refresh every 30m
      "sudo puppet agent --server puppet.emojivoto.local --test",
      "sudo puppet agent --server puppet.emojivoto.local",
    ]
  }

  # Clean puppet certificate on destroy
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.puppet.public_ip
      private_key = file("terraform")
    }
    inline = [
      "sudo rm /var/lib/puppet/ssl/ca/signed/voting.emojivoto.local.pem"
    ]
  }
}
