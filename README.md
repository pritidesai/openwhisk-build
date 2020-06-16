# OpenWhisk Application pipeline for Knative

*This catalog offering provides a single pipeline that can be used to build either [Apache OpenWhisk](https://openwhisk.apache.org/) or [Knative](https://openwhisk.apache.org/) compatible containers for supported runtimes used to execute OpenWhisk serverless functions.*

As background, the [Apache OpenWhisk project](https://openwhisk.apache.org/) provides a robust implementation of a  Function-as-a-Service (FaaS) platform to run serverless applications written in any functional language.

The project provides a set of [supported language runtimes](https://openwhisk.apache.org/downloads.html#component-releases) that includes a proxy enforces a documented contract for function initialization (function injection) and execution along with a standard context. Several of these runtimes, such as NodeJS, Python and Java, have been updated to support execution on as containers on either OpenWhisk or [Knative](https://openwhisk.apache.org/) clusters. In the latter case, the resultant containers can be run as on Knative without requiring an OpenWhisk control plane.

## Pipeline resources

The pipeline also uses a consistent series of tasks to perform similar functional steps for each language.  Each supported language has a series of language-specific task implementations that all appear as their own branch of the pipeline.

In general, these common tasks provide the following logical steps:

![OpenWhisk to Knative generalized pipeline](images/OpenWhisk-to-Knative-general-pipeline.png)

1. Detect Runtimes (Condition)
2. Clone Serverless Function and Dependencies
3. Clone Compatible Language Runtime (Versioned)
4. (Optionally) Perform language-specific tasks
5. Build the Serverless Application image
    - *Configure service proxy for Knative or OpenWhisk target platforms.*
6. Push image to target image repo.
    - *Optionally, add OpenWhisk context to environment variables.*

## Running the pipeline

### Prerequisites

This pipeline and all examples were tested using the following prerequisite software and listed versions:

- [x] [Tekton Pipeline](https://github.com/tektoncd/pipeline/blob/master/docs/install.md#installing-tekton-pipelines) v1beta1
- [x] [Kubernetes](https://kubernetes.io/docs/home/#learn-how-to-use-kubernetes) v1.15.5
- [x] [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) v1.15.5
- [x] [Knative Serving](https://knative.dev/docs/install/any-kubernetes-cluster/) 0.9.0 *(for running examples)*

Specifically, for development and testing on Mac OS, the following components and versions were used:

- [x] [Docker Desktop for Mac Docker Community Edition 2.2.0.5](https://www.docker.com/get-started) (stable)
    - which includes Kubernetes 1.15.5

#### Docker Desktop resources

If using Docker Desktop, verify in the Docker Desktop menu dropdown that you see "Kubernetes is running". If not, then enable it by selecting **Preferences** -> **Kubernetes**  and check "enable" then wait for it to start.

Further verify that you have allocated enough resources to run all sample applications by selecting **Preferences** -> **Resources** -> **Advanced**.  The following settings were used for testing all examples:

- [x] **CPUs: 6**
- [x] **Memory: 8.0 GiB**
- [x] **Swap: 1.5 GiB**

#### Verify Kubernetes

1. Verify node is ready
    </br>
    ```
    $ kubectl get nodes

    NAME             STATUS    ROLES     AGE       VERSION
    docker-desktop   Ready     master    4d22h     v1.15.5
    ```

2. Verify client and server versions
</br>
    ```bash
    $ kubectl version
    ```

    ```bash
    Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.5", GitCommit:"20c265fef0741dd71a66480e35bd69f18351daea", GitTreeState:"clean", BuildDate:"2019-10-15T19:16:51Z", GoVersion:"go1.12.10", Compiler:"gc", Platform:"darwin/amd64"}
    Server Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.5", GitCommit:"20c265fef0741dd71a66480e35bd69f18351daea", GitTreeState:"clean", BuildDate:"2019-10-15T19:07:57Z", GoVersion:"go1.12.10", Compiler:"gc", Platform:"linux/amd64"}
    ```

3. Verify Kubernetes and Tekton pipeline pods are running
<br>
    ```bash
    $ kubectl get pods --namespace kube-system
    ```
    <details>
    <summary>Example results:</summary>
    ```bash
    $ kubectl get pods --namespace kube-system
    ```

    ```bash
    NAME                                     READY   STATUS    RESTARTS   AGE
    coredns-5c98db65d4-h5qhs                 1/1     Running   1          38d
    coredns-5c98db65d4-hfxsq                 1/1     Running   1          38d
    etcd-docker-desktop                      1/1     Running   0          38d
    kube-apiserver-docker-desktop            1/1     Running   0          38d
    kube-controller-manager-docker-desktop   1/1     Running   0          38d
    kube-proxy-8sfxl                         1/1     Running   0          38d
    kube-scheduler-docker-desktop            1/1     Running   1          38d
    storage-provisioner                      1/1     Running   1          38d
    ```

    </details>
    </br>

    ```bash
    $ kubectl get pods --namespace tekton-pipelines
    ```

    <details>
    <summary>Example results:</summary>

    ```bash
    NAME                                           READY   STATUS    RESTARTS   AGE
    tekton-pipelines-controller-7c67695997-4wtsf   1/1     Running   0          13d
    tekton-pipelines-webhook-7787f6489-t28gj       1/1     Running   0          13d
    ```

    </details>

## Installing pipeline resources

The `Pipeline` is defined in the Kubernetes-style YAML file:  [pipeline-to-build-openwhisk-app.yaml](pipeline/pipeline-to-build-openwhisk-app.yaml).  It includes reference to the shared `Workspace` called "openwhisk-workspace" and all referenced `PipelineResources` and `Tasks`.

All dependent resources required by the pipeline can be installed using the single "[deploy.sh](deploy.sh)" script located in the root of the `openwhisk` directory.

Follow these instructions to install the pipeline resources:

### Set Docker environment variables

The deployment script needs two environment variables `DOCKER_USERNAME` and `DOCKER_PASSWORD` set to your Docker basic auth. credentials (i.e., DockerHub username and password) with the *values provided in plain text*.

```bash
export DOCKER_USERNAME=<my_dockerhub_username>
export DOCKER_PASSWORD=<my_dockerhub_password>
```

verify variables are set:

```bash
printenv DOCKER_USERNAME
printenv DOCKER_PASSWORD
```

### Run the deploy script

Deploy all `Pipeline resources using the [deploy.sh](deploy.sh) script using the following command:

```shell script
./deploy.sh
```

You should see all resource successfully created:

```bash
secret/dockerhub-user-pass created
serviceaccount/openwhisk-app-builder created
condition.tekton.dev/is-nodejs-runtime created
condition.tekton.dev/is-java-runtime created
condition.tekton.dev/is-python-runtime created
persistentvolumeclaim/openwhisk-workspace created
task.tekton.dev/clone-app-repo-to-workspace created
task.tekton.dev/clone-runtime-repo-to-workspace created
task.tekton.dev/task-install-npm-packages created
task.tekton.dev/task-build-archive created
task.tekton.dev/openwhisk created
task.tekton.dev/task-install-pip-packages created
task.tekton.dev/task-build-archive-python created
task.tekton.dev/openwhisk-python created
task.tekton.dev/create-jar-with-maven created
task.tekton.dev/build-runtime-with-gradle created
task.tekton.dev/build-shared-class-cache created
task.tekton.dev/finalize-runtime-with-function created
pipeline.tekton.dev/build-openwhisk-app created
```

## Building OpenWhisk Applications using the pipeline

In this section, we will describe how to use the pipeline to build and deploy Serverless application images for the following popular OpenWhisk languages using some sample functions:

- [NodeJS](#nodejs)
- [Python](#python)
- [Java](#java)

In addition, we will show how to confugre the pipeline to produce a Serverless application image that is compatible with:

- [Knative](https://knative.dev/) (default)
- [Apache OpenWhisk](https://openwhisk.apache.org/)
- [Project Coligo](https://cloud.ibm.com/docs/knative?topic=knative-kn-faqs) *an IBM experimental Knative-based container platform*

### NodeJS

#### Custom Tasks

The `Pipeline` includes the following customized `Tasks`  specific to NodeJS:

Here is the list of `Tasks` created:

* [01-install-deps.yaml](tasks/javascript/01-install-deps.yaml) - Pull NodeJS Application source with an OpenWhisk action
from an open GitHub repo and download a list of dependencies specified in the `package.json` file.

* [02-build-archive.yaml](tasks/javascript/02-build-archive.yaml) - Build an archive with application source and all the dependencies.

* [03-openwhisk.yaml](tasks/javascript/03-openwhisk.yaml) - Inject NodeJS application archive built in previous task into the
OpenWhisk runtime and build/publish an image.

* Use Knative Serving to deploy the finalized image on Knative.

![NodeJS pipeline resources](images/pipeline-customized-for-nodejs.png)

#### Running the example

1. Execute `PipelineRun` with:

    ```bash
    sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/javascript/pipelinerun-javascript.yaml.tmpl > pipelinerun/javascript/pipelinerun-javascript.yaml
    kubectl apply -f pipelinerun/javascript/pipelinerun-javascript.yaml
    ```

2. Confirm that the `PipelineRun` completed successfully:

    ```bash
    tkn pr describe build-javascript-app-image
    ```

    ```
    STATUS
    14 hours ago   52 seconds   Succeeded(Completed)
    ```

    <details>
    <summary>Expand to see complete sample output </summary>

    ```
    Name:              build-javascript-app-image
    Namespace:         default
    Pipeline Ref:      build-openwhisk-app
    Service Account:   openwhisk-app-builder
    Timeout:           1h0m0s
    Labels:
    tekton.dev/pipeline=build-openwhisk-app

    🌡️  Status

    STARTED        DURATION     STATUS
    14 hours ago   52 seconds   Succeeded(Completed)

    📦 Resources
    NAME            RESOURCE REF
    ∙ app-git
    ∙ runtime-git
    ∙ app-image

    ⚓ Params
    NAME               VALUE
    ∙ OW_APP_PATH      packages/left-pad/
    ∙ DOCKERFILE       core/nodejs10Action/knative/Dockerfile
    ∙ OW_ACTION_NAME   openwhisk-padding-app

    🗂  Taskruns
    NAME                                                                TASK NAME                        STARTED        DURATION     STATUS
    ∙ build-javascript-app-image-clone-python-app-source-g9vnd          clone-python-app-source          ---            ---          Failed(ConditionCheckFailed)
    ∙ build-javascript-app-image-clone-java-app-source-2t4mf            clone-java-app-source            ---            ---          Failed(ConditionCheckFailed)
    ∙ build-javascript-app-image-build-openwhisk-app-image-node-mm8zj   build-openwhisk-app-image-node   14 hours ago   3 minutes    Succeeded
    ∙ build-javascript-app-image-build-archive-node-nv48j               build-archive-node               14 hours ago   11 seconds   Succeeded
    ∙ build-javascript-app-image-clone-nodejs-runtime-source-7ksnl      clone-nodejs-runtime-source      14 hours ago   12 seconds   Succeeded
    ∙ build-javascript-app-image-install-npm-packages-4dxrg             install-npm-packages             14 hours ago   11 seconds   Succeeded
    ∙ build-javascript-app-image-clone-nodejs-app-source-64hdr          clone-nodejs-app-source          14 hours ago   7 seconds    Succeeded
    ```

    </details>
    </br>

3. Create a new service on Knative with:

    ```shell script
    sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' services/service-openwhisk-javascript-app.yaml.tmpl > services/service-openwhisk-javascript-app.yaml
    kubectl apply -f services/service-openwhisk-javascript-app.yaml
    ```

4. Run the application service:

    ```shell script
    curl -H "Host: openwhisk-javascript-app.default.example.com" -d '@left-padding-data-run.json' -H "Content-Type: application/json" -X POST http://localhost/
    {"padded":[".........................Hello","..................How are you?"]}
    ```

---

### Python

#### Custom Tasks

The `Pipeline` includes the following customized `Tasks`  specific to Python:

* [01-install-deps.yaml](tasks/javascript/01-install-deps.yaml) - Pull NodeJS Application source with an OpenWhisk action
from an open GitHub repo and download a list of dependencies specified in the `package.json` file.

* [02-build-archive.yaml](tasks/javascript/02-build-archive.yaml) - Build an archive with application source and all the dependencies.

* [03-openwhisk.yaml](tasks/javascript/03-openwhisk.yaml) - Inject NodeJS application archive built in previous task into the
OpenWhisk runtime and build/publish an image.

* Use Knative Serving to deploy the finalized image on Knative.

This entire pipeline is designed in [pipeline-to-build-openwhisk-app.yaml](pipeline/pipeline-to-build-openwhisk-app.yaml) including all the `Tasks` defined above and
pipeline run in [pipelinerun-build-padding-app.yaml.tmpl](pipelinerun/javascript/pipelinerun-build-padding-app.yaml.tmpl) to execute the pipeline.

![Python pipeline resources](images/pipeline-customized-for-python.png)

Execute `PipelineRun` with:

```shell script
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/python/pipelinerun-python.yaml.tmpl > pipelinerun/python/pipelinerun-python.yaml
kubectl apply -f pipelinerun/python/pipelinerun-python.yaml
```

Listing all the `Tasks`, `Pipeline`, and `PipelineRun`:

```shell script
tkn pr describe build-python-app-image
Name:              build-python-app-image
Namespace:         default
Pipeline Ref:      build-openwhisk-app
Service Account:   openwhisk-app-builder
Timeout:           1h0m0s
Labels:
 tekton.dev/pipeline=build-openwhisk-app

🌡️  Status

STARTED      DURATION    STATUS
1 hour ago   8 minutes   Succeeded(Completed)

📦 Resources

 NAME            RESOURCE REF
 ∙ app-git
 ∙ runtime-git
 ∙ app-image

⚓ Params

 NAME               VALUE
 ∙ OW_APP_PATH      packages/helloMorse/
 ∙ DOCKERFILE       core/python3Action/Dockerfile
 ∙ OW_ACTION_NAME   openwhisk-morse-hello-app

🗂  Taskruns

 NAME                                                       TASK NAME                          STARTED      DURATION     STATUS
 ∙ build-app-image-clone-java-app-source-f62w4              clone-java-app-source              ---          ---          Failed(ConditionCheckFailed)
 ∙ build-app-image-clone-nodejs-app-source-fsfqt            clone-nodejs-app-source            ---          ---          Failed(ConditionCheckFailed)
 ∙ build-app-image-build-openwhisk-app-image-python-h4kgv   build-openwhisk-app-image-python   1 hour ago   7 minutes    Succeeded
 ∙ build-app-image-build-archive-python-jwphl               build-archive-python               1 hour ago   11 seconds   Succeeded
 ∙ build-app-image-clone-python-runtime-source-cjgjz        clone-python-runtime-source        1 hour ago   11 seconds   Succeeded
 ∙ build-app-image-install-pip-packages-jvclf               install-pip-packages               1 hour ago   35 seconds   Succeeded
 ∙ build-app-image-clone-python-app-source-x44p2            clone-python-app-source            1 hour ago   6 seconds    Succeeded
```

Create a new service on Knative with:

```shell script
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' services/service-openwhisk-python-app.yaml.tmpl > services/service-openwhisk-python-app.yaml
kubectl apply -f services/service-openwhisk-python-app.yaml
```

Run OpenWhisk NodeJS Application service:

```shell script
curl -H "Host: openwhisk-morse-hello-app.default.example.com" -d '@left-padding-data-run.json' -H "Content-Type: application/json" -X POST http://localhost/
{"morseGreeting": ".... . .-.. .-.. --- --..--   .-- --- .-. .-.. -.. -.-.-- "}
```

---

#### Java

In a recent experiment with OpenWhisk, we built a Tekton pipeline to create an image with OpenWhisk Java Runtime serving an application source from GitHub repo.

#### Custom Tasks

The `Pipeline` includes the following customized `Tasks`  specific to Java:

* [01-create-jar-with-maven.yaml](tasks/java/01-create-jar-with-maven.yaml) - Pull Java Application with an OpenWhisk action
from an open GitHub repo, with java action taking an image and converting it into gray image. Compile the source code
and build Jar file using Maven if POM file exists at the root of application repo.

* [02-build-runtime-with-gradle.yaml](tasks/java/02-build-runtime-with-gradle.yaml) - Select the JDK version, optional framework,
and optional profile libraries.

* [03-build-shared-class-cache.yaml](tasks/java/03-build-shared-class-cache.yaml) - Compile OpenWhisk Java runtime i.e.
create Java Shared Class Cache for proxy.

* [04-finalize-runtime-with-function.yaml](tasks/java/04-finalize-runtime-with-function.yaml) - Inject Java application
Jar into the OpenWhisk runtime and build/publish an image.

* Use Knative Serving to deploy the finalized image on Knative.

This entire pipeline is designed in [pipeline-to-build-openwhisk-app.yaml](pipeline/pipeline-to-build-openwhisk-app.yaml) including all the `Tasks` defined above and
pipeline run in [pipelinerun-java-yaml.tmpl](pipelinerun/java/pipelinerun-java.yaml.tmpl) to execute the pipeline.


![Java pipeline resources](images/pipeline-customized-for-java.png)

Execute `PipelineRun` with:

```shell script
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/java/pipelinerun-java.yaml.tmpl > pipelinerun/java/pipelinerun-java.yaml
kubectl apply -f pipelinerun/java/pipelinerun-java.yaml
```

Listing all the `Tasks`, `Pipeline`, and `PipelineRun`:

```shell script
tkn pr describe build-java-app-image
Name:              build-java-app-image
Namespace:         default
Pipeline Ref:      build-openwhisk-app
Service Account:   openwhisk-app-builder
Timeout:           1h0m0s
Labels:
 tekton.dev/pipeline=build-openwhisk-app

🌡️  Status

STARTED      DURATION    STATUS
1 hour ago   2 minutes   Succeeded(Completed)

📦 Resources

 NAME            RESOURCE REF
 ∙ app-git
 ∙ runtime-git
 ∙ app-image

⚓ Params

 NAME                     VALUE
 ∙ OW_BUILD_CONFIG_PATH   knative-build/runtimes/java/core/java8/proxy/
 ∙ OW_ACTION_NAME         openwhisk-java-app
 ∙ OW_RUNTIME_CONTEXT     dir:///workspace/openwhisk-workspace/runtime/knative-build/runtimes/java/core/java8/
 ∙ OW_AUTO_INIT_MAIN      Hello

🗂  Taskruns

 NAME                                                          TASK NAME                        STARTED      DURATION     STATUS
 ∙ build-java-app-image-clone-nodejs-app-source-fpkrx          clone-nodejs-app-source          ---          ---          Failed(ConditionCheckFailed)
 ∙ build-java-app-image-clone-python-app-source-c67jq          clone-python-app-source          ---          ---          Failed(ConditionCheckFailed)
 ∙ build-java-app-image-finalize-runtime-with-function-nz96w   finalize-runtime-with-function   1 hour ago   1 minute     Succeeded
 ∙ build-java-app-image-build-shared-class-cache-wkrbc         build-shared-class-cache         1 hour ago   20 seconds   Succeeded
 ∙ build-java-app-image-build-runtime-with-gradle-2n989        build-runtime-with-gradle        1 hour ago   25 seconds   Succeeded
 ∙ build-java-app-image-clone-java-runtime-source-vzgs4        clone-java-runtime-source        1 hour ago   36 seconds   Succeeded
 ∙ build-java-app-image-create-jar-with-maven-jbp4t            create-jar-with-maven            1 hour ago   1 minute     Succeeded
 ∙ build-java-app-image-clone-java-app-source-wbqbl            clone-java-app-source            1 hour ago   8 seconds    Succeeded
```

Create a new service on Knative with:

```shell script
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' services/service-openwhisk-java-app.yaml.tmpl > services/service-openwhisk-java-app.yaml
kubectl apply -f services/service-openwhisk-java-app.yaml
```

Run OpenWhisk Java Application service with few different images:

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '@01-dice-color.json' -H "Content-Type: application/json" -X POST http://localhost/run | jq -r '.body' | base64 -D > 01-dice-gray.png
```

![01-dice-color.png](images/01-dice-color.png)  ![01-dice-gray.png](images/01-dice-gray.png)

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '@02-conf-crowd.json' -H "Content-Type: application/json" -X POST http://localhost/run | jq -r '.body' | base64 -D > 02-conf-crowd-gray.png
```

![02-conf-crowd.png](images/02-conf-crowd.png) => ![02-conf-crowd-gray.png](images/02-conf-crowd-gray.png)

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '{"value": {"png": "'$(base64 images/03-eclipsecon-2019.png | tr -d \\n)'"}}' -H "Content-Type: application/json" -X POST http://localhost/run | jq -r '.body' | base64 -D > 03-eclipsecon-2019-gray.png
```

![03-eclipsecon-2019.png](images/03-eclipsecon-2019.png) => ![03-eclipsecon-2019-gray.png](images/03-eclipsecon-2019-gray.png)

#### Java pipeline vision

It is the goal of this pipeline to provide further optimizations via additional tasks.

The following diagram shows at a high level the envisioned tasks:

![Java Pipeline](java-pipeline.jpg)

We welcome any Java developers who may wish to help us create and improve the tasks and their steps to help realize this vision!