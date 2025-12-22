# redis subnet:
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

# redis sg:
resource "aws_security_group" "redis_sg" {
  name   = "redis-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# redis instance:
resource "aws_elasticache_replication_group" "redis_cart" {
  count = var.memorystore ? 1 : 0

  replication_group_id = "redis-cart"
  description          = "Redis for cart service"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t3.micro"
  port                 = 6379

  num_cache_clusters   = 1

  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis_sg.id]

  automatic_failover_enabled = false
}


