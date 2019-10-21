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

# Create a Secret with DockerHub credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials
# https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line
# kubectl create secret docker-registry dockerhub-user-pass --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD

# Create a Service Account called openwhisk-runtime-builder
# kubectl create serviceaccount openwhisk-app-builder

# Annotate Service Account with Docker Registry secret
# kubectl annotate serviceaccount openwhisk-app-builder secret=dockerhub-user-pass
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' -e 's/${DOCKER_PASSWORD}/'"$DOCKER_PASSWORD"'/' docker-secret.yaml.tmpl > docker-secret.yaml
printf "\nCreating secret [dockerhub-user-pass] to publish the Serverless Function Image.\n"
kubectl $OPERATION -f docker-secret.yaml
sleep $DELAY

printf "\nCreating service account [openwhisk-app-builder] with the secret just created.\n"
kubectl $OPERATION -f service-account.yaml
sleep $DELAY
# else
#    kubectl delete secret docker-registry dockerhub-user-pass
#    kubectl delete serviceaccount openwhisk-app-builder

if [ "$LANGUAGE" == "$JAVASCRIPT" ]; then
  # Create Clone Source Task
  kubectl $OPERATION -f tasks/javascript/clone-source.yaml
  # Create Install Deps Task
  kubectl $OPERATION -f tasks/javascript/install-deps.yaml
  # Create Build Archive Task
  kubectl $OPERATION -f tasks/javascript/build-archive.yaml
  # Create OpenWhisk Task
  kubectl $OPERATION -f tasks/openwhisk.yaml
  # Create Conditions Detecting Runtimes
  kubectl $OPERATION -f tasks/detect-runtimes.yaml
  # Create a Pipeline with all three tasks
  kubectl $OPERATION -f pipeline/javascript/pipeline-build-openwhisk-app.yaml
  # Run OpenWhisk Pipeline after replacing DOCKER_USERNAME with user specified name
  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/javascript/pipelinerun-build-padding-app.yaml.tmpl > pipelinerun/javascript/pipelinerun-build-padding-app.yaml
  kubectl $OPERATION -f pipelinerun/javascript/pipelinerun-build-padding-app.yaml
fi

if [ "$LANGUAGE" == "$JAVA" ]; then
  # Create Build Gradle Task
  printf "\nINFO: Creating task [create-jar-with-maven] to Clone Java App Source and Create Jar using Maven\n"
  kubectl $OPERATION -f tasks/java/01-create-jar-with-maven.yaml
  sleep $DELAY

  printf "\nINFO: Creating task [build-runtime-with-gradle] to select JDK version along with the base image with optional Framework and Profile Libraries\n"
  kubectl $OPERATION -f tasks/java/02-build-runtime-with-gradle.yaml
  sleep $DELAY

  printf "\nINFO: Creating task [build-shared-class-cache] to Compile and Create shared Class Cache for JVM\n"
  kubectl $OPERATION -f tasks/java/03-build-shared-class-cache.yaml
  sleep $DELAY

  printf "\nINFO: Creating task [finalize-runtime-with-function] to finalize Serverless Java Function Image and Publish\n"
  kubectl $OPERATION -f tasks/java/04-finalize-runtime-with-function.yaml
  sleep $DELAY

  printf "\nINFO: Creating Pipeline [pipeline-java] combining all the Tasks from above.\n"
  kubectl $OPERATION -f pipeline/java/pipeline-java.yaml
  sleep $DELAY

  sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/java/pipelinerun-java.yaml.tmpl > pipelinerun/java/pipelinerun-java.yaml
  printf "\nINFO: Creating PipelineRun [pipelinerun-java] to Execute the Java pipeline.\n"
  kubectl $OPERATION -f pipelinerun/java/pipelinerun-java.yaml
  sleep $DELAY
fi
