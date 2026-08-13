"""
process_upload: triggered by an S3 upload event, reads the object,
records basic metadata back to the same bucket under a metadata/
prefix. Deliberately simple, real application logic is not the point
of this environment, its IAM role, network placement, and the data it
touches are.

This function only ever needs s3:GetObject and s3:PutObject scoped to
the uploads bucket. The role it actually runs under
(terraform/iam.tf's lambda_process_upload role) grants full S3 access
across every bucket in the account instead, the seeded finding Chain A,
Project 1 exists to find and fix using real CloudTrail data showing
this function never calls anything beyond GetObject and PutObject.
"""

import json
import logging
import os
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

BUCKET_NAME = os.environ.get("UPLOADS_BUCKET", "")


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        logger.info("Processing s3://%s/%s", bucket, key)

        obj = s3.get_object(Bucket=bucket, Key=key)
        size_bytes = obj["ContentLength"]

        metadata = {
            "source_key": key,
            "size_bytes": size_bytes,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

        metadata_key = f"metadata/{key}.json"
        s3.put_object(
            Bucket=bucket,
            Key=metadata_key,
            Body=json.dumps(metadata).encode("utf-8"),
            ContentType="application/json",
        )

        logger.info("Wrote metadata to s3://%s/%s", bucket, metadata_key)

    return {"statusCode": 200, "processed": len(event.get("Records", []))}
