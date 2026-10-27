locals {
  USER_ID = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID  = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix  = "${local.USER_ID}_${local.ENV_ID}_${var.prefix}"
}
