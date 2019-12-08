from random import randint
import boto3
import json
import time

def handler(event, context):
    s3_client = boto3.resource('s3')
    s3_client.Bucket('gm-monitoring').put_object(Key='data.json', Body=json.dumps({
        "timestamp":      int(time.time()),
        "sample.stats":   randint(0, 1000),
        "processed.data": randint(0, 100)
    }))
    print("New file uploaded to s3 bucket...")
