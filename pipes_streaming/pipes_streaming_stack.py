import os
import aws_cdk as cdk
from aws_cdk import (
    aws_iam as iam,
    aws_kinesis as kinesis,
    aws_lambda as lambda_,
    aws_pipes as pipes,
    aws_sqs as sqs,
    Stack,
)
from constructs import Construct
from aws_cdk.aws_lambda import InlineCode

# Load environment-specific configuration
THIS_FOLDER = os.path.dirname(os.path.realpath(__file__))
TEST_LAMBDA_PYTHON_ENRICHMENT = os.path.join(THIS_FOLDER, "functions/enrichment.py")

def load_file(path):
    with open(path, 'r') as file:
        return file.read()

class PipesStreamingStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Resources
        source_stream = kinesis.Stream(self, "SourceStream", shard_count=3)
        dlq = sqs.Queue(self, "DLQ")
        enrichment_function = lambda_.Function(
            self,
            "Function",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="index.handler",
            timeout=cdk.Duration.seconds(60),
            code=lambda_.InlineCode(code=load_file(TEST_LAMBDA_PYTHON_ENRICHMENT)),
        )

        target_stream = kinesis.Stream(self, "TargetStream", shard_count=1)

        # IAM
        pipe_role = iam.Role(
            self, "PipeRole", assumed_by=iam.ServicePrincipal("pipes.amazonaws.com")
        )
        source_policy = iam.PolicyStatement(
            sid="AllowSourceStream",
            effect=iam.Effect.ALLOW,
            actions=[
                "kinesis:DescribeStream",
                "kinesis:DescribeStreamSummary",
                "kinesis:GetRecords",
                "kinesis:GetShardIterator",
                "kinesis:ListStreams",
                "kinesis:ListShards",
                "sqs:SendMessage",
            ],
            resources=[source_stream.stream_arn, dlq.queue_arn],
        )
        pipe_role.add_to_policy(source_policy)
        enrichment_policy = iam.PolicyStatement(
            sid="AllowEnrichmentLambda",
            effect=iam.Effect.ALLOW,
            actions=["lambda:InvokeFunction"],
            resources=[enrichment_function.function_arn],
        )
        pipe_role.add_to_policy(enrichment_policy)
        target_policy = iam.PolicyStatement(
            sid="AllowTargetStream",
            effect=iam.Effect.ALLOW,
            actions=["kinesis:PutRecord", "kinesis:PutRecords"],
            resources=[target_stream.stream_arn],
        )
        pipe_role.add_to_policy(target_policy)

        # Pipe
        pipe = pipes.CfnPipe(
            self,
            "Pipe",
            role_arn=pipe_role.role_arn,
            source=source_stream.stream_arn,
            source_parameters=pipes.CfnPipe.PipeSourceParametersProperty(
                kinesis_stream_parameters=pipes.CfnPipe.PipeSourceKinesisStreamParametersProperty(
                    starting_position="TRIM_HORIZON",
                    dead_letter_config=pipes.CfnPipe.DeadLetterConfigProperty(arn=dlq.queue_arn),
                    maximum_retry_attempts=1,
                    batch_size=2,
                ),
            ),
            enrichment=enrichment_function.function_arn,
            target=target_stream.stream_arn,
            target_parameters=pipes.CfnPipe.PipeTargetParametersProperty(
                kinesis_stream_parameters=pipes.CfnPipe.PipeTargetKinesisStreamParametersProperty(
                    partition_key="target-partition-key-0"
                )
            ),
        )

        # Outputs
        cdk.CfnOutput(self, "PipeName", value=pipe.ref)
        cdk.CfnOutput(self, "SourceStreamName", value=source_stream.stream_name)
        cdk.CfnOutput(self, "DlqUrl", value=dlq.queue_url)
        cdk.CfnOutput(self, "DlqName", value=dlq.queue_name)
        cdk.CfnOutput(self, "EnrichmentFunctionName", value=enrichment_function.function_name)
        cdk.CfnOutput(self, "TargetStreamName", value=target_stream.stream_name)
        cdk.CfnOutput(self, "RoleName", value=pipe_role.role_name)
