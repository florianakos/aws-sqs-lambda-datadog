from random import randint
import boto3
import json
import time

def handler(event, context):
    # create S3 resource object
    s3_client = boto3.resource('s3')
    # select S3 bucklet and upload JSON content to the specified file key
    s3_client.Bucket('gm-monitoring').put_object(Key='component=gfc/subComponent=tls/date=20191214/metric.json', Body=json.dumps({
        "timestamp":      int(time.time()),
        "sample.stats":   randint(0, 1000),
        "processed.data": randint(0, 100)
    }))
    # print log message about new file
    print("New file uploaded to s3 bucket...")
