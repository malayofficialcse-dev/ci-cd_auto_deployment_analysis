#!/bin/bash

source config.env

LOGFILE="logs/deployment_$(date +%Y%m%d_%H%M%S).log"

mkdir -p logs
mkdir -p reports

log() {
    echo "[$(date)] $1"
    echo "[$(date)] $1" >> "$LOGFILE"
}

step() {
    echo
    echo "===================================================="
    echo "$1"
    echo "===================================================="
}

git_pull() {

    step "GIT PULL"

    if [ ! -d "$PROJECT_NAME" ]; then

        git clone "$GIT_REPO"

    else

        cd "$PROJECT_NAME"

        git pull origin main

        cd ..

    fi
}

build_project() {

    step "BUILD PROJECT"

    cd "$PROJECT_NAME"

    if [ -f package.json ]; then

        npm install
        npm run build

    elif [ -f pom.xml ]; then

        mvn clean package

    elif [ -f requirements.txt ]; then

        pip install -r requirements.txt

    fi

    cd ..
}

run_tests() {

    step "RUN TESTS"

    cd "$PROJECT_NAME"

    if [ -f package.json ]; then

        npm test

    elif [ -f pom.xml ]; then

        mvn test

    fi

    cd ..
}

docker_build() {

    step "DOCKER BUILD"

    docker build \
    -t $DOCKER_IMAGE:$DOCKER_TAG \
    ./$PROJECT_NAME
}

docker_push() {

    step "DOCKER PUSH"

    docker push \
    $DOCKER_IMAGE:$DOCKER_TAG
}

deploy_kubernetes() {

    step "KUBERNETES DEPLOYMENT"

    kubectl apply \
    -f deployments/deployment.yaml

    kubectl apply \
    -f deployments/service.yaml
}

update_image() {

    step "UPDATE IMAGE"

    kubectl set image \
    deployment/$KUBE_DEPLOYMENT \
    $KUBE_CONTAINER=$DOCKER_IMAGE:$DOCKER_TAG \
    -n $KUBE_NAMESPACE
}

wait_rollout() {

    step "WAIT FOR ROLLOUT"

    kubectl rollout status \
    deployment/$KUBE_DEPLOYMENT \
    -n $KUBE_NAMESPACE
}

health_check() {

    step "HEALTH CHECK"

    sleep 15

    curl -f "$HEALTH_URL"

    if [ $? -eq 0 ]; then

        echo
        echo "Deployment Successful"

    else

        echo
        echo "Deployment Failed"

        ./rollback.sh

        exit 1
    fi
}

generate_report() {

REPORT="reports/deployment_report_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "DEPLOYMENT REPORT"
    echo "Generated: $(date)"
    echo

    echo "Git Repository"
    echo "$GIT_REPO"

    echo
    echo "Docker Image"
    echo "$DOCKER_IMAGE:$DOCKER_TAG"

    echo
    echo "Kubernetes Namespace"
    echo "$KUBE_NAMESPACE"

    echo
    echo "Pods"

    kubectl get pods -n $KUBE_NAMESPACE

    echo
    echo "Services"

    kubectl get svc -n $KUBE_NAMESPACE

} > "$REPORT"

echo
echo "Report Created:"
echo "$REPORT"

}

main() {

    log "DEPLOYMENT STARTED"

    git_pull

    build_project

    run_tests

    docker_build

    docker_push

    deploy_kubernetes

    update_image

    wait_rollout

    health_check

    generate_report

    log "DEPLOYMENT COMPLETED"
}

main