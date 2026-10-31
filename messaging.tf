# Queues of the service order saga (ADR-015 in the OS Service repository).
#
# They are the saga's broker, and a broker is shared platform: the three
# services publish and consume on it, as they would on a RabbitMQ cluster.
# That is why they live here, next to the cluster and the gateway, and not in
# any one service's repository. The notifications topic stays in the lambda
# repository, which owns its consumer.
#
# One command queue per participant and one reply queue for the orchestrator.
# FIFO, grouped by service order: the messages of one order stay in sequence,
# and a repeated send inside the five-minute window is dropped by its id.

locals {
  saga_queues = ["billing-commands", "execution-commands", "saga-replies"]
}

# Where a message lands after five failed receives. The OS Service reads the
# command dead-letter queues and treats an exhausted command as a failed step;
# the reply dead-letter queue is a failure of the OS itself and raises an alert.
resource "aws_sqs_queue" "saga_dlq" {
  for_each = toset(local.saga_queues)

  name       = "${local.cluster_name}-${each.key}-dlq.fifo"
  fifo_queue = true

  # Fourteen days, the maximum: time to notice and inspect a failed message.
  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "saga" {
  for_each = toset(local.saga_queues)

  name       = "${local.cluster_name}-${each.key}.fifo"
  fifo_queue = true

  # Off: every message carries its own MessageDeduplicationId, the envelope's
  # messageId. Deduplicating by content would drop two different commands
  # that happen to have the same body.
  content_based_deduplication = false

  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20

  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.saga_dlq[each.key].arn
    maxReceiveCount     = 5
  })
}
