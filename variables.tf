variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:ca32eb61f65c28ec97c3f465238358acc7c5b1ae"
}

variable "bucket_name" {
  default = "bingoapp-terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}