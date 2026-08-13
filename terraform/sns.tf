# A plain SNS topic, deliberately not wired to anything yet. Chain C's
# event-driven automation, automated incident response, and compliance
# projects are what actually publish real findings here and subscribe
# real response logic to it, this environment only provides the empty
# channel, wiring it up is each project's own work.

resource "aws_sns_topic" "security_alerts" {
  name = "${var.environment_name}-security-alerts"
}

resource "aws_sns_topic_subscription" "alert_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
