variable "aws_region" {
  description = "AWS region. The Learner Lab only allows us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used in tags and resource names."
  type        = string
  default     = "production"
}

variable "cluster_version" {
  description = <<-TXT
    Kubernetes version on EKS.

    1.34, not 1.31: versions 1.31 through 1.33 entered extended support, which
    AWS bills at USD 0.60 per hour against USD 0.10 for standard support. Six
    times the price for the same cluster.
    Check with: aws eks describe-cluster-versions
  TXT
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = <<-TXT
    Instance type for the node group.

    t3.large, not t3.medium. The first limit reached was not memory but the pod
    ceiling per node, which comes from the instance type's ENI count:

      t3.medium   3 ENIs x  6 IPs  ->  17 pods,  4 GiB
      t3.large    3 ENIs x 12 IPs  ->  35 pods,  8 GiB

    With two t3.medium the cluster had 34 slots and infrastructure alone took
    25, leaving loki-0 and one promtail Pending for lack of a slot, not of
    resources.

    Two t3.large solve it without enabling CNI prefix delegation, which would be
    one more adjustment to maintain. Five of the pods are DaemonSets, one per
    node, so a larger node also means fewer pods in total.
  TXT
  type        = string
  default     = "t3.large"
}

variable "node_desired_size" {
  description = "Number of nodes in steady state."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum nodes. Two, to tolerate losing one without taking observability down."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes, with headroom for the application HPA to scale."
  type        = number
  default     = 4
}

variable "cluster_public_access_cidrs" {
  description = <<-TXT
    Sources allowed to reach the control plane's public endpoint.

    Broad by default because the CD runs on a GitHub-hosted runner, whose IP
    range changes and does not fit the EKS CIDR limit. Narrowing this is how to
    close it once there is a runner with a fixed IP.
  TXT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_gateway_routes" {
  description = <<-TXT
    Creates the NLB integration, the gateway routes and the integration with
    the authentication function.

    Set to `false` only during the first phase of a from-scratch provision: the
    NLB comes from the application Service and the function ARN comes from the
    functions repository's remote state, and neither exists before this cluster.
    Never use `false` on an environment that already has the routes: the apply
    destroys them.
  TXT
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "Origins allowed by the gateway CORS configuration."
  type        = list(string)
  default     = ["*"]
}

variable "throttling_rate_limit" {
  description = "Requests per second in steady state. Sized for the two-node cluster."
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Instantaneous burst tolerated above the steady rate."
  type        = number
  default     = 200
}

variable "public_routes" {
  description = <<-TXT
    Routes the gateway forwards to the cluster.

    An explicit list rather than a wildcard: anything absent answers 404 without
    reaching the application. Every externally reachable route is a written
    decision, not the side effect of a wildcard.

    Each prefix appears twice on purpose: "/customers" matches the collection
    and "/customers/{proxy+}" matches the items under it. One form does not
    cover the other.

    Deliberately out of the list:
      /auth/customers/lookup  has its own route and throttling in
                              api-gateway-lookup-route.tf
      /metrics                scraped by Prometheus from inside the cluster
  TXT
  type        = list(string)

  default = [
    "POST /auth/login",
    "POST /auth/register",

    "ANY /customers",
    "ANY /customers/{proxy+}",
    "ANY /vehicles",
    "ANY /vehicles/{proxy+}",
    "ANY /services",
    "ANY /services/{proxy+}",
    "ANY /items",
    "ANY /items/{proxy+}",
    "ANY /service-orders",
    "ANY /service-orders/{proxy+}",

    # API documentation.
    "GET /docs",
    "GET /docs/{proxy+}",

    # Probes: useful to check the path from outside without depending on data.
    "GET /health",
    "GET /ready",
  ]
}

variable "lookup_throttling_rate_limit" {
  description = <<-TXT
    Requests-per-second ceiling on the internal lookup route.

    Five per second: the function makes one query per authentication, so even a
    spike of legitimate logins stays far below. The number exists in case the
    shared secret leaks, separating a single lookup from a sweep of CPFs.
  TXT
  type        = number
  default     = 5
}

variable "lookup_throttling_burst_limit" {
  description = "Burst tolerated on the internal lookup route."
  type        = number
  default     = 10
}
