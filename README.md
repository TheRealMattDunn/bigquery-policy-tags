# Big Query Policy Tags Demo

## Introduction

[Google Cloud BigQuery](https://cloud.google.com/bigquery) has a feature which allows you to apply fine-grained access control to sensitive [columns using policy tags](https://cloud.google.com/bigquery/docs/column-level-security-intro).

This repository contains a Terraform POC demo for creating and applying a policy tag to a BigQuery table column to mask the data for specified users. For another set of users, the data is unmasked.

This is not end-to-end production-ready code, but instead can be used as inspiration for a more thought out implementation!
