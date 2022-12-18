variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:3f2e9437244c1a12c44131e1766c9d1cd6aefedc"
}

variable "bucket_name" {
  default = "bingoapp-terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}