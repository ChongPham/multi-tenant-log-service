vpc_id            = "TODO"
public_subnet_ids = ["TODO"]
# TODO: Provide existing private subnets in this VPC, in AZs enabled on the NLB.
# Their route tables must provide NAT egress for the current ECS images/startup.
private_subnet_ids = ["TODO"]

core_state_bucket = "trongpq-tfstate-prod-174772361218-eu-central-1"

cluster_name = "trongpq-collectors-prod"

chromeleon_service_name = "chromeleon-collector-prod"
