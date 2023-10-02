# Get-AzVmWithDefaultOutbound

This script detects the VMs and VMSSs which uses the default outbound access in your subscription.

This script checks your VMs which doesn't match any of the following condition.

1. Your VM uses a public IP address
1. Your VM runs on the subnet which NAT Gateway relates with
1. Your VM runs on the subnet which related with the route table which has the route(0.0.0.0/0 -> VirtualAppliance)
1. Your VM is the backend of public load balancer which uses an outbound rule.

This script checks your VMSSs which doesn't match any of the following condition.

1. Your VM runs on the subnet which NAT Gateway relates with
1. Your VM runs on the subnet which related with the route table which has the route(0.0.0.0/0 -> VirtualAppliance)
1. Your VM is the backend of public load balancer which uses an outbound rule.

INFO: This script doesn't run correctly in the environment which uses force tunneling.

# Disclaimer
- This is a sample script, and do not represent the views or opinions of your organization.
- I will endeavor to create aan accurate information based on publicly available information, but we do not guarantee the completeness, accuracy, usefulness, safety, or recency of the content.
