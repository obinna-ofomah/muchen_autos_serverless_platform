resource "aws_lambda_function" "lambda" {
  function_name = "muchen_container_function"
  role          = aws_iam_role.lambda_ex_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_ecr.repository_url}:latest"
  depends_on = [aws_ecr_repository.lambda_ecr]


  memory_size = 1024
  timeout     = 180

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.lambda_rds.address
    }
  }

  architectures = ["x86_64"] # Graviton support for better price/performance
}

resource "aws_lambda_permission" "with_s3" {
  statement_id  = "AllowS3TriggerEvent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_lake.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_lake.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "muchen_source_data/"
  }

  depends_on = [aws_lambda_permission.with_s3]
}
