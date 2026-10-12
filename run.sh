#!/bin/bash
set -euo pipefail

# Extract stack outputs and store them in variables
eval $(lstk aws cloudformation describe-stacks --stack-name PipesStreamingStack | jq -r '.Stacks | .[] | .Outputs | .[] | "\(.OutputKey)=\(.OutputValue)"')

echo "PipeName: $PipeName"
echo "SourceStreamName: $SourceStreamName"
echo "TargetStreamName: $TargetStreamName"
echo "DlqUrl: $DlqUrl"

MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}

# Happy path: a record should reach the target stream with the enrichment field
echo "Putting a record into the source stream"
lstk aws kinesis put-record \
  --cli-binary-format raw-in-base64-out \
  --stream-name "$SourceStreamName" \
  --data '{"fail":false}' \
  --partition-key my-partition-key > /dev/null

SHARD_ITERATOR=$(lstk aws kinesis get-shard-iterator \
  --shard-id shardId-000000000000 \
  --shard-iterator-type TRIM_HORIZON \
  --stream-name "$TargetStreamName" \
  --query 'ShardIterator' \
  --output text)

found=""
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  RECORDS_JSON=$(lstk aws kinesis get-records --shard-iterator "$SHARD_ITERATOR")
  SHARD_ITERATOR=$(echo "$RECORDS_JSON" | jq -r '.NextShardIterator')
  for data in $(echo "$RECORDS_JSON" | jq -r '.Records[].Data'); do
    decoded=$(echo "$data" | base64 --decode)
    if echo "$decoded" | jq -e '.enrichment == "Hello from Lambda"' > /dev/null 2>&1; then
      found="$decoded"
      break 2
    fi
  done
  echo "Attempt $attempt/$MAX_ATTEMPTS: no enriched record in target stream yet"
  sleep 2
done

if [ -z "$found" ]; then
  echo "Test failed: no enriched record reached the target stream"
  exit 1
fi
echo "Enriched record: $found"
echo "Test passed: record was enriched and delivered to the target stream"

# Failure path: a record that makes the enrichment fail should end up in the DLQ
echo "Putting a failing record into the source stream"
lstk aws kinesis put-record \
  --cli-binary-format raw-in-base64-out \
  --stream-name "$SourceStreamName" \
  --data '{"fail":true}' \
  --partition-key my-partition-key > /dev/null

dlq_count=0
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  dlq_count=$(lstk aws sqs receive-message --queue-url "$DlqUrl" --wait-time-seconds 2 | jq '.Messages | length')
  dlq_count=${dlq_count:-0}
  [ "$dlq_count" -gt 0 ] && break
  echo "Attempt $attempt/$MAX_ATTEMPTS: DLQ still empty"
done

if [ "$dlq_count" -eq 0 ]; then
  echo "Test failed: failing record did not reach the DLQ"
  exit 1
fi
echo "Test passed: failing record was sent to the DLQ"
