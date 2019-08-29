#!/usr/bin/env bash

#
# ARGS:
#   DOCKER_USERNAME
#   DOCKER_PASSWORD
#   COMMAND (default is apply)
#

USAGE="deploy.sh <DOCKER_USERNAME> <DOCKER_PASSWORD> <COMMAND>"

if [[ -z $1 ]]; then
    if [[ -z $2 ]]; then
        echo $USAGE
        exit 1
    fi
fi

if [[ -z $3 ]]; then
    COMMAND="apply"
else
    COMMAND=$3
fi

DOCKER_USERNAME=$1
DOCKER_PASSWORD=$2

# Create a Secret with DockerHub credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
kubectl create secret docker-registry dockerhub-user-pass --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD

# Create a Service Account called openwhisk-runtime-builder
kubectl create serviceaccount openwhisk-app-builder

# Annotate Service Account with Docker Registry secret
kubectl annotate serviceaccount openwhisk-app-builder secret=dockerhub-user-pass

# Create Install Deps Task
kubectl $COMMAND -f tasks/install-deps.yaml
# Create Build Archive Task
kubectl $COMMAND -f tasks/build-archive.yaml
# Create OpenWhisk Task
kubectl $COMMAND -f openwhisk.yaml
# Create Conditions Detecting Runtimes
kubectl $COMMAND -f detect-runtimes.yaml
# Create a Pipeline with all three tasks
kubectl $COMMAND -f pipeline-build-openwhisk-app.yaml
# Run OpenWhisk Pipeline
sed -i 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun-build-padding-app.yaml
kubectl $COMMAND -f pipelinerun-build-padding-app.yaml


