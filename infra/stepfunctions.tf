# Step Functions 리소스 구성 (sfn)
resource "aws_sfn_state_machine" "pipeline" {
  name = local.sfn_name
  # task 작업에 필요한 리소스들을 엑세스 하는 모든 권한 획득
  role_arn = aws_iam_role.stepfunctions.arn
  # 동작 유형
  type = "STANDARD"

  # 로그
  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.stepfunctions.arn}:*"
    # 입력, 출력 모든 로그 포함
    include_execution_data = true
    # 로그 수준 전체
    level = "ALL"
  }

  # task 정의 -> 7개 task 정의 (airflow의 7개의 task 정의와 맥락이 같음)
  definition = jsonencode({
    # 어떤 용도의  총괄 작업인지 설명
    Comment = "EventBridge -> Stepfunctions B/S/G pipeline"
    # 진행 방향, 어떤 Task(or State)부터 시작하는가?
    StartAt = "CheckBronze"
    # 전체 State 목록 구성 (분기 과정을 통해서 시나리오에 맞춰 task가 처리)
    States = {
      # Lambda-> CheckBronze 관련 세부 설정 값을 정의한다.
      CheckBronze = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::lambda:invoke"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 호출할 Lambda 함수 ARN을 지정한다.
          FunctionName = aws_lambda_function.check_bronze.arn
          # Step Functions 입력 JSONPath 값을 Payload.$ 파라미터로 전달한다.
          # $는 현재 Step Functions State의 전체 입력값
          # 입력 JSON 전체를 Lambda의 Payload로 넘긴다
          # .$가 붙으면 고정 문자열이 아니라 JSONPath 표현식의 값을 사용
          "Payload.$" = "$"
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.check"
        # 일시적 오류 발생 시 재시도 정책을 정의한다.
        Retry = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
          # 첫 재시도까지 기다릴 시간을 초 단위로 지정한다.
          IntervalSeconds = 2
          # 최대 재시도 횟수를 지정한다.
          MaxAttempts = 3
          # 재시도 간격을 증가시키는 배율을 지정한다.
          BackoffRate = 2
        }]
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "BronzeExists"
      }

      # BronzeExists 관련 세부 설정 값을 정의한다.
      BronzeExists = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Choice"
        # Choice State에서 평가할 분기 조건 목록을 정의한다.
        Choices = [{
          # Choice 조건에서 검사할 JSONPath 값을 지정한다.
          Variable = "$.check.Payload.data_exists"
          # 대상 값과 비교할 Boolean 값을 지정한다.
          BooleanEquals = true
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "BronzeToSilver"
        }]
        # 어떤 Choice 조건도 만족하지 않을 때 이동할 State를 지정한다.
        Default = "NoBronzeData"
      }

      # NoBronzeData 관련 세부 설정 값을 정의한다.
      NoBronzeData = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Succeed"
      }

      # Glue -> BronzeToSilver 관련 세부 설정 값을 정의한다.
      BronzeToSilver = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 실행할 AWS Glue Job 이름을 지정한다.
          JobName = aws_glue_job.bronze_to_silver.name
          # Glue Job에 전달할 실행 인자를 정의한다.
          Arguments = {
            # Glue Job에 --SOURCE_PATH.$ 실행 인자를 전달한다.
            "--SOURCE_PATH.$" = "$.check.Payload.source_path"
            # Glue Job에 --SILVER_BASE_PATH.$ 실행 인자를 전달한다.
            "--SILVER_BASE_PATH.$" = "$.check.Payload.silver_base_path"
            # Glue Job에 --REJECT_BASE_PATH.$ 실행 인자를 전달한다.
            "--REJECT_BASE_PATH.$" = "$.check.Payload.reject_base_path"
            # Glue Job에 --TARGET_YEAR.$ 실행 인자를 전달한다.
            "--TARGET_YEAR.$" = "$.check.Payload.year"
            # Glue Job에 --TARGET_MONTH.$ 실행 인자를 전달한다.
            "--TARGET_MONTH.$" = "$.check.Payload.month"
            # Glue Job에 --TARGET_DAY.$ 실행 인자를 전달한다.
            "--TARGET_DAY.$" = "$.check.Payload.day"
            # Glue Job에 --TARGET_HOUR.$ 실행 인자를 전달한다.
            "--TARGET_HOUR.$" = "$.check.Payload.hour"
            # Glue Job에 --OUTPUT_PARTITIONS 실행 인자를 전달한다.
            "--OUTPUT_PARTITIONS" = tostring(var.glue_output_partitions)
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.glue"
        # 일시적 오류 발생 시 재시도 정책을 정의한다.
        Retry = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.TaskFailed"]
          # 첫 재시도까지 기다릴 시간을 초 단위로 지정한다.
          IntervalSeconds = 10
          # 최대 재시도 횟수를 지정한다.
          MaxAttempts = 2
          # 재시도 간격을 증가시키는 배율을 지정한다.
          BackoffRate = 2
        }]
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "RepairSilverPartitions"
      }

      # RepairSilverPartitions 관련 세부 설정 값을 정의한다.
      RepairSilverPartitions = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # Athena에서 실행할 SQL 문자열을 지정한다.
          QueryString = "MSCK REPAIR TABLE ${aws_glue_catalog_table.silver.name}"
          # Athena 쿼리를 실행할 WorkGroup을 지정한다.
          WorkGroup = aws_athena_workgroup.pipeline.name
          # Athena 쿼리가 사용할 데이터베이스 컨텍스트를 지정한다.
          QueryExecutionContext = {
            # Athena에서 사용할 Glue Data Catalog 데이터베이스를 지정한다.
            Database = aws_glue_catalog_database.pipeline.name
          }
          # Athena 쿼리 결과 저장 위치 등의 실행 설정을 정의한다.
          ResultConfiguration = {
            # Athena 쿼리 결과 파일을 저장할 S3 경로를 지정한다.
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.repair"
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "CleanupExistingGold"
      }

      # Lambda-> CleanupExistingGold 관련 세부 설정 값을 정의한다.
      CleanupExistingGold = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::lambda:invoke"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 호출할 Lambda 함수 ARN을 지정한다.
          FunctionName = aws_lambda_function.cleanup_gold.arn
          # Lambda 함수에 전달할 이벤트 본문을 정의한다.
          Payload = {
            # Step Functions 입력 JSONPath 값을 gold_prefix.$ 파라미터로 전달한다.
            "gold_prefix.$" = "$.check.Payload.gold_prefix"
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.cleanup"
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "RegisterGoldPartition"
      }

      # RegisterGoldPartition 관련 세부 설정 값을 정의한다.
      RegisterGoldPartition = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # Step Functions 입력 JSONPath 값을 QueryString.$ 파라미터로 전달한다.
          "QueryString.$" = "$.check.Payload.gold_partition_query"
          # Athena 쿼리를 실행할 WorkGroup을 지정한다.
          WorkGroup = aws_athena_workgroup.pipeline.name
          # Athena 쿼리가 사용할 데이터베이스 컨텍스트를 지정한다.
          QueryExecutionContext = {
            # Athena에서 사용할 Glue Data Catalog 데이터베이스를 지정한다.
            Database = aws_glue_catalog_database.pipeline.name
          }
          # Athena 쿼리 결과 저장 위치 등의 실행 설정을 정의한다.
          ResultConfiguration = {
            # Athena 쿼리 결과 파일을 저장할 S3 경로를 지정한다.
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.gold_partition"
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "SilverToGold"
      }

      # SilverToGold 관련 세부 설정 값을 정의한다.
      SilverToGold = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # Step Functions 입력 JSONPath 값을 QueryString.$ 파라미터로 전달한다.
          "QueryString.$" = "$.check.Payload.gold_insert_query"
          # Athena 쿼리를 실행할 WorkGroup을 지정한다.
          WorkGroup = aws_athena_workgroup.pipeline.name
          # Athena 쿼리가 사용할 데이터베이스 컨텍스트를 지정한다.
          QueryExecutionContext = {
            # Athena에서 사용할 Glue Data Catalog 데이터베이스를 지정한다.
            Database = aws_glue_catalog_database.pipeline.name
          }
          # Athena 쿼리 결과 저장 위치 등의 실행 설정을 정의한다.
          ResultConfiguration = {
            # Athena 쿼리 결과 파일을 저장할 S3 경로를 지정한다.
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.gold_query"
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "QualityCheck"
      }

      # Lambda-> QualityCheck 관련 세부 설정 값을 정의한다.
      QualityCheck = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::lambda:invoke"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 호출할 Lambda 함수 ARN을 지정한다.
          FunctionName = aws_lambda_function.quality_check.arn
          # Lambda 함수에 전달할 이벤트 본문을 정의한다.
          Payload = {
            # Step Functions 입력 JSONPath 값을 gold_prefix.$ 파라미터로 전달한다.
            "gold_prefix.$" = "$.check.Payload.gold_prefix"
          }
        }
        # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
        ResultPath = "$.quality"
        # Task 실패 시 이동할 예외 처리 경로를 정의한다.
        Catch = [{
          # 재시도 또는 Catch가 처리할 오류 종류를 지정한다.
          ErrorEquals = ["States.ALL"]
          # Task 실행 결과를 상태 입력의 어느 위치에 저장할지 지정한다.
          ResultPath = "$.error"
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifyFailure"
        }]
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "QualityPassed"
      }

      # QualityPassed 관련 세부 설정 값을 정의한다.
      QualityPassed = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Choice"
        # Choice State에서 평가할 분기 조건 목록을 정의한다.
        Choices = [{
          # Choice 조건에서 검사할 JSONPath 값을 지정한다.
          Variable = "$.quality.Payload.ok"
          # 대상 값과 비교할 Boolean 값을 지정한다.
          BooleanEquals = true
          # 현재 State 완료 후 이동할 다음 State를 지정한다.
          Next = "NotifySuccess"
        }]
        # 어떤 Choice 조건도 만족하지 않을 때 이동할 State를 지정한다.
        Default = "NotifyQualityFailure"
      }

      # NotifySuccess 관련 세부 설정 값을 정의한다.
      NotifySuccess = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::sns:publish"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 알림을 게시할 SNS Topic ARN을 지정한다.
          TopicArn = aws_sns_topic.pipeline.arn
          # SNS 알림 메시지의 제목을 지정한다.
          Subject = "Data pipeline SUCCESS"
          # Step Functions 입력 JSONPath 값을 Message.$ 파라미터로 전달한다.
          "Message.$" = "States.JsonToString($)"
        }
        # 현재 State가 성공적으로 끝나면 상태 머신 실행을 종료한다.
        End = true
      }

      # NotifyQualityFailure 관련 세부 설정 값을 정의한다.
      NotifyQualityFailure = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::sns:publish"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 알림을 게시할 SNS Topic ARN을 지정한다.
          TopicArn = aws_sns_topic.pipeline.arn
          # SNS 알림 메시지의 제목을 지정한다.
          Subject = "Data pipeline QUALITY FAILURE"
          # Step Functions 입력 JSONPath 값을 Message.$ 파라미터로 전달한다.
          "Message.$" = "States.JsonToString($)"
        }
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "PipelineQualityFailed"
      }

      # PipelineQualityFailed 관련 세부 설정 값을 정의한다.
      PipelineQualityFailed = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Fail"
        # Fail State에서 반환할 오류 코드를 지정한다.
        Error = "GoldQualityCheckFailed"
        # Fail State에서 반환할 실패 원인을 지정한다.
        Cause = "Gold output was empty or invalid"
      }

      # NotifyFailure 관련 세부 설정 값을 정의한다.
      NotifyFailure = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Task"
        # Task가 호출할 AWS 서비스 통합 ARN을 지정한다.
        Resource = "arn:aws:states:::sns:publish"
        # 호출 대상 서비스에 전달할 입력 파라미터를 정의한다.
        Parameters = {
          # 알림을 게시할 SNS Topic ARN을 지정한다.
          TopicArn = aws_sns_topic.pipeline.arn
          # SNS 알림 메시지의 제목을 지정한다.
          Subject = "Data pipeline FAILURE"
          # Step Functions 입력 JSONPath 값을 Message.$ 파라미터로 전달한다.
          "Message.$" = "States.JsonToString($)"
        }
        # 현재 State 완료 후 이동할 다음 State를 지정한다.
        Next = "PipelineFailed"
      }

      # PipelineFailed 관련 세부 설정 값을 정의한다.
      PipelineFailed = {
        # 해당 Step Functions State의 유형을 지정한다.
        Type = "Fail"
        # Fail State에서 반환할 오류 코드를 지정한다.
        Error = "PipelineTaskFailed"
        # Fail State에서 반환할 실패 원인을 지정한다.
        Cause = "One or more pipeline tasks failed"
      }
    }

  })
}