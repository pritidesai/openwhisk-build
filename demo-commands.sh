kubectl version

kubectl get all

sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' -e 's/${DOCKER_PASSWORD}/'"$DOCKER_PASSWORD"'/' docker-secret.yaml.tmpl > docker-secret.yaml



kubectl apply -f docker-secret.yaml
kubectl get secret dockerhub-user-pass



kubectl apply -f service-account.yaml
kubectl get serviceaccount openwhisk-app-builder


ls tasks/java

kubectl apply -f tasks/java
kubectl get all

kubectl apply -f pipeline/java
kubectl get all


sed -e 's/${DOCKER_USERNAME}/'"$DOCKER_USERNAME"'/' pipelinerun/java/pipelinerun-java.yaml.tmpl > pipelinerun/java/pipelinerun-java.yaml
kubectl apply -f pipelinerun/java/pipelinerun-java.yaml
kubectl get all


kubectl apply -f service.yaml
kubectl get all

curl -H "Host: openwhisk-java-app.default.example.com" -d '@01-dice-color.json' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 01-dice-gray.png


curl -H "Host: openwhisk-java-app.default.example.com" -d '@02-conf-crowd.json' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 02-conf-crowd-gray.png


curl -H "Host: openwhisk-java-app.default.example.com" -d '{"value": {"png": "'$(base64 images/03-eclipsecon-2019.png | tr -d \\n)'"}}' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 03-eclipsecon-2019-gray.png


curl -H "Host: openwhisk-java-app.default.example.com" -d '{"value": {"png": "'$(base64 images/03-java-duke.png | tr -d \\n)'"}}' -H "Content-Type: application/json" -X POST http://localhost:32319/run | jq -r '.body' | base64 -D > 03-java-duke-gray.png


