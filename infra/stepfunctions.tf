# Step Functions 리소스 구성 (sfn)
resource "aws_sfn_state_machine" "pipeline" {
  name = local.sfn_name
  role_arn = aws_iam_role.
}