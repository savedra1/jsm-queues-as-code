########################### BACKEND CONFIG ####################################################
// This is where the state file and jira/aws credentials are defined
// Please do not make any changes to this section

terraform {
  backend "s3" {
    bucket = var.S3_STATE_BUCKET_NAME
    key    = "prod/terraform.tfstate" // This can be set as a variable or hardcoded as necessary
    region = "eu-west-1" // This can either be set as another variable or hardcoded to any other region
  }

  required_providers { // Importing the fourplusone terraform module
    jira = {
      source = "fourplusone/jira" 
      version = "0.1.16"
    }
  }
}

provider "jira" {
  url = var.JIRA_ENDPOINT // Can also be set using the JIRA_URL environment variable when runnning locally
  user = var.JIRA_USERNAME // Can also be set using the JIRA_USER environment variable when runnning locally
  password = var.JIRA_API_KEY // Can also be set using the JIRA_PASSWORD environment variable when runnning locally
}

#################################################################################################
########### EXAMPLE FILTERS BELOW ####
#################################################################################################


// EXAMPLE Management Queue
resource "jira_filter" "management_queue" {
  name = "TEST: Management Queue" # THIS IS WHAT THE FILTER WILL BE CALLED WHEN CREATED IN JIRA
  jql =  <<EOF
    type != "[TEST] Device Wipe" 
    AND (
      "TEST: Competencies" = Management 
      AND status not in (Resolved, "Write Off Complete") 
      OR 
      type = "[TEST] Hardware Returns" 
      AND "TEST: Labels" = Escalated 
      AND status in (Escalated)
    ) 
    ORDER BY status, updated DESC
      EOF

  // Optional Fields
  description = "TEST queue logic for Management"
  favourite = false

  // View permissions only
  permissions {
    type = "project"
    project_id = var.PROJECT_ID
  }
}

// EXAMPLE Triage queue
resource "jira_filter" "triage_queue" {
  name = "TEST: Triage Queue" # THIS IS WHAT THE FILTER WILL BE CALLED WHEN CREATED IN JIRA
  jql =  <<EOF
    (
      status = "Waiting for Triage" 
      AND "TEST: Support & Password Requests" in cascadeOption("I need support with") 
      AND type = "[TEST] Support/Password & Project Requests" 
      AND Level not in ("Foyer Support Analyst") 
      OR 
      status = "Waiting for Triage" 
      AND "TEST: Support Type" = "I need support" 
      AND type = "[TEST] Support/Password & Project Requests" 
      AND Level not in ("Foyer Support Analyst") 
      OR 
      status = "Waiting for Triage" 
      AND "TEST: Support & Password Requests" in cascadeOption(none) 
      AND "TEST: Support Type" = EMPTY 
      AND type = "[TEST] Support/Password & Project Requests"
    ) 
    AND (
      "TEST: Team Required" is EMPTY 
      OR 
      "TEST: Team Required" = "Tech Support"
    ) 
    AND "TEST: File Migration Request" is EMPTY 
    AND "TEST: External Request" is EMPTY 
    AND "Customer Request Type" != "[Test] Virtual Agent Support (TEST)" 
    AND (
      "TEST: General Support Request" != Zscaler 
      OR 
      "TEST: General Support Request" is EMPTY
    ) 
    ORDER BY "TEST: Priority", created ASC
      EOF

  // Optional Fields
  description = "TEST queue logic for Triage"
  favourite = false

  // View permissions only
  permissions {
    type = "project"
    project_id = var.PROJECT_ID
  }
}

// EXAMPLE Passwords queue
resource "jira_filter" "passwords_queue" {
  name = "TEST: Passwords Queue" # THIS IS WHAT THE FILTER WILL BE CALLED WHEN CREATED IN JIRA
  jql =  <<EOF
    status not in (Resolved, "With Customer") 
    AND issuetype = "[TEST] Support/Password & Project Requests" 
    AND "TEST: Support Type" = "I need a password reset" 
    AND (
      "TEST: Team Required" is EMPTY 
      OR "TEST: Team Required" = "Tech Support"
    ) 
    ORDER BY Updated ASC
      EOF

  // Optional Fields
  description = "TEST queue logic for Passwords"
  favourite = false

  // View permissions only
  permissions {
    type = "project"
    project_id = var.PROJECT_ID
  }
}

// EXAMPLE Escalations queue
resource "jira_filter" "escalations_queue" {
  name = "TEST: Escalations Queue"
  jql =  <<EOF
    "TEST: Labels" = customerescalation 
    AND status not in (Resolved, Cancelled) 
    AND (
      "TEST: Team Required" = "Tech Support" 
      OR 
      "TEST: Team Required" is EMPTY
    ) 
    AND "TEST:  File Migration Request" is EMPTY 
    ORDER BY "TEST: Escalation Priority", "Escalation: Time to first response"
      EOF

  // Optional Fields
  description = "TEST queue logic for Escalations"
  favourite = false

  // View permissions only
  permissions {
    type = "project"
    project_id = var.PROJECT_ID
  }
}

// EXAMPLE Access queue
resource "jira_filter" "access_queue" {
  name = "TEST: Access Queue"
  jql =  <<EOF
    status not in (Resolved, "With Customer", "Authoriser Approval") 
    AND type = "[TEST] Access" 
    AND (
      "TEST: Team Required" is EMPTY 
      OR 
      "TEST: Team Required" = "Tech Support"
    ) 
    AND (
      "TEST: Access Requests" not in ("existing system access extension") 
      OR 
      "TEST: Access Requests" = EMPTY
    ) 
    AND (
      "TEST: Access Requests (Multi-Select)" not in ("existing system access extension", Zscaler) 
      OR 
      "TEST: Access Requests (Multi-Select)" = EMPTY
    ) 
    ORDER BY Status DESC, Updated ASC
      EOF

  // Optional Fields
  description = "TEST queue logic for Access"
  favourite = false

  // View permissions only
  permissions {
    type = "project"
    project_id = var.PROJECT_ID
  }
}


############# BACK HOLE QUEUE TO BE UPDATED EACH TIME A NEW FILTER IS ADDED #############

// EXAMPLE Filter to monitor issues that have gotten lost
resource "jira_filter" "blackhole_monitor" {

  name = "TEST: Blackhole Monitor"
  jql  =  <<EOF
    filter not in (
      "${jira_filter.management_queue.name}", 
      "${jira_filter.triage_queue.name}",
      "${jira_filter.passwords_queue.name}",
      "${jira_filter.escalations_queue.name}",
      "${jira_filter.access_queue.name}",
    )        
      EOF

  // Optional Fields
  description = "TEST queue logic for for the Blackhole monitor queue."
  favourite   = false

  // View permissions only ALWAYS KEEP THE SAME
  permissions {
    type       = "project"
    project_id = var.PROJECT_ID
  }
}

