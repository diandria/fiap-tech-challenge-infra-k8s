#!/usr/bin/env bash
#
# Derruba a infraestrutura Kubernetes provisionada por este repositorio.
#
#   ./scripts/teardown.sh                    destroy do Terraform + conferencia
#   ./scripts/teardown.sh --sweep            remove tambem o que sobrou fora do estado
#   ./scripts/teardown.sh --yes              nao pergunta (para uso em workflow)
#
# O EKS e o item mais caro da fase: o control plane custa USD 0,10/hora, cerca
# de cinco vezes o banco. Derrubar entre sessoes de trabalho e o que faz o
# orcamento do lab durar.
#
# Por que existe o --sweep: se o estado se perder ou dessincronizar, o
# `terraform destroy` nao encontra os recursos, mas a AWS continua cobrando.
# No EKS isso e pior que no RDS, porque o node group sobrevive ao cluster e
# segue cobrando EC2.
set -uo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${CLUSTER_NAME:-car-repair-shop}"

SWEEP=false; ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --sweep)   SWEEP=true ;;
    --yes|-y)  ASSUME_YES=true ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "Opcao desconhecida: $arg"; exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."

fail() { echo "ERRO: $*" >&2; exit 1; }

command -v aws >/dev/null 2>&1 || fail "aws CLI nao encontrado."
aws sts get-caller-identity >/dev/null 2>&1 || fail \
  "Credencial AWS invalida ou expirada. No Learner Lab: Start Lab > AWS Details > AWS CLI > Show."

confirm() {
  $ASSUME_YES && return 0
  printf '%s ' "$1"; read -r reply
  [ "$reply" = "sim" ] || { echo "Cancelado."; exit 0; }
}

echo "== 1. terraform destroy =="
if [ -d .terraform ] || terraform init -input=false >/dev/null 2>&1; then
  confirm "Destruir o cluster e tudo que roda nele? Digite 'sim':"
  terraform destroy -auto-approve || echo "  destroy retornou erro; o sweep abaixo cobre o resto"
else
  echo "  Terraform nao inicializado; indo direto para a verificacao"
fi

echo
echo "== 2. conferindo o que sobrou =="
leftover=0

clusters=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null)
[ -n "$clusters" ] && { echo "  Cluster EKS presente: $clusters"; leftover=1; } || echo "  EKS: limpo"

ec2=$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=instance-state-name,Values=running" \
      --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
[ -n "$ec2" ] && { echo "  EC2 em execucao: $ec2"; leftover=1; } || echo "  EC2: limpo"

elb=$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null)
[ -n "$elb" ] && { echo "  Load balancer presente"; leftover=1; } || echo "  Load balancer: limpo"

links=$(aws apigatewayv2 get-vpc-links --region "$REGION" \
        --query 'Items[].VpcLinkId' --output text 2>/dev/null)
[ -n "$links" ] && { echo "  VPC Link presente: $links"; leftover=1; } || echo "  VPC Link: limpo"

if [ "$leftover" = "1" ] && [ "$SWEEP" = "true" ]; then
  echo
  echo "== 3. sweep =="
  confirm "O sweep apaga recursos direto na AWS, sem passar pelo estado. Digite 'sim':"

  # Ordem importa: node group antes do cluster, senao o cluster recusa a
  # remocao e os nos continuam cobrando.
  for c in $clusters; do
    for ng in $(aws eks list-nodegroups --region "$REGION" --cluster-name "$c" \
                --query 'nodegroups[]' --output text 2>/dev/null); do
      echo "  removendo node group $ng"
      aws eks delete-nodegroup --region "$REGION" --cluster-name "$c" --nodegroup-name "$ng" >/dev/null 2>&1
      aws eks wait nodegroup-deleted --region "$REGION" --cluster-name "$c" --nodegroup-name "$ng" 2>/dev/null \
        && echo "    removido"
    done
    echo "  removendo cluster $c"
    aws eks delete-cluster --region "$REGION" --name "$c" >/dev/null 2>&1
    aws eks wait cluster-deleted --region "$REGION" --name "$c" 2>/dev/null && echo "    removido"
  done

  # Load balancer criado pelo controller dentro do cluster nao esta no estado
  # do Terraform: some com o cluster, mas nem sempre.
  for lb in $elb; do
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$lb" >/dev/null 2>&1 \
      && echo "  load balancer removido"
  done
  for vl in $links; do
    aws apigatewayv2 delete-vpc-link --region "$REGION" --vpc-link-id "$vl" >/dev/null 2>&1 \
      && echo "  vpc link removido"
  done
elif [ "$leftover" = "1" ]; then
  echo
  echo "  Sobrou recurso. Rode novamente com --sweep para remover direto na AWS."
fi

echo
echo "== fim =="
echo "Para conferir se algo ainda cobra: ./scripts/status.sh"
