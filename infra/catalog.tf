# DB 생성, silver, gold 테이블 생성
resource "aws_glue_catalog_database" "pipeline" {
    # "-" => "_" 교체
  name = local.glue_database_name
}