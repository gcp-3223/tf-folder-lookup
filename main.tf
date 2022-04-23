# Copyright 2021 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())


  path = "${path.module}/../.."

  sa_org_roles = [
    "roles/resourcemanager.folderViewer",
    "roles/viewer",
  ]
}


provider "google" {
  # Since this will be executed from cloud-shell for credentials use
  # gcloud auth application-default login

  project = var.project
  region  = var.region
}

# API's and IAM
#...............................................................................
module "project_services" {
  source = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id = var.project

  activate_apis = [
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "sourcerepo.googleapis.com",
    "appengine.googleapis.com"
  ]
}


resource "google_service_account" "folder_lookup_sa" {
  account_id   = var.sa_name
  display_name = "Folder Lookup SA"

  depends_on = [module.project_services]
}


resource "null_resource" "service_accounts" {
  depends_on = [
    module.project_services,
    resource.google_service_account.folder_lookup_sa
  ]
}


resource "google_project_iam_member" "folder_lookup_sa_role_1" {
  project    = var.project
  role       = "roles/iam.serviceAccountUser"
  member     = "serviceAccount:${resource.google_service_account.folder_lookup_sa.email}"
  depends_on = [resource.null_resource.service_accounts]
}


resource "google_project_iam_member" "folder_lookup_sa_role_2" {
  project    = var.project
  role       = "roles/bigquery.admin"
  member     = "serviceAccount:${resource.google_service_account.folder_lookup_sa.email}"
  depends_on = [resource.null_resource.service_accounts]
}


resource "google_project_iam_member" "folder_lookup_sa_role_3" {
  project    = var.project
  role       = "roles/pubsub.admin"
  member     = "serviceAccount:${resource.google_service_account.folder_lookup_sa.email}"
  depends_on = [resource.null_resource.service_accounts]
}




resource "null_resource" "project_iam" {
  depends_on = [
    resource.google_project_iam_member.folder_lookup_sa_role_1,
    resource.google_project_iam_member.folder_lookup_sa_role_2,
    resource.google_project_iam_member.folder_lookup_sa_role_3,
  ]
}


resource "google_organization_iam_member" "org_iam" {
  count = length(local.sa_org_roles)

  org_id = var.org
  role   = local.sa_org_roles[count.index]
  member = "serviceAccount:${resource.google_service_account.folder_lookup_sa.email}"

  depends_on = [module.project_services, resource.null_resource.service_accounts]
}


# Bigquery
#...............................................................................
resource "google_bigquery_dataset" "folderlookupdataset" {
  dataset_id = var.bqdataset

  depends_on = [module.project_services,
    resource.google_organization_iam_member.org_iam,
    resource.null_resource.project_iam,
  ]
}

resource "google_bigquery_table" "folderlookuptable" {
  dataset_id = google_bigquery_dataset.folderlookupdataset.dataset_id
  table_id   = var.bqtable

  time_partitioning {
    type = "DAY"
  }

  schema = <<EOF
  [
      {
          "name": "id",
          "type": "STRING",
          "mode": "REQUIRED"
      },
      {
          "name": "name",
          "type": "STRING",
          "mode": "REQUIRED"
      },
      {
          "name": "level",
          "type": "INTEGER",
          "mode": "REQUIRED"
      },
      {
          "name": "parent",
          "type": "STRING",
          "mode": "REQUIRED"
      }
  ]
EOF

  depends_on          = [resource.google_bigquery_dataset.folderlookupdataset]
  deletion_protection = false
}

#PubSub
#..............................................................................

resource "google_pubsub_topic" "folderLookuptopic" {
  name                 = var.pubsubtopic
  depends_on           = [module.project_services]
}


# Cloud Functions
#...............................................................................

resource "google_cloudfunctions_function" "function-folderLookup" {
 name        = var.cloud_function_folder_lookup
 description = var.cloud_function_folder_desc
 runtime     = var.cloud_function_runtime

 source_archive_bucket  = var.source_code_bucket_name
 source_archive_object  = var.source_code_zip

 event_trigger          {
   event_type           = "providers/cloud.pubsub/eventTypes/topic.publish"
   resource             = var.pubsubtopic
   failure_policy {
      retry = true
    }
 }

 entry_point            = "Dump"
 service_account_email  = resource.google_service_account.folder_lookup_sa.email
 depends_on             = [module.project_services]

 environment_variables  = {
   ROOT                 = "organizations/${var.org}"
   MAX_DEPTH            = "4"
   DATASET              = var.bqdataset
   TABLE                = var.bqtable
   PROJECT              = var.project

 }
}


# Scheduler
#...............................................................................
resource "google_cloud_scheduler_job" "scheduler" {

  depends_on = [module.project_services,
    resource.google_organization_iam_member.org_iam,
    resource.null_resource.project_iam,
  ]

  name        = "folderLookup-job"
  description = "folderLookup-job"
  schedule    = "*/10 * * * *"

  pubsub_target {
    topic_name = "projects/${var.project}/topics/${var.pubsubtopic}"
    data       = base64encode("message")
  }

}
