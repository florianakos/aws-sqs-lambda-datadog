# DataDog - AWS integration projec

This is a small PoC project that integrates AWS Lambda with Datadog. The basic idea is that some service or job running in the cloud will save a json file to a certain S3 bucket, which contains statistics about the job itself. This file should be parsed and the relevant metrics forwarded to DataDog to display in graphs (and possibly alert on anomalies).

This project has two AWS lambda functions working together: one generates and stores fake statistics to the chosen bucket, the other picks up and submits the contained metrics to DataDog via its API.

## Deploy

The project is set up to use Terraform for deploying to AWS. For this reason one needs to set up the proper credentials in `~/.aws/credentials` to be able to execute the `terraform apply`.

### Step 1: Python dependencies

Since the project relies on the `datadog` python package to submit metrics via the DataDog API, we will need to package the dependency with the source code. To do this follow the below code snippet:

```bash
# For the DataDog Metric Submit function
pip install --target ./package datadog
cd package
zip -r9 ${OLDPWD}/ddg_metric_submit.zip .
cd $OLDPWD
zip -g ddg_metric_submit.zip ddg_metric_submit.py

# For the Mock Data source generator
zip ddg_mock_datasource.zip ddg_mock_datasource.py
```
