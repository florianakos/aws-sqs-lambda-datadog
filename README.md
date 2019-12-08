# DataDog - AWS integration projec

This is a small PoC project that integrates AWS Lambda with Datadog. The basic idea is that some service or job running in the cloud will save a json file to a certain S3 bucket, which contains statistics about the job itself. This file should be parsed and the relevant metrics forwarded to DataDog to display in graphs (and possibly alert on anomalies).

This project has two AWS lambda functions working together: one generates and stores fake statistics to the chosen bucket, the other picks up and submits the contained metrics to DataDog via its API. 
