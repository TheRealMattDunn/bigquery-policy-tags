## Variables and locals
variable "project_id" {
  type = string
}

variable "masked_reader" {
  type        = string
  description = "Member who can view masked PII data. Include 'group:', 'user:' etc."
}

variable "fine_grained_reader" {
  type        = string
  description = "Member who can view unmasked PII data. Include 'group:', 'user:' etc."
}

locals {
  region = "europe-west2"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

## Bucket - to store test data
resource "google_storage_bucket" "bucket" {
  name                        = "policy_tags_test_${random_id.bucket_suffix.hex}"
  location                    = local.region
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "data" {
  name   = "policy_tags_test.csv"
  bucket = google_storage_bucket.bucket.name

  ## CSV file - test data
  content = <<-EOF
    foo, bar
    hello, world
  EOF
}

## BigQuery dataset and table
resource "google_bigquery_dataset" "policy_tags_test_dataset" {
  dataset_id                 = "policy_tags_test_dataset"
  location                   = local.region
  delete_contents_on_destroy = true
}

resource "google_bigquery_dataset_iam_binding" "reader" {
  dataset_id = google_bigquery_dataset.policy_tags_test_dataset.dataset_id
  role       = "roles/bigquery.dataViewer"

  members = [
    var.masked_reader,
    var.fine_grained_reader
  ]
}

resource "google_bigquery_table" "policy_tags_test_table" {
  dataset_id          = google_bigquery_dataset.policy_tags_test_dataset.dataset_id
  table_id            = "policy_tags_test_table"
  deletion_protection = false

  schema = jsonencode(
    [
      {
        name : "non_pii"
        type : "STRING"
      },
      {
        name : "pii"
        type : "STRING"
        policyTags : {
          names : [google_data_catalog_policy_tag.policy_tag.name]
        }
      }
    ]
  )
}

resource "random_id" "job_suffix" {
  byte_length = 4
}

resource "google_bigquery_job" "job_load" {
  job_id   = "job_load_${random_id.job_suffix.hex}"
  location = local.region

  load {
    source_uris = ["gs://${google_storage_bucket_object.data.bucket}/${google_storage_bucket_object.data.name}"]

    destination_table {
      project_id = google_bigquery_table.policy_tags_test_table.project
      dataset_id = google_bigquery_table.policy_tags_test_table.dataset_id
      table_id   = google_bigquery_table.policy_tags_test_table.table_id
    }
  }
}

## Taxonomy, policy tag, and IAM bindings
resource "google_data_catalog_taxonomy" "taxonomy" {
  region       = local.region
  display_name = "taxonomy"
}

resource "google_data_catalog_policy_tag" "policy_tag" {
  display_name = "Policy Tag"
  taxonomy     = google_data_catalog_taxonomy.taxonomy.id
}

resource "google_bigquery_datapolicy_data_policy" "data_policy" {
  location         = local.region
  data_policy_id   = "data_policy"
  policy_tag       = google_data_catalog_policy_tag.policy_tag.name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "SHA256"
  }
}

# roles/bigquerydatapolicy.maskedReader allows members to view the data, but masked
resource "google_bigquery_datapolicy_data_policy_iam_binding" "masked_readers" {
  location       = local.region
  data_policy_id = google_bigquery_datapolicy_data_policy.data_policy.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  members        = [var.masked_reader]
}

# roles/datacatalog.categoryFineGrainedReader allows members to view the unmasked data
resource "google_data_catalog_policy_tag_iam_binding" "fine_grained_readers" {
  policy_tag = google_data_catalog_policy_tag.policy_tag.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  members    = [var.fine_grained_reader]
}