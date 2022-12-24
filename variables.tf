variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:839f32f75f116294639a8845862574da4b12a74a"
}

variable "bucket_name" {
  default = "bingoapp-terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}