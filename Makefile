export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION = us-east-1
SHELL := /bin/bash
PYTHON_BIN ?= $(shell which python3 || which python)

usage:      ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

install:    ## Install dependencies
	@which localstack || pip install localstack
	@which awslocal || pip install awscli-local
	@which cdk || npm install -g aws-cdk
	@which cdklocal || npm install -g aws-cdk-local
	@test -e .venv || ($(PYTHON_BIN) -m venv .venv; source .venv/bin/activate; pip install -r requirements.txt)

deploy:
	source .venv/bin/activate; cdklocal bootstrap && cdklocal deploy --all --require-approval never

run:
	./run.sh

start:
	localstack start -d

stop:
	@echo
	localstack stop

ready:
	@echo Waiting on the LocalStack container...
	@localstack wait -t 30 && echo Localstack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

logs:
	@localstack logs > logs.txt
	
.PHONY: usage install start run stop ready logs
