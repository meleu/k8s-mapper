# Kubernetes Mapper

A script that iterates through GCP projects/clusters/namespaces and create markdown files with diagrams with all k8s objects for each namespace in the cluster.


## Dependencies

- [k8sviz](https://github.com/mkimuram/k8sviz) - The *real* magic comes from this tool.
- [docker](https://docs.docker.com/engine/install/) - the k8sviz.sh script calls a container to run the application to generate the images.
- [gcloud](https://cloud.google.com/sdk/docs/install) - to get the list of clusters
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) - to get the list of namespaces


## Installation

First install `k8sviz.sh` script (remember to put it in your `$PATH`):
```bash
# check the official readme if this doesn't work.
# https://github.com/mkimuram/k8sviz#installation
curl -LO https://raw.githubusercontent.com/mkimuram/k8sviz/master/k8sviz.sh
chmod u+x k8sviz.sh
# NOTE: be sure to put k8sviz.sh in your path!
```

Now install the `k8s-mapper.sh` (again: remember to put it in your `$PATH`).
```bash
curl -LO https://raw.githubusercontent.com/meleu/k8s-mapper/master/k8s-mapper.sh
chmod u+x k8s-mapper.sh
# NOTE: be sure to put k8s-mapper.sh in your path!
```


## Usage

Simply call the script passing the GCP project names as arguments.

Example:
```bash
k8s-mapper.sh my-project1 my-other-project2
```

The markdown file(s) will be created in a directory named `k8s-maps`.

The images are going to be stored in subdirectories named like `${gcpProject}/${clusterName}/`.


