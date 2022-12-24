variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:56292dfa9d6e73cafc5e084cfa5df0acbef04929"
}

variable "bucket_name" {
  default = "bingoapp-terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}