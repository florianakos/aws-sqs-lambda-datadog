import json
import csv
import gzip
import boto3
import os
import time
from random import randint

from datadog import initialize as ddg_init
from datadog import api as dd_api
from base64 import b64decode



DDG_API_KEY = boto3.client('kms').decrypt(CiphertextBlob=b64decode(os.environ['DDG_API_KEY']))['Plaintext']
DDG_APP_KEY = boto3.client('kms').decrypt(CiphertextBlob=b64decode(os.environ['DDG_APP_KEY']))['Plaintext']

def handler(event, context):
    # print(json.dumps(event, indent=4, sort_keys=True))
    sqs_msg_body = json.loads(event["Records"][0]["body"])

    # test if the received message is the standard test event which comes when new infra is set up
    if "Event" in sqs_msg_body.keys() and sqs_msg_body["Event"] == "s3:TestEvent":
        print("Bucket test event")
        return

    # get the filename from the message body
    s3_file_name = sqs_msg_body["Records"][0]["s3"]["object"]["key"]

    # fetch the file from S3 that was just uploaded
    s3_client  = boto3.client('s3')
    s3_file = s3_client.get_object(Bucket = 'gm-monitoring', Key=s3_file_name)
    jsonData = json.loads(s3_file["Body"].read().decode('utf-8'))

    # print(jsonData)
    # datadog initialization options
    ddg_options = { 'api_key': DDG_API_KEY,
                    'app_key': DDG_APP_KEY,
                    'api_host': 'https://api.datadoghq.eu'}
    # init the local datadog agent
    ddg_init(**ddg_options)

    for metric_name in jsonData:
        # submit a metric for each field other than the timestamp
        if metric_name != 'timestamp':
            # add some random noise just for testing
            noise = randint(0, 100)
            # prepare data to be submitted for current metric
            data = (int(time.time()), jsonData[metric_name] + noise)
            # print log messages
            print("  sending to DataDog: " + metric_name + ": " + str(jsonData[metric_name] + noise))
            # send datadog API metric data with timestamp
            resp = dd_api.Metric.send(metric=metric_name, type='count', points=data , tags=["environment:dev"])
            print(resp)
