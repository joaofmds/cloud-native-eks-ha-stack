output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB criada"
  value       = aws_dynamodb_table.this.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB"
  value       = aws_dynamodb_table.this.arn
}

output "s3_bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3"
  value       = aws_s3_bucket.this.arn
}
output "s3_logging_bucket_name" {
  description = "Nome do bucket S3 para logs"
  value       = aws_s3_bucket.log_bucket.id
}