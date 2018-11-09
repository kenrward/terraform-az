resource "azurerm_resource_group" "az_testnet" {
    name      = "az_testnet"
    location  = "usgovvirginia"
  
}

resource "azurerm_virtual_network" "az_testnet" {
  name = "az_testnet"
  address_space       = [ "11.0.0.0/16" ]
  location            = "${azurerm_resource_group.az_testnet.location}"
  resource_group_name = "${azurerm_resource_group.az_testnet.name}"
}



# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "mySubnet"
  resource_group_name  = "${azurerm_resource_group.az_testnet.name}"
  virtual_network_name = "${azurerm_virtual_network.az_testnet.name}"
  address_prefix       = "11.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                         = "myPublicIP"
  location                     = "${azurerm_resource_group.az_testnet.location}"
  resource_group_name          = "${azurerm_resource_group.az_testnet.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "Terraform Demo"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "myNetworkSecurityGroup"
  location            = "${azurerm_resource_group.az_testnet.location}"
  resource_group_name = "${azurerm_resource_group.az_testnet.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Terraform Demo"
  }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                      = "myNIC"
  location                  = "${azurerm_resource_group.az_testnet.location}"
  resource_group_name       = "${azurerm_resource_group.az_testnet.name}"
  network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
  }

  tags {
    environment = "Terraform Demo"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.az_testnet.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                        = "diag${random_id.randomId.hex}"
  resource_group_name         = "${azurerm_resource_group.az_testnet.name}"
  location                    = "${azurerm_resource_group.az_testnet.location}"
  account_tier                = "Standard"
  account_replication_type    = "LRS"

  tags {
    environment = "Terraform Demo"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
  name                  = "myVM"
  location              = "${azurerm_resource_group.az_testnet.location}"
  resource_group_name   = "${azurerm_resource_group.az_testnet.name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myvm"
    admin_username = "kewar"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/kewar/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkVBvPrYW/CbDW2vpFOueL711Lu3Wj68OuQGUJx5IgJerhh4PJdCcK0pGHExPa8pmSprUJWz3Ak9uDe7U6Bxoz3yeqZ16Zpcc5sst5NS6TWu00dJVVnI7hMVZn7MQhvmHEMIwuf1/SXRh4pjN67dXDb/6m7FeXPd+qyBTdCogM4GV4J6zmPf7NmgH57tUHNLdusWRBOIWout/OUwKpvRmFP+uFVNc9YoklZj6054UY8LlUE6T7b4sa98q/JBuT+5XyqtJ6BNezweaNgpRVtkp9lCuxfo3MMtO+hk+Bwh0PT2s16Q7MzjfOkffm9wx1QheijG2fQCpseoUd2Ym+GIEJ"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }

  tags {
    environment = "Terraform Demo"
  }
}