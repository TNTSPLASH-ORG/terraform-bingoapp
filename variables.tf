variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:3791ee3d8210fa6bb4521f935af7dd733b3d1b98"
}

variable "bucket_name" {
  default = "bingoapp-terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}