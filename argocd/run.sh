#!/bin/sh

CLUSTER_PREFIX=argo
CLUSTERS=( "$CLUSTER_PREFIX" )

CLUSTER=${CLUSTERS[0]}
NAMESPACE=tpw

wait_for_pod_ready() {
    sleep 5 # Avoid issue if we're too fast and the pod has not yet been created
    kubectl --context $CLUSTER -n $NAMESPACE \
        wait --for=condition=Ready pod -l $1 --timeout=10m
}

cleanup() {
    echo "Deleting any clusters from previous runs"
    TO_DELETE=( $( kubectl config get-contexts -o name | grep "^$CLUSTER_PREFIX" ) )
    for c in "${TO_DELETE[@]}"
    do
        minikube delete -p $c
    done
}

build_clusters() {
    echo "Creating ArgoCD clusters"
    for c in "${CLUSTERS[@]}"
    do
        minikube start -p $c
        minikube addons enable ingress -p $c
    done
}

create_namespace() {
    kubectl --context $CLUSTER create namespace $1
}

install_oidc() {
    helm --kube-context=$CLUSTER -n $NAMESPACE install \
        simple-oidc-provider ../simple-oidc-provider
}

install_prometheus() {
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm --kube-context=$CLUSTER -n $NAMESPACE install \
        prometheus-operator bitnami/prometheus-operator
    
    echo "Waiting for prometheus-operator pod to be Ready..."
    wait_for_pod_ready app.kubernetes.io/component=operator,app.kubernetes.io/instance=prometheus-operator,app.kubernetes.io/name=prometheus-operator
}

install_argo_operator() {
    echo "Installing ArgoCD operator in $NAMESPACE namespace"
    ARGO_OPERATOR_RESOURCES=( service_account role role_binding argo-cd/argoproj.io_applications_crd argo-cd/argoproj.io_appprojects_crd crds/argoproj.io_argocdexports_crd crds/argoproj.io_argocds_crd operator )
    for resource in "${ARGO_OPERATOR_RESOURCES[@]}"
    do
        echo "Applying deploy/$resource.yaml"
        kubectl --context $CLUSTER -n $NAMESPACE \
            apply -f "https://raw.githubusercontent.com/argoproj-labs/argocd-operator/master/deploy/$resource.yaml"
    done
    echo "Waiting for argocd-operator pod to be Ready..."
    wait_for_pod_ready name=argocd-operator
}

install_argo_instance() {
    echo "Installing ArgoCD instance $NAMESPACE"
    NAME=$NAMESPACE-argocd
    cat <<EOF | kubectl create -f -
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: $NAME
  namespace: $NAMESPACE
  labels:
    example: insights
spec:
  grafana:
    enabled: true
    ingress:
      enabled: true
  prometheus:
    enabled: true
    ingress:
      enabled: true
  server:
    insecure: true
    ingress:
        enabled: true
  oidcConfig: |
    name: Simple
    issuer: http://simple-oidc-provider.tpw:9000
    clientID: tpw
    clientSecret: tpw-secret
    # Optional set of OIDC scopes to request. If omitted, defaults to: ["openid", "profile", "email", "groups"]
    requestedScopes: ["openid", "profile", "email"]
    # Optional set of OIDC claims to request on the ID token.
    requestedIDTokenClaims: {"groups": {"essential": true}}
EOF

    echo "Waiting for argocd server to start"
    wait_for_pod_ready app.kubernetes.io/name=$NAMESPACE-argocd-server
    
    echo "Adding ingress hosts to /etc/hosts. You will be asked for your sudo password..."
    echo "`minikube ip -p $CLUSTER` $NAME $NAME-grpc $NAME-grafana $NAME-prometheus" | sudo tee -a /etc/hosts
}

cleanup
build_clusters
create_namespace $NAMESPACE
install_oidc
time install_prometheus
time install_argo_operator
time install_argo_instance