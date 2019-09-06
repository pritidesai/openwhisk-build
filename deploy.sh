#!/usr/bin/env bash

#
# ARGS:
#   COMMAND (default is apply)
#

APPLY="apply"
DELETE="delete"

USAGE=$(cat <<-END
Usage:
    Environment Variables DOCKER_USERNAME and DOCKER_PASSWORD must be set.
    deploy.sh [$APPLY|$DELETE]
    Default: deploy.sh $APPLY
END
)


if [[ -z $DOCKER_USERNAME ]]; then
    echo "$USAGE"
    exit 1
fi

if [[ -z $DOCKER_PASSWORD ]]; then
    echo "$USAGE"
    exit 1
fi

if [[ -z $1 ]]; then
    COMMAND=$APPLY
else
    if [ "$1" == "$APPLY" ] || [ "$1" == "$DELETE" ]; then
        COMMAND=$1
    else
        echo "Invalid Command: $1"
        echo "$USAGE"
        exit 1
    fi
fi

if [ $COMMAND == $APPLY ]; then
    # Create a Secret with DockerHub credentials
    # https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials
    # https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
    # kubectl create secret docker-registry dockerhub-user-pass --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD

    # Create a Service Account called openwhisk-runtime-builder
    # kubectl create serviceaccount openwhisk-app-builder

    # Annotate Service Account with Docker Registry secret
    # kubectl annotate serviceaccount openwhisk-app-builder secret=dockerhub-user-pass
    sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' -e 's/${DOCKER_PASSWORD}/'"$DOCKER_PASSWORD"'/' docker-secret.yaml.tmpl > docker-secret.yaml
    kubectl $COMMAND -f docker-secret.yaml
    kubectl $COMMAND -f service-account.yaml
# else
#    kubectl delete secret docker-registry dockerhub-user-pass
#    kubectl delete serviceaccount openwhisk-app-builder
fi

# Create Clone Source Task
kubectl $COMMAND -f tasks/clone-source.yaml
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
# Run OpenWhisk Pipeline after replacing DOCKER_USERNAME with user specified name
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun-build-padding-app.yaml.tmpl > pipelinerun-build-padding-app.yaml
kubectl $COMMAND -f pipelinerun-build-padding-app.yaml


