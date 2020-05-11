provider "aws" {
  region      = "${var.aws_region}"
  access_key  = "${var.aws_access_key}"
  secret_key  = "${var.aws_secret_key}"
}

resource "aws_instance" "alation-webservers" {
  count           = "${var.number_of_webservers}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type   = "t2.micro"
  key_name        = "${aws_key_pair.aws_key.key_name}"
  security_groups = ["${aws_security_group.alation-web-sg.name}"]

  connection {
    user        = "ubuntu"
    private_key = file("${var.private_key_path}")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${var.private_key_path}"
    destination = "/home/ubuntu/key.pem"
  }

  provisioner "file" {
    content     = "HelloWorld from webserver - ${count.index}"
    destination = "/home/ubuntu/index.html"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get -y install docker-ce docker-ce-cli containerd.io",
      "sudo docker run -d -p 8080:80 -v /home/ubuntu/index.html:/usr/share/nginx/html/index.html nginx"
    ]
  }

  tags = { 
    Name = "alation-webserver-${count.index}"
  }
}

resource "aws_instance" "alation-lb" {
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type   = "t2.micro"
  key_name        = "${aws_key_pair.aws_key.key_name}"
  security_groups = ["${aws_security_group.alation-lb-sg.name}"]

  connection {
    user        = "ubuntu"
    private_key = file("${var.private_key_path}")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${var.private_key_path}"
    destination = "/home/ubuntu/key.pem"
  }

  provisioner "file" {
    content = templatefile("../loadbal/haproxy.cfg.tpl", {balance = "${var.haproxy_balance}", port = 8080, ips = list("${aws_instance.alation-webservers.*.public_ip}")})
    destination = "/home/ubuntu/haproxy.cfg"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get -y install docker-ce docker-ce-cli containerd.io",
      "sudo docker run -d -p 80:80 -v /home/ubuntu/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg haproxy"
    ]
  }

  tags = { 
    Name = "alation-lb"
  }
}

output "haproxy-ip" {
  value = "${aws_instance.alation-lb.public_ip}"
}


