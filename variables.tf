variable "aws_region" {
  description = "AWS region to deploy the website in"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone used for both application tiers"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type used by both application tiers"
  type        = string
  default     = "t3.micro"
}
