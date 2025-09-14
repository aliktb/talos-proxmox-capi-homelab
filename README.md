# Talos Proxmox CAPI Homelab

## Description

This repo contains config for deploying a Kubernetes cluster based on
[Talos](https://www.talos.dev/) using [Cluster
API](https://github.com/kubernetes-sigs/cluster-api) (CAPI)

### Motivation

I want a quick, declarative way to deploy a "production-grade" Kubernetes
cluster of multiple control plane and worker nodes. "production-grade" is used
loosely here as my homelab is no datacenter. [Talos](https://www.talos.dev/)
makes it easy to create a fully-functional Kubernetes cluster, providing a
minimal OS with just enough to run Kubernetes, automatic bootstrapping of ETCD
and ensure communication between Kubernetes components is handled over TLS

[Cluster API](https://github.com/kubernetes-sigs/cluster-api) is a way to
create clusters on various platforms, bare-metal/on-prem as well as cloud.
Unfortunately, Sidero Labs have identified shortcomings of CAPI when it comes
to non-cloud environments [as noted in this
comment](https://github.com/siderolabs/cluster-api-bootstrap-provider-talos/issues/193#issuecomment-2449472526).
However, for the time being, I will explore CAPI as my tool of choice for the
creation/management of my homelab cluster(s)

Note, this repo will only contain the config for creating the cluster(s). All
infrastructure deployed _into_ the cluster is not included in this repo

## Credits

This is heavily inspired by [capi-talos-proxmox](https://github.com/une-tasse-de-cafe/capi-talos-proxmox),
thanks to an amazing article written by [Quentin
JOLY](https://github.com/qjoly) available at
<https://a-cup-of.coffee/blog/talos-capi-proxmox/>

The config in this repo aims to update the manifests to the latest API versions
and provide a simple way to bootstrap a production-grade Kubernetes cluster
inside my homelab on Proxmox

## Cluster API Providers

We will be using pre-configured CAPI providers:

- Bootstrap Provider: [Talos bootstrap provider](https://github.com/siderolabs/cluster-api-bootstrap-provider-talos/releases/latest/)
- Infrastructure Provider: [IONOS Proxmox Provider](https://github.com/ionos-cloud/cluster-api-provider-proxmox/releases/latest/)
- IPAM Provider: [in-cluster](https://github.com/kubernetes-sigs/cluster-api-ipam-provider-in-cluster/releases/latest/)
- Control Plane Provider: [Talos Control Plane
Provider](https://github.com/siderolabs/cluster-api-control-plane-provider-talos/releases/latest/)
(CACPPT)

By default, CAPI will use the latest versions. However, you could specify the
versions in `~/.cluster-api/clusterctl.yaml` as follows:

```yaml
providers:
- name: "talos"
  url: "https://github.com/siderolabs/cluster-api-bootstrap-provider-talos/releases/download/v0.6.7/bootstrap-components.yaml"
  type: "BootstrapProvider"
- name: "talos"
  url: "https://github.com/siderolabs/cluster-api-control-plane-provider-talos/releases/download/v0.5.8/control-plane-components.yaml"
  type: "ControlPlaneProvider"
- name: "proxmox"
  url: "https://github.com/ionos-cloud/cluster-api-provider-proxmox/releases/download/v0.6.2/infrastructure-components.yaml"
  type: "InfrastructureProvider"
```

## Prerequisites

A few things need to be installed/available to start. These are:

- A Proxmox instance
  - this doesn't have to be a cluster. It has been tested on a
  standalone server
- Talos ISO from <https://factory.talos.dev/>
  - This needs to be uploaded to Proxmox so we can create VMs with this image
  - This needs to have the Qemu Guest Agent installed
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start#install-clusterctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [kind](https://kind.sigs.k8s.io/)
  - Docker or Podman are required to be installed locally for this
- [yq](https://github.com/mikefarah/yq)

### Template VM

A VM also has to be created in Proxmox ahead of time. Currently this is done
manually. However, this could be automated with the Proxmox APIs. This VM will
be used as a template for both control plane and worker nodes. The CAPMOX
provider will resize the VMs, so the template config doesn't matter _too_ much.
Create the VM as follows:

- VM ID of `125` (else, you can adapt the manifests in this repo)
- OS ISO from prerequisites
- __Qemu Agent enabled__
- 20GB disk space
- 1 CPU core and 1 CPU socket
- 2048 MiB memory
- default bridge network (usually `vmbr0`)

This VM does not need to be started

### Proxmox credentials

We need to generate a user/token in Proxmox to allow us to authenticate with the
Proxmox APIs to provision VMs via Cluster API. This can be done in the Proxmox
__host__ shell (i.e. not a VM shell):

```bash
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role Administrator
pveum user token add capmox@pve capi -privsep 0
```

Make a note of the token as this won't be shown again.

Create a `proxmox.env` file from the example file:

```bash
cp proxmox.env.example proxmox.env
```

Populate the token that was just obtained, along with the IP of the Proxmox machine

> [!CAUTION]
>
> Currently, this uses __FULL ADMINISTRATOR__ privileges.
> `PVEVMAdmin` _may_ have previously worked, but it seems like it has some missing
> permissions as of PVE v9. To configure the Proxmox user properly, see the
> official IONOS CAPMOX docs:
> [Proxmox RBAC with least privileges](https://github.com/ionos-cloud/cluster-api-provider-proxmox/blob/main/docs/advanced-setups.md#proxmox-rbac-with-least-privileges)

## Usage

### Create management and workload clusters

Assuming all the prerequisite components have been installed/configured, we can
now provision the management cluster and then our workload cluster. A small bash
script has been written to perform both parts in sequence. This can be executed
as:

```bash
bash scripts/init.sh
```

This will take a few minutes

> [!TIP]
>
> You can watch the progress with:
>
> ```bash
> watch kubectl get proxmoxcluster,cluster,taloscontrolplane,ProxmoxMachineTemplate,machine,proxmoxmachine,TalosConfigTemplate
> ```
>
> assuming the `watch` utility has been installed on your OS
>
> You can also view the logs at:
>
> ```bash
> kubectl stern -n capmox-system capmox-controller-manager
> ```
>
> Assuming [stern](https://github.com/stern/stern) has been installed as a
> `kubectl` plugin. See [krew](https://krew.sigs.k8s.io/) docs on more info
> regarding `kubectl` plugins

After all nodes (`machine.cluster.x-k8s.io`) are showing as `READY` and
`AVAILABLE` being `true`, we now have our workload cluster up and running and
ready to go! 🎉

### Get Kubeconfig

Use the script [get-kubeconfig.sh](./scripts/get-kubeconfig.sh) to retrieve the
`kubeconfig` of the _workload_ cluster as follows:

```bash
bash scripts/get-kubeconfig,sh
```

You can now use this `kubeconfig` as-is. E.g:

```bash
kubectl --kubeconfig=kubeconfig get nodes

kubectl --kubeconfig=kubeconfig get pods -A
```

Alternatively, you can set the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=~/path/to/this/repo/relative/to/home/directory/kubeconfig
```

Then you can do:

```bash
kubectl get nodes
kubectl get pods -A
```

> [!IMPORTANT]
>
> Don't get confused between the management and workload clusters if setting the
> `KUBECONFIG` environment variable. You would need to `unset KUBECONFIG` if
> wanting to go back to the management cluster

Alternatively, you can merge the `kubeconfig` file in with the main
`~/.kube/kubconfig` file and use `kubectl` contexts to switch between clusters

### Teardown

To teardown, assume the `kubeconfig`/context of the management cluster and run:

```bash
bash scripts/teardown.sh
```

Note, this does not tear down the management cluster itself. As it is simply a
local Kind cluster, you can run:

```bash
kind delete cluster
```
