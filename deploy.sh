#!/usr/bin/env bash

if [[ -z $1 ]]; then
    COMMAND="apply"
else
    COMMAND=$1
fi

# Create a Secret with DockerHub credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
kubectl create secret docker-registry dockerhub-user-pass --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD}
kubectl create serviceaccount openwhisk-runtime-builder
kubectl annotate serviceaccount openwhisk-runtime-builder secret=dockerhub-user-pass

#
# Create Install Deps Task
kubectl $COMMAND -f tasks/install-deps.yaml
# Create Build Archive Task
kubectl $COMMAND -f tasks/build-archive.yaml
# Create Application Repo Git Pipeline Resource
kubectl $COMMAND -f resources/padding-app-git.yaml

