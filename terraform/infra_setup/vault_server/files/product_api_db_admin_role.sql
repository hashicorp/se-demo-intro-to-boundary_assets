-- Copyright (c) HashiCorp, Inc.
-- SPDX-License-Identifier: Apache-2.0

CREATE ROLE "{{name}}" WITH SUPERUSER LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';