output "vswitch_id" {
  description = "The ID of the VPC"
  value       = "${element(concat(alicloud_vswitch.private.*.id, list("")), 0)}"
}