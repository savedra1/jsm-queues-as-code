# Jira Service Management Queues as Code
If you use JSM and find your project's queue logic is becoming more and more complex, have ever found yourself updating logic to find a load of tickets missing or just generally want better visibility and auditability of your queues, this solution may be of interest! 

The Jira Cloud REST API, along with Terraform and AWS S3 is used here to facilitate a version-controlled, "infrastructure as code" approach to defining the queues used for a JSM project. Github Actions is also utilised to automate and test the Terraform deployment before making the changes to your Jira instance. The use of Github Actions also ensures extensive visibility for stakeholders and easy version controlling capabilities.

### Why take this approach? 
JSM does not provide any native tooling for version controlling of Service Desk queue logic, making it prone to accidents arising from changes. Having the queues defined in this way allows for easy disaster recovery and monitoring of the business logic in use. This can also be used to further simplify queue-based automations and identify "black holes". Storing your JQL in this way also has the added benefit of allowing a much more user-friendly visualisation of the queries compared to what's natively offered from Atlassian.

### How it works
The [fourplusone](https://github.com/fourplusone/terraform-provider-jira) Terraform module _(shout out to those guys)_ is being utilised here to define JQL filter objects in the /filters/main.tf file. Due to the credentials used for the Jira provider, only one service account is able to edit the filters, however, all users within the related project are added as viewers. A state file hosted in AWS S3 is used meaning any changes to the existing filter resources will simply update the existing filters, and any removed resources will be destroyed. Once the filters have been created in the Jira instance, they will need to be added manually to the queues in the project, but any updates from then on would be fully automated through use of the project's Github Actions + Terraform CI pipeline. 

## Prerequisites
In order to set this up for yourself, you will need the following:
- A Jira user API key with permissions for creating, updating and deleting JQL filters in your instance.
- An existing AWS S3 bucket to be used to store the project's Terraform state.  
- And AWS CLI user with permissions to update, delete and read the S3 state bucket. Example permissions for this: 
```
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::{{YOUR_BUCKET_NAME}}",
                "arn:aws:s3:::{{YOUR_BUCKET_NAME}}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:AttachRolePolicy"
            ],
            "Resource": "*"
        }
    ]
  }
```

## Usage instructions
1. Create your remote Github repository that will be used to version control your queue logic. 

2. In your new remote repo, create an environment called `prod` and make sure your default branch is renamed to `main` if it isn't already.

3. Add the following repo secrets _(strings)_ to your `prod` environment: 
- `AWS_ACCESS_KEY_ID`: The access key for your AWS CLI user
- `AWS_SECRET_ACCESS_KEY`: The secret key for your AWS CLI user
- `S3_STATE_BUCKET_NAME`: The name of your S3 state bucket
- `JIRA_ENDPOINT`: The base URL of your Jira instance. E.g. _https://yourinstance.atlassian.net_
- `JIRA_USERNAME`: The email of the user associated with your Jira API key
- `JIRA_API_KEY`: The API key for your Jira user
- `PROJECT_ID`: The ID of your Jira Service Management project

4. Clone this repo: `git clone https://github.com/savedra1/jsm-queues-as-code.git` 

5. In the local `jsm-queues-as-code` repo, you can now add your project's filters found in the `filters/main.tf` file. **NOTE THAT THE EXISTING FILTERS IN THIS FILE ARE ONLY THERE AS EXAMPLES AND SHOULD BE REMOVED/UPDATED BEFORE APPLYING YOUR CHANGES**. To create a filter, you can follow this resource format: 
```
  resource "jira_filter" "name_of_terraform_resource" {

    name = "name_of_filter" # THIS IS WAS YOUR FILTER WILL BE CALLED IN JIRA ONCE CREATED

    jql =  <<EOF
      
      JQL GOES HERE 
        JQL to use for the Filter can be structured
          however you want when
            defined within
        the EOF function

        EOF

    // Optional Fields
    description = "description of filter"
    favourite = false

    // View permissions only - ALWAYS KEEP THE SAME TO ENSURE THE FILTER CANNOT BE UPDATED BY ANY OTHER USER LOCALLY
    permissions {
      type = "project"
      project_id = vars.PROJECT_ID
  }
  }
``` 

  An example filter for a project's _Passwords_ queue:
```
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
```
The JQL expression `filter = "TEST: Passwords Queue"` would then be added to the JSM queue manually once this resource had been created.
**It's also important to note here that the  backend config section of the `main.tf` file should not be changed. This would usually be kept in a separate Terraform file but this is not supported by the `fourplusone` module.**

6. Once you have added your filters, you can set the remote repo of your local `jsm-queues-as-code` folder to your new remote address and push your changes, triggering Github Actions. For example:
```
git remote set-url https://github.com/your-git-instance/your-repo
git checkout -b new-branch
git add .
git commit -m "Commit message"
git push -u origin new-branch
```

To view the progress of the Actions workflow, head into the Actions tab in your repo to view the logs. 

It is recommended to create a branch and push your changes from there, creating a pull request rather than pushing your changes directly to the `main` branch. On creation of a pull request, a GH Actions workflow defined in the project will trigger a `terraform plan` command that will comment the planned changes onto the PR, useful when needing an approval before the branch can be merged. 

When the branch is merged to `main`, the `terraform apply` command will be executed by GH Actions, creating/updating the filters in your instance. 

7. **The manual step**: Set the newly created filters as the logic for your JSM queues. The JQL syntax for this is very simple: 
```filter = "My filter name"```

### Updating existing filters
To update the JQL/config for any existing resources, simply update the JQL in the most recent version of the `main.tf` file and push your changes to the remote repo. When the `terraform apply` command executes, only the changes will be added. 

### Removing filters that were previously created
To delete any filter resources that are no longer required, simply remove the resource from the `main.tf` file and push your changes to the remote repo. When the `terraform apply` command is executed, any missing resources will be _destroyed_ from the instance.

