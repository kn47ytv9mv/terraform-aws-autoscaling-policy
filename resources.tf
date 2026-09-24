resource "random_uuid" "resource" {}

resource "aws_autoscaling_policy" "resource" {
  name                   = coalesce(var.name, random_uuid.resource.id)
  autoscaling_group_name = var.autoscaling_group_name
  policy_type            = var.policy_type
  enabled                = var.enabled

  adjustment_type           = var.adjustment_type
  scaling_adjustment        = var.scaling_adjustment
  cooldown                  = var.cooldown
  estimated_instance_warmup = var.estimated_instance_warmup
  metric_aggregation_type   = var.metric_aggregation_type
  min_adjustment_magnitude  = var.min_adjustment_magnitude

  dynamic "target_tracking_configuration" {
    for_each = var.target_tracking[*]

    content {
      target_value     = target_tracking_configuration.value.target_value
      disable_scale_in = target_tracking_configuration.value.disable_scale_in

      dynamic "predefined_metric_specification" {
        for_each = target_tracking_configuration.value.predefined_metric_type[*]

        content {
          predefined_metric_type = predefined_metric_specification.value
          resource_label         = target_tracking_configuration.value.resource_label
        }
      }

      dynamic "customized_metric_specification" {
        for_each = target_tracking_configuration.value.customized_metric[*]

        content {
          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          unit        = customized_metric_specification.value.unit
          period      = customized_metric_specification.value.period

          dynamic "metric_dimension" {
            for_each = customized_metric_specification.value.dimensions

            content {
              name  = metric_dimension.key
              value = metric_dimension.value
            }
          }
        }
      }
    }
  }

  dynamic "step_adjustment" {
    for_each = var.step_adjustments

    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
      metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
    }
  }
}

output "id" {
  description = "The ID of the policy."
  value       = aws_autoscaling_policy.resource.id
}

output "arn" {
  description = "The ARN of the policy. Feed this into a CloudWatch alarm's alarm_actions for a step or simple scaling policy, which fire from an alarm rather than managing their own."
  value       = aws_autoscaling_policy.resource.arn
}

output "name" {
  description = "The name of the policy."
  value       = aws_autoscaling_policy.resource.name
}
