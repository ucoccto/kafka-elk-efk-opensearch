# vector -> 데이터 put -> Firehose 입력 (direct put firehose)
resource "aws_kinesis_firehose_delivery_stream" "opensearch" {
  name        = var.project_name
  destination = "opensearch"
  opensearch_configuration {
    # opensearch의 arn
    domain_arn = ""
    role_arn   = aws_iam_role.firehose.arn
    # 검색엔진의 인덱스 구분정보 문자열 세팅 -> 전송하는 데이터는 특정 인덱스로 관리
    index_name = var.opensearch_index_name
    # 시간 정보를 이용하여 데이터를 나누는 행위 x, 데이터는 통으로 들어감
    index_rotation_period = "NoRotation"
    buffering_size     = var.firehose_buffer_size
    buffering_interval = var.firehose_buffer_interval
    retry_duration     = 300
    # s3로 백업되는 데이터는 전솔 실패한 데이터만 전송(오픈서치에서는 데이터를 document라 부름)
    s3_backup_mode     = "FailedDocumentsOnly"
    
    s3_configuration {
      
    }
    cloudwatch_logging_options {
      
    }
  }
  depends_on = [
    aws_iam_role_policy.firehose
  ]



  extended_s3_configuration {
    bucket_arn = aws_s3_bucket.data.arn
    role_arn = aws_iam_role.firehose.arn
    buffering_size     = var.firehose_buffer_size
    buffering_interval = var.firehose_buffer_interval
    compression_format = "GZIP"
    custom_time_zone = "Asia/Seoul"
    prefix = "bronze/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/bronze/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  }
  
}