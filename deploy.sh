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
LANGUAGE=$JAVA
DELAY=0


# Usage details is stored here
USAGE=$(cat <<-END
Usage:
    Environment Variables DOCKER_USERNAME and DOCKER_PASSWORD must be set.
    deploy.sh [-o $APPLY|$DELETE] [-l $JAVASCRIPT|$JAVA]
    Default: deploy.sh -o $APPLY -l $JAVASCRIPT
END
)

# Fail and display usage if DOCKER_USERNAME is not set in env.
if [[ -z $DOCKER_USERNAME ]]; then
    echo "$USAGE"
    exit 1
fi

# Fail and display usage if DOCKER_PASSWORD is not set in env.
if [[ -z $DOCKER_PASSWORD ]]; then
    echo "$USAGE"
    exit 1
fi

# Read the command line options and set appropriate arguments, including
# --operations|-o
# --language|-l
while (( "$#" )); do
  case "$1" in
    -o|--operation)
      OPERATION=$2
      shift 2
      ;;
    -l|--language)
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

# validate operations specified in command line
if [ "$OPERATION" != "$APPLY" ] && [ "$OPERATION" != "$DELETE" ]; then
  echo "Invalid Operation: $OPERATION"
  echo "$USAGE"
  exit 1
fi

# validate language/runtime specified in command line
if [ "$LANGUAGE" != "$JAVASCRIPT" ] && [ "$LANGUAGE" != "$JAVA" ]; then
  echo "$LANGUAGE is invalid or not yet supported, please pick one of the supported runtimes [$JAVASCRIPT|$JAVA]"
  echo "$USAGE"
  exit 1
fi

# Create a docker registry secret
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' -e 's/${DOCKER_PASSWORD}/'"$DOCKER_PASSWORD"'/' docker-secret.yaml.tmpl > docker-secret.yaml
kubectl $OPERATION -f docker-secret.yaml
sleep $DELAY

# Create a Service Account called openwhisk-app-builder
# kubectl create serviceaccount openwhisk-app-builder
# Annotate Service Account with Docker Registry secret
# kubectl annotate serviceaccount openwhisk-app-builder secret=dockerhub-user-pass
kubectl $OPERATION -f service-account.yaml
sleep $DELAY

if [ "$LANGUAGE" == "$JAVASCRIPT" ]; then
  # Create Clone Source Task
  kubectl $OPERATION -f tasks/javascript/clone-source.yaml
  sleep $DELAY

  # Create Install Deps Task
  kubectl $OPERATION -f tasks/javascript/install-deps.yaml
  sleep $DELAY

  # Create Build Archive Task
  kubectl $OPERATION -f tasks/javascript/build-archive.yaml
  sleep $DELAY

  # Create OpenWhisk Task
  kubectl $OPERATION -f tasks/openwhisk.yaml
  sleep $DELAY

  # Create Conditions Detecting Runtimes
  kubectl $OPERATION -f tasks/detect-runtimes.yaml
  sleep $DELAY

  # Create a Pipeline with all three tasks
  kubectl $OPERATION -f pipeline/javascript/pipeline-build-openwhisk-app.yaml
  sleep $DELAY

  # Run OpenWhisk Pipeline after replacing DOCKER_USERNAME with user specified name
  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/javascript/pipelinerun-build-padding-app.yaml.tmpl > pipelinerun/javascript/pipelinerun-build-padding-app.yaml
  kubectl $OPERATION -f pipelinerun/javascript/pipelinerun-build-padding-app.yaml
  sleep $DELAY
fi

if [ "$LANGUAGE" == "$JAVA" ]; then
  kubectl $OPERATION -f tasks/java/01-create-jar-with-maven.yaml
  sleep $DELAY

  kubectl $OPERATION -f tasks/java/02-build-runtime-with-gradle.yaml
  sleep $DELAY

  kubectl $OPERATION -f tasks/java/03-build-shared-class-cache.yaml
  sleep $DELAY

  kubectl $OPERATION -f tasks/java/04-finalize-runtime-with-function.yaml
  sleep $DELAY

  kubectl $OPERATION -f pipeline/java/pipeline-java.yaml
  sleep $DELAY

  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/java/pipelinerun-java.yaml.tmpl > pipelinerun/java/pipelinerun-java.yaml
  kubectl $OPERATION -f pipelinerun/java/pipelinerun-java.yaml
  sleep $DELAY
fi
