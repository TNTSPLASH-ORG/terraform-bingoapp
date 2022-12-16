variable "image_bingoapp" {
  default = "982250989342.dkr.ecr.us-west-1.amazonaws.com/bingoapp:4e319de325008835c99699db7aaa47e2f2195958"
}

variable "bucket_name" {
  default = "terraform-state-bucket"
}

variable "site_name" {
  default = "simonsbingo.com"
}