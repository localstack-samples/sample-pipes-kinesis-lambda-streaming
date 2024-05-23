# Testing EventBridge Pipes with Kinesis to Lambda to Kinesis and SQS DLQ

This demo, demonstrates deploying and testing a Pipe with the following flow: Kinesis source stream to Lambda enrichment to Kinesis target stream.

Users can deploy the infrastructure with AWS Cloud Development Kit (CDK), and we will demonstrate how you use LocalStack to deploy the infrastructure on your developer machine and your CI environment.

## Prerequisites

-   LocalStack Pro with [`LOCALSTACK_AUTH_TOKEN`](https://docs.localstack.cloud/getting-started/auth-token/)
-   [AWS CLI](https://docs.localstack.cloud/user-guide/integrations/aws-cli/) with the  [`awslocal`](https://github.com/localstack/awscli-local) wrapper.
-   [CDK](https://docs.localstack.cloud/user-guide/integrations/aws-cdk/) with the  [`cdklocal`](https://github.com/localstack/aws-cdk-local) wrapper.
-   [Python](https://www.python.org/downloads/) 3.10+ or later.

Start LocalStack Pro by setting your  `LOCALSTACK_AUTH_TOKEN`  to activate the Pro features.

```bash
export LOCALSTACK_AUTH_TOKEN=<your-auth-token>
localstack start -d
```

## Instructions

You can build and deploy the sample application on LocalStack by running our Makefile commands. To deploy the infrastructure, you can run the following commands:

```bash
make install
make deploy
make run
```

Here are instructions to deploy and test it manually step-by-step.

### Installing the dependencies

Create a `virtualenv` and install all the dependencies there:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Creating the infrastructure

To deploy the infrastructure, you can run the following command:

```bash
cdklocal bootstrap aws://000000000000/us-east-1
cdklocal deploy
```

> Note: Make sure your region is set to `us-east-1` in your AWS CLI configuration. Alternatively you can adjust the bootstrap command to match your region. The region in the Makefile is also set to `us-east-1` and might need changing.

After successful deployment, you will see the following output:

```bash
Outputs:
PipesStreamingStack.DlqName = PipesStreamingStack-DLQ581697C4-d3281d1b
PipesStreamingStack.DlqUrl = http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/PipesStreamingStack-DLQ581697C4-d3281d1b
PipesStreamingStack.EnrichmentFunctionName = PipesStreamingStack-Function76856677-ccaf61c6
PipesStreamingStack.PipeName = PipesStreamingStack-Pipe-59fed9fa
PipesStreamingStack.RoleName = PipesStreamingStack-PipeRole4D7B8476-9756b83e
PipesStreamingStack.SourceStreamName = PipesStreamingStack-SourceStream325EA350-55f54d02
PipesStreamingStack.TargetStreamName = PipesStreamingStack-TargetStream3B4B2880-204262c5
Stack ARN:
arn:aws:cloudformation:us-east-1:000000000000:stack/PipesStreamingStack/daa159bc

✨  Total time: 24.48s
```

### Running the application

Run the following command to extract stack outputs:

```bash
eval $(awslocal cloudformation describe-stacks --stack-name PipesStreamingStack | jq -r '.Stacks | .[] | .Outputs | .[] | "\(.OutputKey)=\(.OutputValue)"')
```

Put a record in the source stream:

```bash
awslocal kinesis put-record \
  --stream-name $SourceStreamName \
  --data '{"fail":false}' \
  --partition-key my-partition-key
```

Get the shard iterator from the target stream:

```bash
SHARD_ITERATOR=$(awslocal kinesis get-shard-iterator \
  --shard-id shardId-000000000000 \
  --shard-iterator-type TRIM_HORIZON \
  --stream-name $TargetStreamName \
  --query 'ShardIterator' \
  --output text)
```

Get the records from the target stream:

```bash
awslocal kinesis get-records \
  --shard-iterator $SHARD_ITERATOR
```

The expected output should be:

```json
{
    "Records": [],
    "NextShardIterator": "AAAAAAAAAAH8ndyIbymJXg7AwfdV//KSETuVxcqVqRu8OK952cQoxtEcdiyiV9YXV3q7xOi0pp18Ca1MIZTVyfwjC63/smmjwtQH+65m4MRrSb8cjrS/2l+0EyC0LrnoXXFgnpnCd77xveDhB31fKDZN7KjP+Jn7ETjgG67onmZjJio1oYvcsYZ4gkVYp/Uo+Rdq+Hhk6SVWSLgToRphVcPYwom+s893FTuLjUAWFVqv3EbWrHcIhYHkIChJZBMtRQV2F36ptpM=",
    "MillisBehindLatest": 0
}
```

## GitHub Action

This application sample hosts an example GitHub Action workflow that starts up LocalStack, deploys the infrastructure, and runs a simple smoke test. You can find the workflow in the `.github/workflows/ci.yml`  file. To run the workflow, you can fork this repository and push a commit to the `main` branch after adding a [valid CI key](https://docs.localstack.cloud/user-guide/web-application/ci-keys/) to the repository secrets.

Users can adapt this example workflow to run in their own CI environment. LocalStack supports various CI environments, including GitHub Actions, CircleCI, Jenkins, Travis CI, and more. You can find more information about the CI integration in the  [LocalStack documentation](https://docs.localstack.cloud/user-guide/ci/).
