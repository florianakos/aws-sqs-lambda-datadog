import json
import csv
import gzip
import boto3
import requests

def handler(event, context):
    # verify that URL is passed correctly and create file_name variable based on it
    if 'org_name' not in event.keys():
      print("Missing 'org_name' from request body (JSON)!")
      return
    file_name = event["org_name"]+'_github_repos.csv.gz'

    # verify that target bucket name is passed correctly and create local variable
    if 'target_bucket' not in event.keys():
      print("Missing 'target_bucket' from request body (JSON)!")
      return
    target_bucket_name = event["target_bucket"]

    # send Github API request
    print("URL validated! Selected organization: " + event["org_name"])
    print("Sending Github API request... ")
    resp = requests.get("https://api.github.com/orgs/" + event["org_name"] + "/repos?type=all")
    data = resp.json()
    if resp.status_code != 200:
        print("Organization not found")
        return

    # Store response in Gzipped CSV file
    print("Storing organization repos in gzipped CSV (in local /tmp folder) ... ")
    with gzip.open('/tmp/'+file_name, 'wb') as gzipf:
            gzipf.write(str.encode("id,description,html_url\n"))
            for d in data:
                if d["description"] == None:
                    gzipf.write(str.encode(str(d["id"])+","+"NONE"+","+d["html_url"]+"\n"))
                else:
                    gzipf.write(str.encode(
                                        str(d["id"])+","
                                        +d["description"].translate({ord(','): None, ord(';'): None})+","
                                        +d["html_url"]+"\n"))

    # handle the upload from local /tmp folder to S3 bucket
    print("Uploading gzipped CSV to S3 bucket () ...")
    s3 = boto3.client("s3")
    s3.upload_file('/tmp/'+file_name, target_bucket_name, file_name)


    # try to read a message from SQS queue
    # print("Trying to receive from SQS...")
    # sqs = boto3.client('sqs')
    # resp_url = sqs.get_queue_url(QueueName='cisco-prague-queue', QueueOwnerAWSAccountId='546454927816')
    # rcv_msg = sqs.receive_message(
    #     QueueUrl=resp_url["QueueUrl"],
    #     MaxNumberOfMessages=1,
    #     MessageAttributeNames=['All'],
    #     VisibilityTimeout=0,
    #     WaitTimeSeconds=0
    # )
    # message = rcv_msg['Messages'][0]
    # receipt_handle = message['ReceiptHandle']

    # # Delete received message from queue
    # sqs.delete_message(
    #     QueueUrl=resp_url["QueueUrl"],
    #     ReceiptHandle=receipt_handle
    # )
    # print('Received and deleted message: %s' % message)
