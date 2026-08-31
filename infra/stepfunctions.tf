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
    # 전체 State 목록 구성 (분기 과정을 통해서 시나리오에 맞춰 task가 처리)
    States = {
      CheckBronze = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.check_bronze.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.check"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "BronzeExists"
      }

      BronzeExists = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.check.Payload.data_exists"
          BooleanEquals = true
          Next          = "BronzeToSilver"
        }]
        Default = "NoBronzeData"
      }

      NoBronzeData = {
        Type = "Succeed"
      }

      BronzeToSilver = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.bronze_to_silver.name
          Arguments = {
            "--SOURCE_PATH.$"        = "$.check.Payload.source_path"
            "--SILVER_BASE_PATH.$"   = "$.check.Payload.silver_base_path"
            "--REJECT_BASE_PATH.$"   = "$.check.Payload.reject_base_path"
            "--TARGET_YEAR.$"        = "$.check.Payload.year"
            "--TARGET_MONTH.$"       = "$.check.Payload.month"
            "--TARGET_DAY.$"         = "$.check.Payload.day"
            "--TARGET_HOUR.$"        = "$.check.Payload.hour"
            "--OUTPUT_PARTITIONS"    = tostring(var.glue_output_partitions)
          }
        }
        ResultPath = "$.glue"
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 10
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "RepairSilverPartitions"
      }

      RepairSilverPartitions = {
        Type     = "Task"
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        Parameters = {
          QueryString = "MSCK REPAIR TABLE ${aws_glue_catalog_table.silver.name}"
          WorkGroup   = aws_athena_workgroup.pipeline.name
          QueryExecutionContext = {
            Database = aws_glue_catalog_database.pipeline.name
          }
          ResultConfiguration = {
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        ResultPath = "$.repair"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "CleanupExistingGold"
      }

      CleanupExistingGold = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.cleanup_gold.arn
          Payload = {
            "gold_prefix.$" = "$.check.Payload.gold_prefix"
          }
        }
        ResultPath = "$.cleanup"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "RegisterGoldPartition"
      }

      RegisterGoldPartition = {
        Type     = "Task"
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        Parameters = {
          "QueryString.$" = "$.check.Payload.gold_partition_query"
          WorkGroup       = aws_athena_workgroup.pipeline.name
          QueryExecutionContext = {
            Database = aws_glue_catalog_database.pipeline.name
          }
          ResultConfiguration = {
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        ResultPath = "$.gold_partition"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "SilverToGold"
      }

      SilverToGold = {
        Type     = "Task"
        Resource = "arn:aws:states:::athena:startQueryExecution.sync"
        Parameters = {
          "QueryString.$" = "$.check.Payload.gold_insert_query"
          WorkGroup       = aws_athena_workgroup.pipeline.name
          QueryExecutionContext = {
            Database = aws_glue_catalog_database.pipeline.name
          }
          ResultConfiguration = {
            OutputLocation = "s3://${aws_s3_bucket.data_lake.id}/athena/results/"
          }
        }
        ResultPath = "$.gold_query"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "QualityCheck"
      }

      QualityCheck = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.quality_check.arn
          Payload = {
            "gold_prefix.$" = "$.check.Payload.gold_prefix"
          }
        }
        ResultPath = "$.quality"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "NotifyFailure"
        }]
        Next = "QualityPassed"
      }

      QualityPassed = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.quality.Payload.ok"
          BooleanEquals = true
          Next          = "NotifySuccess"
        }]
        Default = "NotifyQualityFailure"
      }

      NotifySuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn  = aws_sns_topic.pipeline.arn
          Subject   = "Data pipeline SUCCESS"
          "Message.$" = "States.JsonToString($)"
        }
        End = true
      }

      NotifyQualityFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.pipeline.arn
          Subject     = "Data pipeline QUALITY FAILURE"
          "Message.$" = "States.JsonToString($)"
        }
        Next = "PipelineQualityFailed"
      }

      PipelineQualityFailed = {
        Type  = "Fail"
        Error = "GoldQualityCheckFailed"
        Cause = "Gold output was empty or invalid"
      }

      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.pipeline.arn
          Subject     = "Data pipeline FAILURE"
          "Message.$" = "States.JsonToString($)"
        }
        Next = "PipelineFailed"
      }

      PipelineFailed = {
        Type  = "Fail"
        Error = "PipelineTaskFailed"
        Cause = "One or more pipeline tasks failed"
      }
    }

  })
}