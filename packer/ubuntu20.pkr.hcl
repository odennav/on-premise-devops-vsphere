local "vcenter_username" {
    expression = vault("/secrets/data/vmware", "username")
    sensitive = true
}

local "vcenter_password" {
    expression = vault("/secrets/data/vmware", "password")
    sensitive = true
}

local "vcenter_server" {
    expression = vault("/secrets/data/vmware", "server")
    sensitive = true
}

local "vcenter_cluster" {
    expression = vault("/secrets/data/vmware", "cluster")
    sensitive = true
}

local "vcenter_datacenter" {
    expression = vault("/secrets/data/vmware", "datacenter")
    sensitive = true
}

local "esx_datastore" {
    expression = vault("/secrets/data/vmware", "esx_datastore")
    sensitive = true
}

local "esx_host" {
    expression = vault("/secrets/data/vmware", "esx_host")
    sensitive = true
}

locals {
    buildtime = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
}

source "vsphere-iso" "ubuntu20" {
    vcenter_server = local.vcenter_server
    username = local.vcenter_username
    password = local.vcenter_password
    cluster = local.vcenter_cluster
    datacenter = local.vcenter_datacenter
    datastore = local.esx_datastore
    host = local.esx_host
    folder ="Templates"
    insecure_connection = "true"

    remove_cdrom = true
    convert_to_template = true
    guest_os_type = "ubuntu64Guest"
    notes = "Built By Packer on ${local.buildtime}"

    vm_name = "packer_ubuntu20"
    CPUs = "4"
    RAM = "8192"
    disk_controller_type = ["pvscsi"]
    firmware = "bios"

    storage {
        disk_size = "40960"
        disk_thin_provisioned = true
    }

    network_adapters {
        network = "VM Network"
        network_card = "vmxnet3"
    }

    iso_paths = [
        "[${local.esx_datastore}] ISO/ubuntu-20.04.3-live-server-amd64.iso"
    ]
    iso_checksum = "none"

    boot_order = "disk,cdrom"
    boot_wait = "4s"
    boot_command = [
        "<esc><esc><esc>",
        "<enter><wait>",
        "/casper/vmlinuz ",
        "root=/dev/sr0 ",
        "initrd=/casper/initrd ",
        "autoinstall ",
        "ds=nocloud-net;s=http://192.168.*.*:8600/",
        "<enter>"
    ]
    ip_wait_timeout = "20m"
    ssh_password = "ubuntu"
    ssh_username = "ubuntu"
    ssh_timeout = "20m"
    ssh_handshake_attempts = "100"
    communicator = "ssh"

    shutdown_command = "sudo -S -E shutdown -P now"
    shutdown_timeout = "15m"

    http_port_min = 8600
    http_port_max = 8600
    http_directory = "./artifacts"
}

build {
    sources = ["source.vsphere-iso.ubuntu20"]

    provisioner "shell" {
        inline = [
            "echo Running updates",
            "sudo apt-get update",
            "sudo apt-get -y install open-vm-tools",
            "sudo touch /etc/cloud/cloud-init.disabled", # Fixing issues with preboot DHCP
            "sudo apt-get -y purge cloud-init",
            "sudo sed -i \"s/D /tmp 1777/#D /tmp 1777/\" /usr/lib/tmpfiles.d/tmp.conf",
            "sudo sed -i \"s/After=/After=dbus.service /\" /lib/systemd/system/open-vm-tools.service",
            "sudo rm -rf /etc/machine-id", # next four lines fix same ip address being assigned in vmware
            "sudo rm -rf /var/lib/dbus/machine-id",
            "sudo touch /etc/machine-id",
            "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id"
        ]
    }
}
