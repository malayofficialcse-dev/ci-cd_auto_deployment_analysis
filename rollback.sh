#!/bin/bash

source config.env

echo
echo "ROLLBACK INITIATED"

kubectl rollout undo \
deployment/$KUBE_DEPLOYMENT \
-n $KUBE_NAMESPACE

kubectl rollout status \
deployment/$KUBE_DEPLOYMENT \
-n $KUBE_NAMESPACE

echo
echo "ROLLBACK COMPLETED"