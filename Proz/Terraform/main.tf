resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Proz_VPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public_Subnet-1"
  }
}

resource "aws_subnet" "subnet4" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "public-subnet-2"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private_Subnet-1"
  }
}
resource "aws_subnet" "subnet3" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "private_Subnet-2"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Proz_IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Proz_Public_RT"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc4" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "private_rt"
  }
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "Proz_NAT_EIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet1.id
  tags = {
    Name = "Proz_NAT_GW"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "private_rt_assoc1" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_rt_assoc2" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "sg" {
  name        = "Proz_SG"
  description = "Security group for Proz VPC"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#RDS

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "proz-db-subnet-group"
  subnet_ids = [aws_subnet.subnet2.id, aws_subnet.subnet3.id]

  tags = {
    Name = "Proz_DB_Subnet_Group"
  }
}

resource "aws_db_instance" "db_instance" {
  identifier             = "proz-db-instance"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "prozdb"
  username               = "admin"
  password               = "Admin123!"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  tags = {
    Name = "mySQLRDS"
  }
}

# ALB

resource "aws_lb" "ALB" {
  name               = "ProzALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet4.id]
}

# target Group

resource "aws_alb_target_group" "frontend_target_group" {
  name        = "FrontendTG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_target_group" "backend_target_group" {
  name        = "BackendTG"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.frontend_target_group.arn
  }
}

resource "aws_lb_listener_rule" "listener_rule" {
  listener_arn = aws_lb_listener.frontend_listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.backend_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}


#ECR

resource "aws_ecr_repository" "frontend_ecr" {
  name = "frontend-repo"
}

resource "aws_ecr_repository" "backend_ecr" {
  name = "backend-repo"
}

# ECS Cluster

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "Proz_ECS_Cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "my-log-group" {
  name              = "/ecs/my-ecs-cluster"
  retention_in_days = 7
  tags = {
    Name = "myECSLogGroup"
  }
}

# IAM Role for ECS Task Execution

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# ECS Task Definitions

resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-container"
      image     = "${aws_ecr_repository.frontend_ecr.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      cpu    = 256
      memory = 512
      linuxParameters = {
        initProcessEnabled = true
      },

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.my-log-group.name,
          awslogs-region        = "us-east-1",
          awslogs-stream-prefix = "frontend-log"
        }
      }
    }

  ])
}

resource "aws_ecs_task_definition" "backend_task" {
  family                   = "backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend-container"
      image     = "${aws_ecr_repository.backend_ecr.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      cpu    = 256
      memory = 512
      environment = [
        {
          name  = "DATABASE_ENDPOINT",
          value = aws_db_instance.db_instance.address
        },
        {
          name  = "DATABASE_USER",
          value = aws_db_instance.db_instance.username
        },
        {
          name  = "DATABASE_PASSWORD",
          value = aws_db_instance.db_instance.password
        },
        {
          name  = "FRONTEND_URL",
          value = "http://${aws_lb.ALB.dns_name}"
        }
      ]
      linuxParameters = {
        initProcessEnabled = true
      },
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.my-log-group.name,
          awslogs-region        = "us-east-1",
          awslogs-stream-prefix = "backend-log"
        }
      }
    }
  ])
}

# ECS Services  

resource "aws_ecs_service" "frontend_service" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.subnet2.id, aws_subnet.subnet3.id]
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.frontend_target_group.arn
    container_name   = "frontend-container"
    container_port   = 80
  }
}

resource "aws_ecs_service" "backend_service" {
  name            = "backend_service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.subnet2.id, aws_subnet.subnet3.id]
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.backend_target_group.arn
    container_name   = "backend-container"
    container_port   = 3000
  }
}
