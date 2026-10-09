vpc_id            = "vpc-0a5841a05e0126d14"
public_subnet_ids = ["subnet-045fa9b493a23b859"]
# TODO: Provide existing private subnets in this VPC, in AZs enabled on the NLB.
# Their route tables must provide NAT egress for the current ECS images/startup.
private_subnet_ids = ["subnet-00952fbea9c2eacf8"]

core_state_bucket = "trongpq-tfstate-qa-174772361218-eu-central-1-an"

cluster_name = "trongpq-collectors-qa"

log_collector_service_name = "log-collector-qa"
