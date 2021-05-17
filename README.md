# packet-deployer

Deploy Field PM labs on Equinix Metal

## Prerequisites

Input your Equinix metal API key and Openshift pull secret in the script

Feel free to adjust other options (project name, instance type, spot max bid is using spot)

## Usage

```sh packet-deployer.sh deploy

````
deploys <https://github.com/RHFieldProductManagement/openshift-virt-labs> using UPI

```sh packet-deployer.sh deploy ipi
````

deploys <https://github.com/RHFieldProductManagement/openshift-virt-labs> using IPI

```sh packet-deployer.sh clean

````
destroys your previous deployment using infos saved in node-infos.txt

```sh packet-deployer.sh clean <project_id>
````

destroys the specified project and associated server(s)
