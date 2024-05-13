#!/bin/bash

# Extract stack outputs and store them in variables
eval $(awslocal cloudformation describe-stacks --stack-name PipesStreamingStack | jq -r '.Stacks | .[] | .Outputs | .[] | "\(.OutputKey)=\(.OutputValue)"')

# Print the variables to confirm they have been set correctly
echo "PipeName: $PipeName"
echo "SourceStreamName: $SourceStreamName"
echo "DlqUrl: $DlqUrl"
echo "DlqName: $DlqName"
echo "EnrichmentFunctionName: $EnrichmentFunctionName"
echo "TargetStreamName: $TargetStreamName"
echo "RoleName: $RoleName"

# Put a record into the source stream
echo "Putting a record into the source stream"
awslocal kinesis put-record \
  --stream-name $SourceStreamName \
  --data '{"fail":false}' \
  --partition-key my-partition-key

sleep 5

# Get the shard iterator for the target stream
echo "Getting the shard iterator for the target stream"
SHARD_ITERATOR=$(awslocal kinesis get-shard-iterator \
  --shard-id shardId-000000000000 \
  --shard-iterator-type TRIM_HORIZON \
  --stream-name $TargetStreamName \
  --query 'ShardIterator' \
  --output text)

sleep 5

# Get the record from the target stream
echo "Getting the record from the target stream"
RECORDS_JSON=$(awslocal kinesis get-records \
  --shard-iterator $SHARD_ITERATOR)

echo "$RECORDS_JSON"

# Check if the JSON output contains the NextShardIterator
NEXT_SHARD_ITERATOR_PRESENT=$(echo "$RECORDS_JSON" | jq 'has("NextShardIterator")')

if [ "$NEXT_SHARD_ITERATOR_PRESENT" == "true" ]; then
  echo "Test passed: NextShardIterator is present in the JSON output."
else
  echo "Test failed: NextShardIterator is not present in the JSON output."
fi
