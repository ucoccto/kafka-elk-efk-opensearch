# *.py 파일 -> 압축(zip) -> 람다 함수 등록시 업로드 -> 관련 정보 조회
# py 원소스 위치, 차후 압축되면 생성되는 zip 위치 지정 -> 조회통해서 가져올수 있게 구성
data "archive_file" "check_bronze" {
  type        = "zip"
  source_file = "${path.module}/../lambda/check_bronze.py"
  output_path = "${path.module}/.check_bronze.zip"
}

data "archive_file" "cleanup_gold" {
  type        = "zip"
  source_file = "${path.module}/../lambda/cleanup_gold.py"
  output_path = "${path.module}/.cleanup_gold.zip"
}

data "archive_file" "quality_check" {
  type        = "zip"
  source_file = "${path.module}/../lambda/quality_check.py"
  output_path = "${path.module}/.quality_check.zip"
}

# 람다 함수 3개 리소스 생성
resource "aws_lambda_function" "check_bronze" {
    # 이름
    function_name = "${var.project_name}-check-bronze"
    # 업무 => 권한 => role
    role = aws_iam_role.
    # 파이썬 작동 => 런타임 환경
    runtime = 
    # 엔트리포인트 (시작점 지정)
    handler = 
    # 소스
    filename = 
    # 소스 업데이트
    source_code_hash = 
    # 작업 최대시간
    timeout = 
    # 람다 사용할 최대 메모리
    memory_size = 
    # 환경변수  
    environment {
      
    }
}
resource "aws_lambda_function" "cleanup_gold" {
  
}
resource "aws_lambda_function" "quality_check" {
  
}


