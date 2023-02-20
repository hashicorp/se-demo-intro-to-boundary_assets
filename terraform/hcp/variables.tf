# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: Apache-2.0

variable "create_boundary" {
  type = bool
  default = true
}

variable "unique_name" {
  type = string
}

variable "boundary_admin_login" {
  type = string
  default = "admin"
}
