# Step Functions 리소스 구성 (sfn)
resource "aws_sfn_state_machine" "pipeline" {
  name = local.sfn_name
  # task 작업에 필요한 리소스들을 엑세스 하는 모든 권한 획득
  role_arn = aws_iam_role.stepfunctions.arn
  # 동작 유형
  type = "STANDARD"

  # 로그
  logging_configuration {
    
  }

  # task 정의 -> 7개 task 정의 (airflow의 7개의 task 정의와 맥락이 같음)
  definition = jsonencode({
    # 어떤 용도의  총괄 작업인지 설명
    Comment = "EventBridge -> Stepfunctions B/S/G pipeline"
    # 진행 방향, 어떤 Task(or State)부터 시작하는가?
    StartAt = "CheckBronze"
    # 전체 State 목록 구성
    States = {
        # 람다 함수를 통해서 브론즈 값 체크, 설정값등 처리
        CheckBronze = {}
        CheckBronze = {}
        CheckBronze = {}
        CheckBronze = {}
        CheckBronze = {}
        CheckBronze = {}
        CheckBronze = {}
    }

  })
}