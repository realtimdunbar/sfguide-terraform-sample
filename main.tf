terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.22.0"
    }
  }
}

provider "snowflake" {
  role     = "SYSADMIN"
  region   = "us-east-1"
}

resource "snowflake_database" "db" {
  name = "TF_DEMO"
}

resource "snowflake_warehouse" "warehouse" {
  name           = "TF_DEMO"
  warehouse_size = "small"

  auto_suspend = 60
}

provider "snowflake" {
   alias    = "security_admin"
   role     = "SECURITYADMIN"
   region   = "us-east-1"
}
resource "snowflake_role" "role" {
   provider = snowflake.security_admin
   name     = "TF_DEMO_SVC_ROLE"
}
resource "snowflake_database_grant" "grant" {
   database_name = snowflake_database.db.name
   privilege = "USAGE"
   roles     = [snowflake_role.role.name]
   with_grant_option = false
}
resource "snowflake_schema" "schema" {
   database = snowflake_database.db.name
   name     = "TF_DEMO"
   is_managed = false
}
resource "snowflake_schema_grant" "grant" {
   database_name = snowflake_database.db.name
   schema_name   = snowflake_schema.schema.name
   privilege = "USAGE"
   roles     = [snowflake_role.role.name]
   with_grant_option = false
}
resource "snowflake_warehouse_grant" "grant" {
   warehouse_name = snowflake_warehouse.warehouse.name
   privilege      = "USAGE"
   roles = [snowflake_role.role.name]
   with_grant_option = false
}
resource "tls_private_key" "svc_key" {
   algorithm = "RSA"
   rsa_bits  = 2048
}
resource "snowflake_user" "user" {
   provider = snowflake.security_admin
   name     = "tf_demo_user"
   default_warehouse = snowflake_warehouse.warehouse.name
   default_role      = snowflake_role.role.name
   default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
   rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}
resource "snowflake_role_grants" "grants" {
   role_name = snowflake_role.role.name
   users     = [snowflake_user.user.name]
}
resource "snowflake_task" "task" {
  comment = "employees_task"

  database  = "demo_db"
  schema    = "public"
  warehouse = "compute_wh"

  name          = "employee_task"
  schedule      = "1"
  sql_statement = "INSERT INTO EMPLOYEES_COPY(EMPLOYEE_ID, EMPLOYEE_NAME, LOAD_TIME) SELECT * FROM EMPLOYEES;"

  user_task_timeout_ms = 10000
  enabled              = true
}