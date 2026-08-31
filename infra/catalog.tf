# DB 생성, silver, gold 테이블 생성
resource "aws_glue_catalog_database" "pipeline" {
  # "-" => "_" 교체
  name = local.glue_database_name
}

# Glue가 생성한 Silver Parquet 데이터를 Athena에서 조회할 External Table
resource "aws_glue_catalog_table" "silver" {
  name          = local.silver_table_name
  database_name = aws_glue_catalog_database.pipeline.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL       = "TRUE"
    classification = "parquet"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.id}/silver/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "event_id"
      type = "string"
    }
    columns {
      name = "occurred_at"
      type = "timestamp"
    }
    columns {
      name = "sensor_id"
      type = "string"
    }
    columns {
      name = "temperature"
      type = "double"
    }
    columns {
      name = "humidity"
      type = "double"
    }
    columns {
      name = "status"
      type = "string"
    }
    columns {
      name = "source_topic"
      type = "string"
    }
    columns {
      name = "kafka_partition"
      type = "int"
    }
    columns {
      name = "kafka_offset"
      type = "bigint"
    }
    columns {
      name = "vector_ingest_at"
      type = "timestamp"
    }
    columns {
      name = "temperature_alert"
      type = "boolean"
    }
    columns {
      name = "humidity_alert"
      type = "boolean"
    }
    columns {
      name = "processed_at"
      type = "timestamp"
    }
  }

  # S3의 Hive 스타일 year/month/day/hour 경로를 Athena 파티션으로 사용한다.
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Silver를 센서별/시간별로 집계한 Gold Parquet 데이터를 조회할 External Table
resource "aws_glue_catalog_table" "gold" {
  name          = local.gold_table_name
  database_name = aws_glue_catalog_database.pipeline.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL       = "TRUE"
    classification = "parquet"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.id}/gold/sensor_hourly/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "sensor_id"
      type = "string"
    }
    columns {
      name = "event_count"
      type = "bigint"
    }
    columns {
      name = "avg_temperature"
      type = "double"
    }
    columns {
      name = "avg_humidity"
      type = "double"
    }
    columns {
      name = "max_temperature"
      type = "double"
    }
    columns {
      name = "max_humidity"
      type = "double"
    }
    columns {
      name = "high_temperature_count"
      type = "bigint"
    }
    columns {
      name = "high_humidity_count"
      type = "bigint"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
  partition_keys {
    name = "hour"
    type = "string"
  }
}
