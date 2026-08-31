# 권한 + 리소스
data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eventbridge" {
  name               = "${local.name_prefix}-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json
}

data "aws_iam_policy_document" "eventbridge" {
  statement {
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.pipeline.arn]
  }
}

resource "aws_iam_role_policy" "eventbridge" {
  name   = "${local.name_prefix}-eventbridge-policy"
  role   = aws_iam_role.eventbridge.id
  policy = data.aws_iam_policy_document.eventbridge.json
}