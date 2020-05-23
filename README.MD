# Repeatable Infrastructure on GCP

This example demonstrates you could provision Immutable Infrastructure with encapsulation - *“Automating the process of provisioning, configuring, deploying, and tearing down cloud infrastructure and services.”*

This could be expended as required, I have tried to keep this example as simple as possible while trying to follow all the best practices.

## Getting Started

What we are trying to achieve is repeatable Infrasture and provisioning of environment, since terraform does not have a plug-in for ansible yet, we will use local-exec and remote-exec to configure our environment.

This guide will showcase how best to use terraform and ansible together with a dynamic inventory.

![](https://i.imgur.com/n1C4XSj.png)
Inspiration was taken from [here](https://medium.com/faun/building-repeatable-infrastructure-with-terraform-and-ansible-on-aws-3f082cd398ad).


### Prerequisites

You must have terraform and ansible binary in the local system, I am using Terraform v0.12.24 and ansible 2.9.1.

once you have those you must execute
```
terraform init
```
This would provide the local environment with terraform modules required.

### Terraform

**Question:** How is encapsulation done?
```
resource "random_id" "instance_id" {
  byte_length = 8
}
```
This module is responsible for generating random ID, which will be associated with every infrastructure object, hence providing encapsulation.
For example name of the instance:
```
resource "google_compute_network" "vpc_network" {
  name         = "demo-automation-${random_id.instance_id.hex}"
  routing_mode = "GLOBAL"
}
```


**Question:** How is ansible-playbook executed?
For execution of ansible script; this is the snippet responsible:
```
  provisioner "local-exec" {
    command = <<EOT
      sleep 30;
    >inventory.ini;
    echo "[java]" | tee -a inventory.ini;
    echo "${google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip} ansible_user=murtaza ansible_ssh_private_key_file=_SSH_PUBLIC_KEY_" | tee -a inventory.ini;
      export ANSIBLE_HOST_KEY_CHECKING=False;
    ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ -i ./inventory.ini ./ansible/playbooks/install_*.yaml
    EOT
  }
```
although it requires the the new virtual machine must have dependencies resolved beforehand. below is the snippet for this:
```
  provisioner "remote-exec" {
    inline = ["sudo apt-get -qq install python python-apt -y"]
    connection {
          type        = "ssh"
          host          = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
          user        = "murtaza"
          private_key = file("_SSH_PUBLIC_KEY_")
        }
  }
```

## Running the tests

```
Line 4: credentials = file("_GCP_SERVICE_ACCOUNT_CREDENTIAL_FILE_.json")
```
you need to create a service account in GCP and provide the JSON file here

```
Line 6: project     = "_PROJECT_ID_"
```
Project ID needs to be updated here.

```
Line 60: ssh-keys = "murtaza:${file("_SSH_PUBLIC_KEY_")}"
Line 84: private_key = file("_SSH_PUBLIC_KEY_")
Line 93: ...ansible_ssh_private_key_file=_SSH_PUBLIC_KEY_"...
Line 95: ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ ...
Line 104: ...ansible_ssh_private_key_file=_SSH_PUBLIC_KEY_"...
Line 106: ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ ...
```
also, update the _SSH_PUBLIC_KEY_ and user name.

### Terraform execution and verification

once the fields are populated correctly, you can execute the following commands:
provision infrastructure
```
terraform apply
```
if you wish to tear-down the said environment execute:
```
terraform destroy
```
you can also execute a validate command to verify the syntax.
```
terraform validate
```
or when you don't have backend cloud, you could execute the below command to mock it:
```
terraform init -backend=false
```
something thing which I use often fix the indentation problem in  terraform file is:
```
terraform fmt 
```

### executing ansible for standalone,

if for some reason you need to just execute ansible-playbook again after the first iteration and you don't wish to provision the whole infrastructure again, use the below snippet but update the ssh key and user name.

```
ansible-playbook -u murtaza --private-key _SSH_PUBLIC_KEY_ -i ./inventory.ini ./ansible/playbooks/install_8.yaml
```
assuming inventory file is still available.

## Built With

* [Terraform](https://www.terraform.io/) - IaC
* [Ansible](https://www.ansible.com/) - CM

## Authors

* **Qazi Murtaza** - *Initial work* - [kazimurtaza](https://github.com/kazimurtaza)


## License

This project is licensed under the MIT License.

## Acknowledgments

* [ernesen](https://github.com/ernesen) for publishing this [idea](https://medium.com/faun/building-repeatable-infrastructure-with-terraform-and-ansible-on-aws-3f082cd398ad).

