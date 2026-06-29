resource "aws_db_instance" "lambda_rds" {
  allocated_storage   = 10
  db_name             = "obinnadb"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  username            = "obinna"
  password            = "password"
  skip_final_snapshot = true
  port                = 5432
  publicly_accessible = false


  vpc_security_group_ids = [aws_security_group.rds_lambda_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.lambda_rds.name

  apply_immediately = true
}