# One password per participant, shared by all the nodes of the stack.
resource "random_string" "student" {
  length  = 12
  special = false
}
