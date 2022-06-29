resource "azurerm_resource_group" "rg" {
  name                  = var.resource_group_name
  location              = var.location_name
}

resource "azurerm_virtual_network" "vnet" {
  name                  = var.network_name
  address_space         = [ "10.0.0.0/16" ]
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                  = var.subnet_name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.vnet.name
  address_prefixes      = ["10.0.2.0/24"] 
}

resource "azurerm_network_interface" "nic" { 
  count                 = var.num_maquinas
  name                  = "vnic${count.index}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name


  ip_configuration {
    name                            = "internal${count.index}"
    subnet_id                       = azurerm_subnet.subnet.id
    private_ip_address_allocation   = "Dynamic" 
    public_ip_address_id            = azurerm_public_ip.publicip[count.index].id
  }   
}


resource "azurerm_linux_virtual_machine" "vm" {
  count                 = var.num_maquinas
  name                  = "vm${count.index}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1ls"
  zone                  = element(var.availability-zones, (count.index))
  admin_username        = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username                        = "azureuser"
    public_key                      = file("C:\\Users\\arena\\Documents\\Devops\\caso_practico\\Caso_practico_2\\id_rsa.pub")
  }

  os_disk {
    caching                         = "ReadWrite"
    storage_account_type            = "Standard_LRS"
  }

  source_image_reference {
    publisher                       = "Canonical"
    offer                           = "UbuntuServer"
    sku                             = "16.04-LTS"
    version                         = "latest"
  }

}

resource "azurerm_managed_disk" "data" {
  count                 = var.num_maquinas
  name                  = "data${count.index}"
  location              = azurerm_resource_group.rg.location
  create_option         = "Empty"
  disk_size_gb          = 1
  resource_group_name   = azurerm_resource_group.rg.name
  storage_account_type  = "Standard_LRS"
  zone                  = element(var.availability-zones, (count.index))
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
    count               = var.num_maquinas
    virtual_machine_id  = azurerm_linux_virtual_machine.vm[count.index].id
    managed_disk_id     = azurerm_managed_disk.data[count.index].id
    lun                 = 0
    caching             = "None" 
}

resource "azurerm_public_ip" "publicip" {
  count                 = var.num_maquinas
  name                  = "pubip${count.index}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  allocation_method     = "Static"
  sku                   = "Standard"
  sku_tier              = "Regional"
  zones                 = ["${element(var.availability-zones, (count.index))}"]
}

resource "azurerm_network_security_group" "firewall" {
  name                = "firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

  security_rule {
    name                       = "TCP80"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "redfirewall" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.firewall.id
}

resource "azurerm_public_ip" "iplb" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                   = "Standard"
  sku_tier              = "Regional"
}

resource "azurerm_lb" "lb" {
  name                  = "LoadBalancer"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  sku                   = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.iplb.id
  }
}

resource "azurerm_lb_backend_address_pool" "beaddpool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "lb" {
  count                 = var.num_maquinas
  network_interface_id  = azurerm_network_interface.nic[count.index].id
  ip_configuration_name = "internal${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.beaddpool.id
}

resource "azurerm_lb_probe" "lb" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "ssh-running-probe"
  protocol        = "Tcp"
  port            = 22
  interval_in_seconds = 5
  number_of_probes = 2
}

resource "azurerm_lb_rule" "lbrule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.beaddpool.id]
  probe_id                       = azurerm_lb_probe.lb.id
}

