#!/usr/bin/env bash

#
# ARGS:
#   COMMAND (default is apply)
#

APPLY="apply"
DELETE="delete"
OPERATION=$APPLY
JAVASCRIPT="javascript"
JAVA="java"
LANGUAGE=$JAVASCRIPT

USAGE=$(cat <<-END
Usage:
    Environment Variables DOCKER_USERNAME and DOCKER_PASSWORD must be set.
    deploy.sh [-o $APPLY|$DELETE] [-l $JAVASCRIPT|$JAVA]
    Default: deploy.sh -o $APPLY -l $JAVASCRIPT
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

while (( "$#" )); do
  case "$1" in
    -o|--operation)
      OPERATION=$2
      shift 2
      ;;
    -l|--LANGUAGE)
      LANGUAGE=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      echo $USAGE
      exit 1
      ;;
  esac
done

if [ "$OPERATION" != "$APPLY" ] && [ "$OPERATION" != "$DELETE" ]; then
  echo "Invalid Operation: $OPERATION"
  echo "$USAGE"
  exit 1
fi

if [ "$LANGUAGE" != "$JAVASCRIPT" ] && [ "$LANGUAGE" != "$JAVA" ]; then
  echo "$LANGUAGE is invalid or not yet supported, please pick one of the supported runtimes [$JAVASCRIPT|$JAVA]"
  echo "$USAGE"
  exit 1
fi

if [ "$OPERATION" == "$APPLY" ]; then
    # Create a Secret with DockerHub credentials
    # https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials
    # https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
    # kubectl create secret docker-registry dockerhub-user-pass --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD

    # Create a Service Account called openwhisk-runtime-builder
    # kubectl create serviceaccount openwhisk-app-builder

    # Annotate Service Account with Docker Registry secret
    # kubectl annotate serviceaccount openwhisk-app-builder secret=dockerhub-user-pass
    sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' -e 's/${DOCKER_PASSWORD}/'"$DOCKER_PASSWORD"'/' docker-secret.yaml.tmpl > docker-secret.yaml
    kubectl $OPERATION -f docker-secret.yaml
    kubectl $OPERATION -f service-account.yaml
# else
#    kubectl delete secret docker-registry dockerhub-user-pass
#    kubectl delete serviceaccount openwhisk-app-builder
fi

if [ "$LANGUAGE" == "$JAVASCRIPT" ]; then
  # Create Clone Source Task
  kubectl $OPERATION -f tasks/javascript/clone-source.yaml
  # Create Install Deps Task
  kubectl $OPERATION -f tasks/javascript/install-deps.yaml
  # Create Build Archive Task
  kubectl $OPERATION -f tasks/javascript/build-archive.yaml
  # Create OpenWhisk Task
  kubectl $OPERATION -f openwhisk.yaml
  # Create Conditions Detecting Runtimes
  kubectl $OPERATION -f detect-runtimes.yaml
  # Create a Pipeline with all three tasks
  kubectl $OPERATION -f pipeline-build-openwhisk-app.yaml
  # Run OpenWhisk Pipeline after replacing DOCKER_USERNAME with user specified name
  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun-build-padding-app.yaml.tmpl > pipelinerun-build-padding-app.yaml
  kubectl $OPERATION -f pipelinerun-build-padding-app.yaml
fi

if [ "$LANGUAGE" == "$JAVA" ]; then
  # Create Build Gradle Task
  kubectl $OPERATION -f tasks/java/embed-java-profile.yaml
  kubectl $OPERATION -f tasks/java/create-one-jar.yaml
  kubectl $OPERATION -f tasks/java/openwhisk.yaml
  kubectl $OPERATION -f pipeline-java.yaml
  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun-java.yaml.tmpl > pipelinerun-java.yaml
  kubectl $OPERATION -f pipelinerun-java.yaml
fi
