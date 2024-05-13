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
awslocal kinesis put-record \
  --stream-name $SourceStreamName \
  --data '{"fail":false}' \
  --partition-key my-partition-key

sleep 5

# Get the shard iterator for the target stream
SHARD_ITERATOR=$(awslocal kinesis get-shard-iterator \
  --shard-id shardId-000000000000 \
  --shard-iterator-type TRIM_HORIZON \
  --stream-name $TargetStreamName \
  --query 'ShardIterator' \
  --output text)

sleep 5

RECORD_DATA=$(awslocal kinesis get-records \
  --shard-iterator $SHARD_ITERATOR | jq -r '.Records[0].Data' | base64 --decode)

echo "$RECORD_DATA" | jq -r 'if .enrichment == "Hello from Lambda" then "Success" else "Failure" end'
