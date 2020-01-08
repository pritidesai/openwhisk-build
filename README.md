# Building OpenWhisk Java Application with Tekton for Knative

In a recent experiment with OpenWhisk, we built a Tekton pipeline to create an image with OpenWhisk Java Runtime serving an application source from GitHub repo.
FollowingHere is the list of `Tasks` created: 

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


![Java Pipeline](java-pipeline.jpg)

This entire pipeline is designed in [pipeline-java.yaml](pipeline/java/pipeline-java.yaml) including all the `Tasks` defined above and
pipeline run in [pipelinerun-java-yaml.tmpl](pipelinerun/java/pipelinerun-java.yaml.tmpl) to execute the pipeline.  

Deploy `Tasks`, `Pipeline` and `Pipelinerun` using [deploy.sh](deploy.sh):

```shell script
./deploy.sh
```

[deploy.sh](deploy.sh) need two environment variables `DOCKER_USERNAME` and `DOCKER_PASSWORD` set to appropriate Docker credentials in plain text.

Create a new service on Knative with:

```shell script
sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' service/service-openwhisk-java-app.yaml.tmpl > service/service-openwhisk-java-app.yaml
kubectl apply -f service/service-openwhisk-java-app.yaml
```

Run OpenWhisk Java Application service with few different images:

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '@01-dice-color.json' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 01-dice-gray.png
```

![01-dice-color.png](images/01-dice-color.png) => ![01-dice-gray.png](images/01-dice-gray.png)

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '@02-conf-crowd.json' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 02-conf-crowd-gray.png
```

![02-conf-crowd.png](images/02-conf-crowd.png) => ![02-conf-crowd-gray.png](images/02-conf-crowd-gray.png)

```shell script
curl -H "Host: openwhisk-java-app.default.example.com" -d '{"value": {"png": "'$(base64 images/03-eclipsecon-2019.png | tr -d \\n)'"}}' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 03-eclipsecon-2019-gray.png
```

![03-eclipsecon-2019.png](images/03-eclipsecon-2019.png) => ![03-eclipsecon-2019-gray.png](images/03-eclipsecon-2019-gray.png)



