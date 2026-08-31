# 권한 + 리소스
# 정책
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
# Role 생성 -> 기본 events에 대한 정책 반영
resource "aws_iam_role" "eventbridge" {
  name               = "${var.project_name}-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json
}
# 이벤트브릿지 => step function 작동을 위한 정책 조회
data "aws_iam_policy_document" "eventbridge" {
  statement {
    actions   = ["states:StartExecution"]
    # step functions 리소스
    resources = [aws_sfn_state_machine.pipeline.arn]
  }
}
# role 바로 위 정책을 반영
resource "aws_iam_role_policy" "eventbridge" {
  name   = "${var.project_name}-eventbridge-policy"
  role   = aws_iam_role.eventbridge.id
  policy = data.aws_iam_policy_document.eventbridge.json
}