
provider "google" {
  ### Insert credential file below
  credentials = file("_GCP_SERVICE_ACCOUNT_CREDENTIAL_FILE_.json")
  ### Insert Project id below
  project     = "_PROJECT_ID_"
  ### Update the region to be used
  region      = "australia-southeast1"
}
### random ID generator for encapsulating the environment
resource "random_id" "instance_id" {
  byte_length = 8
}

resource "google_compute_project_default_network_tier" "default" {
  network_tier = "STANDARD"
}

resource "google_compute_network" "vpc_network" {
  name         = "demo-automation-${random_id.instance_id.hex}"
  routing_mode = "GLOBAL"
}

resource "google_compute_firewall" "allow-https" {
  name    = "demo-automation-${random_id.instance_id.hex}-allow-https"
  network = "demo-automation-${random_id.instance_id.hex}"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  // Allow traffic from everywhere to instances with an http-server tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
  depends_on    = [google_compute_network.vpc_network]
}

resource "google_compute_firewall" "allow-bastion" {
  name    = "demo-automation-${random_id.instance_id.hex}-allow-bastion"
  network = "demo-automation-${random_id.instance_id.hex}"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  // Allow traffic from everywhere to instances with an ssh tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
  depends_on    = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "vm_instance" {
  name         = "demo-automation-${random_id.instance_id.hex}"
  machine_type = "n1-standard-2"
  zone         = "australia-southeast1-a"
  tags         = ["ssh", "https-server"]
  metadata = {
    ### Insert ssh public key here
    ssh-keys = "murtaza:${file("_SSH_PUBLIC_KEY_")}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
      size= 20
    }
  }
  metadata_startup_script = ""
  
  network_interface {
    network = "demo-automation-${random_id.instance_id.hex}"

    access_config {
    }
  }
  ### to be able to execute ansible playbooks on a new server, you need to resolve some dependecies.
  provisioner "remote-exec" {
    inline = ["sudo apt-get -qq install python python-apt -y"]
	connection {
	      type        = "ssh"
		  host		  = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
	      user        = "murtaza"
	      private_key = file("_SSH_PUBLIC_KEY_")
	    }
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 30;
    >inventory.ini;
    echo "[java]" | tee -a inventory.ini;
    echo "${google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip} ansible_user=murtaza ansible_ssh_private_key_file=_SSH_PUBLIC_KEY_" | tee -a inventory.ini;
      export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ -i ./inventory.ini ./ansible/playbooks/install_java.yaml
    EOT
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 30;
    >inventory.ini;
    echo "[docker]" | tee -a inventory.ini;
    echo "${google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip} ansible_user=murtaza ansible_ssh_private_key_file=_SSH_PUBLIC_KEY_" | tee -a inventory.ini;
      export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ -i ./inventory.ini ./ansible/playbooks/install_docker.yaml
    EOT
  }

  depends_on = [google_compute_network.vpc_network,
    google_compute_firewall.allow-bastion,
    google_compute_firewall.allow-https,
  ]
}
## pull current DNS zone in GCP Cloug DNS
data "google_dns_managed_zone" "demo-automation-zone" {
  name = "demo-automation-zone"
}

resource "google_dns_record_set" "demo-automation" {
  name = "demo-${random_id.instance_id.hex}.${data.google_dns_managed_zone.demo-automation-zone.dns_name}"
  type = "A"
  ttl  = 60

  managed_zone = data.google_dns_managed_zone.demo-automation.name

  rrdatas = [google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip]
}
output "ip" {
  value = "${google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip}"
}
output "demo-automation_dns_record" {
  description = "DS record of the demo-automation subdomain."
  value       = google_dns_record_set.demo-automation.name
}