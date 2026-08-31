# vector -> 데이터 put -> Firehose 입력 (direct put firehose)
resource "aws_kinesis_firehose_delivery_stream" "bronze" {
  name        = local.firehose_name
  # 목적지 수정
  destination = "extended_s3"
  # 목적지 구성
  extended_s3_configuration {
    # role
    role_arn = aws_iam_role.firehose.arn
    # 버킷
    bucket_arn = aws_s3_bucket.data_lake.arn
    # 버퍼크기
    # 버퍼인터벌
    # 압축형태
    # 프리픽스
    # 에러플릭
    # 로그->클라우드와치
  }


  depends_on = [
    aws_iam_role_policy.firehose
  ]
}