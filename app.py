#!/usr/bin/env python3
import os

import aws_cdk as cdk

from pipes_streaming.pipes_streaming_stack import PipesStreamingStack


app = cdk.App()
PipesStreamingStack(app, "PipesStreamingStack")

app.synth()
