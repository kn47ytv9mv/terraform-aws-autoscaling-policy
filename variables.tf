variable "name" {
  default     = null
  description = "Name of the policy. If null, a unique name is generated."
}

variable "autoscaling_group_name" {
  default     = null
  description = "Name of the group this policy scales, from terraform-aws-autoscaling-group's name output."
}

variable "policy_type" {
  default     = "TargetTrackingScaling"
  description = "How the policy decides to scale: 'TargetTrackingScaling' holds a metric at a target value and is the right default for most workloads; 'StepScaling' applies graduated adjustments across metric ranges; 'SimpleScaling' applies one adjustment and then waits out a cooldown."

  validation {
    condition     = contains(["TargetTrackingScaling", "StepScaling", "SimpleScaling", "PredictiveScaling"], var.policy_type)
    error_message = "policy_type must be one of 'TargetTrackingScaling', 'StepScaling', 'SimpleScaling', or 'PredictiveScaling'."
  }
}

variable "enabled" {
  default     = null
  description = "Whether the policy is active. Setting false leaves it in place but stops it acting, which is how scaling is paused during an incident without deleting the configuration. If null, AWS's own default (enabled) applies."
}

variable "target_tracking" {
  default     = null
  description = "Target-tracking configuration, used when policy_type is 'TargetTrackingScaling'. Set either predefined_metric_type ('ASGAverageCPUUtilization', 'ASGAverageNetworkIn', 'ASGAverageNetworkOut', or 'ALBRequestCountPerTarget') or the customized_metric fields, not both. disable_scale_in leaves the policy to scale out only, which pairs with a separate scale-in policy on a different metric."
  type = object({
    target_value           = number
    predefined_metric_type = optional(string)
    resource_label         = optional(string)
    disable_scale_in       = optional(bool)
    customized_metric = optional(object({
      metric_name = string
      namespace   = string
      statistic   = string
      unit        = optional(string)
      period      = optional(number)
      dimensions  = optional(map(string), {})
    }))
  })

  validation {
    condition     = var.target_tracking == null || (var.target_tracking.predefined_metric_type == null) != (var.target_tracking.customized_metric == null)
    error_message = "A target-tracking policy needs exactly one of predefined_metric_type or customized_metric."
  }

  validation {
    condition     = var.target_tracking == null || var.target_tracking.predefined_metric_type == null || contains(["ASGAverageCPUUtilization", "ASGAverageNetworkIn", "ASGAverageNetworkOut", "ALBRequestCountPerTarget"], var.target_tracking.predefined_metric_type)
    error_message = "predefined_metric_type must be one of 'ASGAverageCPUUtilization', 'ASGAverageNetworkIn', 'ASGAverageNetworkOut', or 'ALBRequestCountPerTarget'."
  }
}

variable "adjustment_type" {
  default     = null
  description = "How scaling_adjustment and step adjustments are interpreted: 'ChangeInCapacity' (add or remove that many instances), 'ExactCapacity' (set the count outright), or 'PercentChangeInCapacity'. Required for step and simple scaling, and rejected for target tracking."
}

variable "scaling_adjustment" {
  default     = null
  description = "How much to scale by, in the units adjustment_type selects. Only used by 'SimpleScaling'."
}

variable "cooldown" {
  default     = null
  description = "Seconds after a simple-scaling activity before another may start. Only used by 'SimpleScaling' — step and target-tracking policies use estimated_instance_warmup instead."
}

variable "estimated_instance_warmup" {
  default     = null
  description = "Seconds a newly launched instance takes before its metrics count toward scaling decisions. Too short and the group scales again while the first instance is still booting, overshooting badly."
}

variable "metric_aggregation_type" {
  default     = null
  description = "How datapoints are aggregated for a step-scaling policy: 'Minimum', 'Maximum', or 'Average'. If null, AWS's own default ('Average') applies."
}

variable "min_adjustment_magnitude" {
  default     = null
  description = "Minimum number of instances to move when adjustment_type is 'PercentChangeInCapacity'. Without it, a small percentage of a small group rounds to zero and the policy never does anything."
}

variable "step_adjustments" {
  default     = []
  description = "Graduated adjustments for a step-scaling policy, each covering a range of the breach relative to the alarm threshold. Bounds are offsets, not absolute metric values: a lower bound of 0 and upper of 10 covers a breach up to 10 above the threshold. Exactly one step must have no lower bound and one no upper bound, or some breaches fall into a gap and nothing happens."
  type = list(object({
    scaling_adjustment          = number
    metric_interval_lower_bound = optional(string)
    metric_interval_upper_bound = optional(string)
  }))
}
