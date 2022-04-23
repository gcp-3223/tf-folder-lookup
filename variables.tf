/*
Copyright 20210 Google LLC
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

variable "sa_name" {
  description = "Value that will be used for SA creation etc."
  type        = string
  default     = "safolderlookup"
}

variable "org" {
  description = "Value of the Org Id to deploy the solution"
  type        = string
}

variable "project" {
  description = "Value of the Project Id to deploy the solution"
  type        = string
}

variable "region" {
  description = "Value of the region to deploy the solution."
  type        = string
}


variable "cloud_function_folder_lookup" {
  description = "Cloud Functions name for folder lookup"
  type        = string
  default     = "folderLookup"
}

variable "cloud_function_folder_desc" {
  description = "Cloud Functions description for folder lookup"
  type        = string
  default     = "Collect folder names and IDs"
}

variable "cloud_function_runtime" {
  description = "Cloud Functions runtime"
  type = string
  default = "go113"
}

variable "source_code_bucket_name" {
  description = "Cloud storage bucket name to download source code for Cloud Functions"
  type        = string
  default     = "public-folder-lookup"
}

variable "source_code_zip" {
  description = "Cloud storage object with source code for Cloud Functions"
  type        = string
  default     = "folder-lookup-master.zip"
}

variable "bqdataset" {
  description = "Name of BQ dataset"
  type        = string
  default     = "folderlookupdataset"
}

variable "bqtable" {
  description = "Name of BQ table"
  type        = string
  default     = "folderlookuptable"
}


variable "pubsubtopic" {
  description = "Name of PubSub topic"
  type        = string
  default     = "folderlookuptopic"
}
