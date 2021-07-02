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

  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  warehouse = snowflake_warehouse.warehouse.name

  name          = "employees_task"
  schedule      = "1 MINUTE"
  sql_statement = "INSERT INTO EMPLOYEES(LOAD_TIME) VALUES(CURRENT_TIMESTAMP);"

  user_task_timeout_ms = 10000
  enabled              = false
}

resource "snowflake_task" "task1" {
  comment = "employee_task"

  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  warehouse = snowflake_warehouse.warehouse.name

  name          = "employee_task"
  schedule      = "1 MINUTE"
  sql_statement = "INSERT INTO EMPLOYEES(LOAD_TIME) VALUES(CURRENT_TIMESTAMP);"

  user_task_timeout_ms = 10000
  enabled              = false
}

resource "snowflake_table" "tree_task_table_1" {
  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  name       = "EMPLOYEES"
  comment    = "A table for testing tree of tasks with terraform"

#   owner      = "TF_DEMO_SVC_ROLE"

  column {
    name = "id"
    type = "int"
  }

  column {
    name = "data"
    type = "text"
  }

  column {
    name = "DATE"
    type = "TIMESTAMP_NTZ(9)"
  }
}

resource "snowflake_table" "tree_task_table_2" {
  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  name       = "EMPLOYEES_COPY"
  comment    = "A table for testing tree of tasks with terraform"

#   owner      = "TF_DEMO_SVC_ROLE"

  column {
    name = "id"
    type = "int"
  }

  column {
    name = "data"
    type = "text"
  }

  column {
    name = "DATE"
    type = "TIMESTAMP_NTZ(9)"
  }
}

resource "snowflake_task" "parent_task" {
  comment = "testing tree of tasks with terraform, parent"

  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  warehouse = snowflake_warehouse.warehouse.name

  name          = "parent_task"
  schedule      = "1 MINUTE"
  sql_statement = "INSERT INTO EMPLOYEES VALUES(1, 'test', current_date());"

  user_task_timeout_ms = 10000
  enabled              = true
}

resource "snowflake_task" "child_task" {
  comment = "testing tree of tasks with terraform, child"

  database  = snowflake_database.db.name
  schema    = snowflake_schema.schema.name
  warehouse = snowflake_warehouse.warehouse.name

  name          = "child_task"
  sql_statement = "INSERT INTO EMPLOYEES_COPY SELECT * FROM EMPLOYEES;"

  user_task_timeout_ms = 10000
  after                = "parent_task"
  enabled              = true
}