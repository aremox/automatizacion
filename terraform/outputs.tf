output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "vm_id" {
  value = "${azurerm_linux_virtual_machine.vm.*.id}"
}

output "pub_ip" {
  value = "${azurerm_public_ip.publicip.*.ip_address}"
}

output "ip_lb" {
  value = "${azurerm_public_ip.iplb.*.ip_address}"
}