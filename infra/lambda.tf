# *.py 파일 -> 압축(zip) -> 람다 함수 등록시 업로드 -> 관련 정보 조회
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

