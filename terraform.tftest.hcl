mock_provider "aws" {}

run "invalid_policy_type_is_rejected" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    policy_type            = "MagicScaling"
  }

  expect_failures = [var.policy_type]
}

run "target_tracking_needs_exactly_one_metric_source" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    target_tracking = {
      target_value           = 60
      predefined_metric_type = "ASGAverageCPUUtilization"
      customized_metric = {
        metric_name = "QueueDepth"
        namespace   = "App"
        statistic   = "Average"
      }
    }
  }

  expect_failures = [var.target_tracking]
}

run "invalid_predefined_metric_type_is_rejected" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    target_tracking = {
      target_value           = 60
      predefined_metric_type = "ASGAverageDiskUtilization"
    }
  }

  expect_failures = [var.target_tracking]
}

run "name_defaults_to_random_uuid" {
  command = apply

  variables {
    autoscaling_group_name = "web"
  }

  assert {
    condition     = aws_autoscaling_policy.resource.name == random_uuid.resource.id
    error_message = "Leaving name unset should fall back to the generated random_uuid."
  }
}

run "defaults_to_target_tracking" {
  command = plan

  variables {
    autoscaling_group_name = "web"
  }

  assert {
    condition     = aws_autoscaling_policy.resource.policy_type == "TargetTrackingScaling"
    error_message = "The policy should default to target tracking, which suits most workloads."
  }
}

run "predefined_target_tracking_emits_one_specification" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    target_tracking = {
      target_value           = 60
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }

  assert {
    condition     = length(aws_autoscaling_policy.resource.target_tracking_configuration) == 1
    error_message = "Setting target_tracking should emit exactly one configuration block."
  }

  assert {
    condition     = one(one(aws_autoscaling_policy.resource.target_tracking_configuration).predefined_metric_specification).predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "The predefined metric type should pass through unchanged."
  }

  assert {
    condition     = length(one(aws_autoscaling_policy.resource.target_tracking_configuration).customized_metric_specification) == 0
    error_message = "A predefined metric should emit no customized metric specification."
  }
}

run "customized_target_tracking_emits_dimensions" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    target_tracking = {
      target_value = 100
      customized_metric = {
        metric_name = "QueueDepth"
        namespace   = "App"
        statistic   = "Average"
        dimensions  = { QueueName = "jobs" }
      }
    }
  }

  assert {
    condition     = length(one(one(aws_autoscaling_policy.resource.target_tracking_configuration).customized_metric_specification).metric_dimension) == 1
    error_message = "Each dimension supplied should produce one metric_dimension block."
  }
}

run "no_step_adjustments_by_default" {
  command = plan

  variables {
    autoscaling_group_name = "web"
  }

  assert {
    condition     = length(aws_autoscaling_policy.resource.step_adjustment) == 0
    error_message = "Leaving step_adjustments unset should emit no step_adjustment blocks."
  }
}

run "step_adjustments_create_one_block_each" {
  command = plan

  variables {
    autoscaling_group_name = "web"
    policy_type            = "StepScaling"
    adjustment_type        = "ChangeInCapacity"
    step_adjustments = [
      { scaling_adjustment = 1, metric_interval_lower_bound = "0", metric_interval_upper_bound = "10" },
      { scaling_adjustment = 3, metric_interval_lower_bound = "10" },
    ]
  }

  assert {
    condition     = length(aws_autoscaling_policy.resource.step_adjustment) == 2
    error_message = "Each step_adjustments entry should produce one step_adjustment block."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    name                   = "cpu-target"
    autoscaling_group_name = "web"

    target_tracking = {
      target_value           = 60
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    estimated_instance_warmup = 300
  }
}

run "readme_step_scaling_example" {
  command = plan

  variables {
    autoscaling_group_name = "workers"
    policy_type            = "StepScaling"
    adjustment_type        = "ChangeInCapacity"

    step_adjustments = [
      { scaling_adjustment = 1, metric_interval_lower_bound = "0", metric_interval_upper_bound = "10" },
      { scaling_adjustment = 3, metric_interval_lower_bound = "10" },
    ]
  }
}
