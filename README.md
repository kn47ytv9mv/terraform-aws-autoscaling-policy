# terraform-aws-autoscaling-policy

Terraform module for an EC2 autoscaling policy — the rule that actually
changes an autoscaling group's capacity in response to load.

## Cost

Autoscaling policies carry no charge. The instances they add do. A
target-tracking policy creates and manages CloudWatch alarms on your
behalf, which bill at the standard alarm rate. See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page.

## Design

Pair with
[`terraform-aws-autoscaling-group`](https://github.com/kn47ytv9mv/terraform-aws-autoscaling-group),
whose `name` output goes in `autoscaling_group_name`. **A group with no
policy never changes size on its own** — it holds whatever
`desired_capacity` says and replaces unhealthy instances, nothing more.

One policy per module call, because a group commonly has several, each
watching a different signal and independently tuned.

### Choosing a policy type

`TargetTrackingScaling` is the default and the right answer for most
workloads: name a metric and a target value, and AWS creates and
manages the alarms itself. `StepScaling` gives graduated responses
across ranges of a breach and needs its own CloudWatch alarm pointed at
the policy's ARN. `SimpleScaling` is the oldest form — one adjustment
then a cooldown — and is rarely the right choice today.

Set `estimated_instance_warmup` to however long an instance genuinely
takes to start serving. Too short and the group scales again while the
first instance is still booting, overshooting hard.

`disable_scale_in` on a target-tracking policy leaves it scaling out
only. That is how two policies are combined: one scaling out on a
demand metric, another scaling in on something different.

### Step adjustment bounds are offsets

A step adjustment's bounds are relative to the alarm threshold, not
absolute metric values: a lower bound of `0` and an upper of `10`
covers a breach up to ten above the threshold. **Exactly one step must
have no lower bound and one no upper bound**, or some breaches fall into
a gap where no step applies and the policy silently does nothing.

### Deliberately not covered

Predictive scaling, and metric-math queries inside a customized metric
specification, are not exposed. Both carry deeply nested surface for
features most groups do not use.

## Usage

```hcl
module "cpu_target" {
  source = "kn47ytv9mv/autoscaling-policy/aws"

  name                   = "cpu-target"
  autoscaling_group_name = module.group.name

  target_tracking = {
    target_value           = 60
    predefined_metric_type = "ASGAverageCPUUtilization"
  }

  estimated_instance_warmup = 300
}
```

Or directly from this repository, stepping on a custom metric:

```hcl
module "queue_steps" {
  source = "github.com/kn47ytv9mv/terraform-aws-autoscaling-policy"

  autoscaling_group_name = "workers"
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"

  step_adjustments = [
    { scaling_adjustment = 1, metric_interval_lower_bound = "0", metric_interval_upper_bound = "10" },
    { scaling_adjustment = 3, metric_interval_lower_bound = "10" },
  ]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the policy. If null, a unique name is generated. | `null` | no |
| autoscaling_group_name | Name of the group this policy scales, from `terraform-aws-autoscaling-group`. | `null` | no |
| policy_type | `'TargetTrackingScaling'`, `'StepScaling'`, `'SimpleScaling'`, or `'PredictiveScaling'`. | `"TargetTrackingScaling"` | no |
| enabled | Whether the policy is active. False pauses scaling without deleting the configuration. | `null` | no |
| target_tracking | Target-tracking configuration. Needs exactly one of `predefined_metric_type` or `customized_metric`. | `null` | no |
| adjustment_type | `'ChangeInCapacity'`, `'ExactCapacity'`, or `'PercentChangeInCapacity'`. Required for step and simple scaling. | `null` | no |
| scaling_adjustment | How much to scale by. Only used by `'SimpleScaling'`. | `null` | no |
| cooldown | Seconds between simple-scaling activities. Only used by `'SimpleScaling'`. | `null` | no |
| estimated_instance_warmup | Seconds before a new instance's metrics count toward scaling decisions. | `null` | no |
| metric_aggregation_type | `'Minimum'`, `'Maximum'`, or `'Average'` for step scaling. | `null` | no |
| min_adjustment_magnitude | Minimum instances to move under `'PercentChangeInCapacity'`, so a small percentage does not round to zero. | `null` | no |
| step_adjustments | Graduated adjustments, with bounds expressed as offsets from the alarm threshold. | `[]` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the policy. |
| arn | The ARN of the policy. Feed this into a CloudWatch alarm's `alarm_actions` for a step or simple scaling policy. |
| name | The name of the policy. |

## License

MIT — see [LICENSE.md](LICENSE.md).
