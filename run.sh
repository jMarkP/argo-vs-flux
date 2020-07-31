CLUSTER_PREFIX=site
CLUSTERS=( "$CLUSTER_PREFIX-1-s" "$CLUSTER_PREFIX-2-s" "$CLUSTER_PREFIX-1-p" "$CLUSTER_PREFIX-2-p" )

cleanup() {
    echo "Deleting any clusters from previous runs"
    TO_DELETE=( $( kubectl config get-contexts -o name | grep "^$CLUSTER_PREFIX-" ) )
    for cluster in "${TO_DELETE[@]}"
    do
        minikube delete -p $cluster
    done
}

build_clusters() {
    echo "Creating ArgoCD clusters"
    for cluster in "${CLUSTERS[@]}"
    do
        minikube start -p $cluster
    done
}

cleanup
build_clusters

sh ./argocd/run.sh