output "website_name" {
  description = "Name displayed for the public website EC2 instance in AWS"
  value       = "Nurudeen Website"
}

output "website_public_ip" {
  description = "Stable Elastic IP address of the public website"
  value       = aws_eip.website.public_ip
}

output "website_url" {
  description = "URL for the public website"
  value       = "http://${aws_eip.website.public_ip}"
}

output "middle_tier_private_ip" {
  description = "Private IP address of the middle-tier instance"
  value       = aws_instance.middle.private_ip
}
