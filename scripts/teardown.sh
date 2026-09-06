#!/usr/bin/env bash
#
# Tears down the Kubernetes infrastructure provisioned by this repository.
#
#   ./scripts/teardown.sh                    terraform destroy + verification
#   ./scripts/teardown.sh --sweep            also remove what is left outside the state
#   ./scripts/teardown.sh --yes              no prompt (for workflow use)
#
# EKS is the most expensive resource here: the control plane costs USD
# 0.10/hour, about five times the database. Tearing it down between work
# sessions is what makes the lab budget last.
#
# Why --sweep exists: if the state is lost or drifts, `terraform destroy` does
# not find the resources but AWS keeps billing. On EKS that is worse than on
# RDS, because the node group outlives the cluster and keeps billing EC2.
#
# The application Service is deleted before the destroy, not after. It lives in
# the application repository and owns the NLB, which this Terraform does not
# know about, so destroying the cluster first leaves the balancer orphaned and
# billing. APP_MANIFESTS points at the manifests; adjust if the repository sits
# elsewhere.
set -uo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${CLUSTER_NAME:-car-repair-shop}"
APP_MANIFESTS="${APP_MANIFESTS:-$HOME/dev/fiap-tech-challenge/k8s}"

SWEEP=false; ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --sweep)   SWEEP=true ;;
    --yes|-y)  ASSUME_YES=true ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."

fail() { echo "ERROR: $*" >&2; exit 1; }

command -v aws >/dev/null 2>&1 || fail "aws CLI not found."
aws sts get-caller-identity >/dev/null 2>&1 || fail \
  "AWS credentials invalid or expired. In the Learner Lab: Start Lab > AWS Details > AWS CLI > Show."

confirm() {
  $ASSUME_YES && return 0
  printf '%s ' "$1"; read -r reply
  [ "$reply" = "yes" ] || { echo "Cancelled."; exit 0; }
}

echo "== 1. removing the application and the NLB it creates =="
# The Service belongs to the application repository and is not in the Terraform
# state. Deleting it here lets the AWS Load Balancer Controller, still running,
# remove the NLB properly. Once the cluster is gone, nothing can.
if [ -d "$APP_MANIFESTS" ] && command -v kubectl >/dev/null 2>&1 \
   && aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null | grep -qw "$CLUSTER"; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1
  kubectl delete -f "$APP_MANIFESTS/03-app/" --ignore-not-found >/dev/null 2>&1
  kubectl delete -f "$APP_MANIFESTS/02-service/" --ignore-not-found >/dev/null 2>&1 \
    && echo "  Service removed; waiting for the NLB to go"
  for _ in $(seq 1 30); do
    n=$(aws elbv2 describe-load-balancers --region "$REGION" \
        --query 'length(LoadBalancers)' --output text 2>/dev/null)
    [ "$n" = "0" ] && { echo "  NLB removed"; break; }
    sleep 5
  done
else
  echo "  cluster absent or manifests not found; the sweep covers the NLB"
fi

echo
echo "== 2. terraform destroy =="
if [ -d .terraform ] || terraform init -input=false >/dev/null 2>&1; then
  confirm "Destroy the cluster and everything running on it? Type 'yes':"
  terraform destroy -auto-approve || echo "  destroy returned an error; the sweep below covers the rest"
else
  echo "  Terraform not initialised; going straight to the verification"
fi

echo
echo "== 3. checking what is left =="
leftover=0

clusters=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null)
[ -n "$clusters" ] && { echo "  EKS cluster present: $clusters"; leftover=1; } || echo "  EKS: clean"

ec2=$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
[ -n "$ec2" ] && { echo "  EC2 running: $ec2"; leftover=1; } || echo "  EC2: clean"

elb=$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null)
[ -n "$elb" ] && { echo "  Load balancer present"; leftover=1; } || echo "  Load balancer: clean"

links=$(aws apigatewayv2 get-vpc-links --region "$REGION" \
        --query 'Items[].VpcLinkId' --output text 2>/dev/null)
[ -n "$links" ] && { echo "  VPC Link present: $links"; leftover=1; } || echo "  VPC Link: clean"

# Volumes from the observability PersistentVolumeClaims. They outlive the
# cluster and keep billing per provisioned GiB without showing up anywhere.
vols=$(aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
       --query 'Volumes[].VolumeId' --output text 2>/dev/null)
[ -n "$vols" ] && { echo "  Orphaned EBS volumes: $vols"; leftover=1; } || echo "  EBS volumes: clean"

if [ "$leftover" = "1" ] && [ "$SWEEP" = "true" ]; then
  echo
  echo "== 4. sweep =="
  confirm "The sweep deletes resources directly in AWS, bypassing the state. Type 'yes':"

  # Order matters: node group before cluster, or the cluster refuses removal
  # and the nodes keep billing.
  for c in $clusters; do
    for ng in $(aws eks list-nodegroups --region "$REGION" --cluster-name "$c" \
                --query 'nodegroups[]' --output text 2>/dev/null); do
      echo "  removing node group $ng"
      aws eks delete-nodegroup --region "$REGION" --cluster-name "$c" --nodegroup-name "$ng" >/dev/null 2>&1
      aws eks wait nodegroup-deleted --region "$REGION" --cluster-name "$c" --nodegroup-name "$ng" 2>/dev/null \
        && echo "    removed"
    done
    echo "  removing cluster $c"
    aws eks delete-cluster --region "$REGION" --name "$c" >/dev/null 2>&1
    aws eks wait cluster-deleted --region "$REGION" --name "$c" 2>/dev/null && echo "    removed"
  done

  # A load balancer created by the controller inside the cluster is not in the
  # Terraform state: it usually goes with the cluster, but not always.
  for lb in $elb; do
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$lb" >/dev/null 2>&1 \
      && echo "  load balancer removed"
  done
  for vl in $links; do
    aws apigatewayv2 delete-vpc-link --region "$REGION" --vpc-link-id "$vl" >/dev/null 2>&1 \
      && echo "  vpc link removed"
  done

  # After the cluster: a volume still attached refuses removal.
  for v in $(aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
             --query 'Volumes[].VolumeId' --output text 2>/dev/null); do
    aws ec2 delete-volume --region "$REGION" --volume-id "$v" >/dev/null 2>&1 \
      && echo "  volume $v removed" || echo "  volume $v not removed; check the console"
  done
elif [ "$leftover" = "1" ]; then
  echo
  echo "  Resources are left. Run again with --sweep to remove them directly in AWS."
fi

echo
echo "== done =="
echo "To check whether anything is still billing: ./scripts/status.sh"
