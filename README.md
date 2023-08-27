# Scaling MobilityDB in AWS Cloud Services

This repository show how to distributes PostgreSQL database on Elastic Kubernetes Service (EKS) provided by AWS cloud provider. The goal is to scaling moving object database supported by MobilityDB extension for PostgreSQL in order to idealize the performance. We have chosen Citus extension for PostgreSQL, to partitioning the data and distributing the query across the cluster.


[MobilityDB](https://github.com/ULB-CoDE-WIT/MobilityDB) is an open source software program that adds support for temporal and spatio-temporal objects to the [PostgreSQL](https://www.postgresql.org/) database and its spatial extension [PostGIS](http://postgis.net/).

Citus is a PostgreSQL-based distributed RDBMS. Is an open source extension build on top of PostgreSQL, it transform a PostgreSQL database into a distributed environment to enable the horizontal scalability, Citus employs distributed tables, reference tables, and a distributed SQL query engine. The query engine parallelizes SQL queries across multiple servers in a database cluster to deliver results with reduced response times, even for data-intensive applications. For more information, see the [Citus Data website](http://docs.citusdata.com/en/v10.1/).

Requirements
------------

*   AWS account
*   docker latest version
*   kubectl client to deploy application/images from your host machine 
*	eksctl client to manage the AWS cluster from your host machine


Both approachs need to build the mobilitydb-aws image.

### Setting Up the Cloud-Native Docker Container 
If you're planning to deploy Citus on top of MobilityDB along with its essential requirements as a Docker container within your cluster, the following set of Bash commands should be executed on all nodes of your cluster. This applies specifically if you're opting for a deployment using a Citus cluster.

In case you're deploying this on an Amazon EKS cluster, run these commands using the 'kubectl' command directly from your local machine. Here's how:  
```bash
git clone https://github.com/MobilityDB/MobilityDB-AWS.git
cd MobilityDB-AWS
docker build -t bouzouidja/mobilitydb-aws .
```

Or you can pull the image directely from the docker hub

```bash
docker pull bouzouidja/mobilitydb-aws:latest
```
This process ensures that Citus, along with MobilityDB and its prerequisites, is properly set up within a cloud-native Docker container, ready to be deployed and orchestrated within your chosen cluster environment.          

Deployment Using EKS Cluster
------------

### Prerequisite Installation
Prior to proceeding with this step, it's assumed that you've already established an AWS Kubernetes cluster using the EKS command-line tools.

1. Install kubectl
```bash
curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl
# Check the SHA-256 sum for your downloaded binary.
openssl sha1 -sha256 kubectl

# Apply execute permissions to the binary.
chmod +x ./kubectl

# Copy the binary to a folder in your PATH. If you have already installed a version of kubectl, then we recommend creating a $HOME/bin/kubectl and ensuring that $HOME/bin comes first in your $PATH.

mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin

# (Optional) Add the $HOME/bin path to your shell initialization file so that it is configured when you open a shell. 
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

# After you install kubectl , you can verify its version with the following command: 
kubectl version --short --client
````

2. Install eksctl
```bash
# Download and extract the latest release of eksctl with the following command. 
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
# Move the extracted binary to /usr/local/bin. 
sudo mv /tmp/eksctl /usr/local/bin
# Test that your installation was successful with the following command.
eksctl version
```

3. Install and configure the AWS CLI (Command Line Interface) environment

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
# aws-cli/2.1.29 Python/3.7.4 Linux/4.14.133-113.105.amzn2.x86_64 botocore/2.0.0
```
AWS requires that all incoming requests are cryptographically signed. These are the most important security information need to be set up in your host machine in order to manage your AWS services remotely. 

[Access Key ID](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-creds)


[Secret access Key](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-creds)


[AWS Region](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-region)


[Output Format](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-format)

Navigate to https://console.aws.amazon.com/iam/home#/home
- In the navigation pane, choose Users.

- Choose the name of the user whose access keys you want to create, and then choose the Security credentials tab.

- In the Access keys section, choose Create access key.

- To view the new access key pair, choose Show. You will not have access to the secret access key again after this dialog box closes. Save the access key id and the secret access key somewhere.
Now run AWS configure and copy past them in their corresponding parameter

```bash
aws configure
# AWS Access Key ID [****************FZQ2]: 
# AWS Secret Access Key [****************RVKZ]: 
# Default region name [eu-west-3]: 
# Default output format [None]: 
```
You can use the default region as the nearest one from you. In my case i have used eu-west-3 region (Paris).
At this stage we can manage our AWS services remotely from our machine through the credentials stored on the file named credentials located in: 
```bash
~/.aws/credentials
```

### Create an Amazon EKS Cluster

1. Run the following eksctl command to create a cluster using Elastic Kubernetes Service
```bash
eksctl create cluster \
 --name mobilitydb-aws-cluster \
 --version 1.20 \
 --region eu-west-3 \
 --nodegroup-name linux-nodes \
 --node-type m5.large \
 --ssh-access \
 --nodes 3 
```

When specifying the node-type parameter, you have the freedom to designate the resource type for the newly created node. AWS presents an array of resource types to choose from. In my scenario, I've chosen the m5.large instance type. This type offers 2 CPUs, 8GB of RAM, and 10GB of storage capacity. For your convenience, the complete catalog of available node types can be found [here](https://eu-west-3.console.aws.amazon.com/ec2/v2/home?region=eu-west-3#LaunchInstanceWizard:).

 The ssh-access option used to accept ssh connection if you want to access to your EC2 instances created via ssh.

You can customize your cluster creation according to your needs, run eksctl create cluster --help to see all the options.

The creation process take about 20 minutes of time.

If you want to delete the cluster with all the ressources created just use:
```bash
eksctl delete cluster --name mobilitydb-cluster
```` 

2. View the cluster's ressources

```bash
kubectl get nodes
# You should see your EC2 node as this:
# NAME                                           STATUS   ROLES    AGE     VERSION
# ip-192-168-47-163.eu-west-3.compute.internal   Ready    <none>   8m56s   v1.20.4-eks-6b7464
# ip-192-168-9-100.eu-west-3.compute.internal    Ready    <none>   8m48s   v1.20.4-eks-6b7464
# ip-192-168-95-188.eu-west-3.compute.internal   Ready    <none>   8m52s   v1.20.4-eks-6b7464

```
You should see three nodes created in the terminal and in the AWS interface for EC2 instances [here](https://eu-west-3.console.aws.amazon.com/ec2/v2/home?region=eu-west-3#Instances:instanceState=running)



### Deploy mobilitydb-aws Image Using kubectl

We have prepared a manifest yaml file that define the environment of our workload MobilityDB in AWS. It contain the basics information and configuration to configure our Kubernetes cluster.

The deployment instance is employed to delineate the utilization of the "mobilitydb-aws" Docker image, along with the configuration of the mounted volume path. Additionally, the number of replications is determined for our deployment, a step aimed at enhancing overall availability.
configMap instance defined the environement information (postgres user, password, database name).

The most important objects is the PersistentVolume and PersistentVolumeClaim that enables to define the class of storage, device and file system that store our MobilityDB data. AWS provides different classes of storages, for more information see [this](https://docs.aws.amazon.com/eks/latest/userguide/storage.html). 

The PersistentVolumeClaim parameter outlines the specific request and access parameters to be employed for querying our PersistentVolume. Each PersistentVolumeClaim incorporates an access type policy, namely ReadWriteOnce, ReadOnlyMany, or ReadWriteMany. Essentially, it operates as a pod responsible for overseeing access to our storage resources.

Upon the creation of an EKS cluster, the PersistentVolume is automatically configured to utilize the gp2 driver, representing the General Purpose SSD class. This class is backed by Amazon EBS (Elastic Block Store) technology.

Use this command to see the default storage class.
```bash
kubectl get storageclass
# NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  15d
```
If you want to create your own storage class and set it as default, follow [this guides](https://docs.aws.amazon.com/eks/latest/userguide/storage-classes.html)

Finnaly the service instance used to expose our MobilityDB workload. All thoses configuration can be updated according to your workload needs.

Putting it all together in mobilitydb-aws-workload.yaml file. Run this command to initialize all the instances. 
```bash
kubectl apply -f mobilitydb-aws-workload.yaml

# deployment.apps/mobilitydb-aws created
# persistentvolume/postgres-pv-volume unchanged
# persistentvolumeclaim/postgres-pv-claim unchanged
# configmap/postgres-config unchanged
# service/mobilitydb-aws created

```
Now you should see all instances running.
```bash
kubectl get all

# NAME                                    READY   STATUS    RESTARTS   AGE
# pod/mobilitydb-aws-7d745544dd-dkm7k   1/1     Running   0          43s

# NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# service/kubernetes         ClusterIP   10.100.0.1      <none>        443/TCP          15d
# service/mobilitydb-aws   NodePort    10.100.38.140   <none>        5432:30200/TCP   69m

# NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/mobilitydb-aws   1/1     1            1           69m

# NAME                                          DESIRED   CURRENT   READY   AGE
# replicaset.apps/mobilitydb-aws-7d745544dd   1         1         1       69m

````

At this stage you can run your psql client to confirm that the mobilitydb-aws is deployed successfully.
To run the psql, you need to know on which node the MobilityDB pod is running. the following command show details informations including the ip address that host the mobilitydb-aws.  
```bash
kubectl get pod -owide

# NAME                                READY   STATUS    RESTARTS   AGE     IP               NODE                                          NOMINATED NODE   READINESS GATES
# mobilitydb-aws-7d745544dd-dkm7k   1/1     Running   0          100s   192.168.45.32   ip-192-168-60-10.eu-west-3.compute.internal   <none>           <none>


```
In my case, mobilitydb-aws have pod name as mobilitydb-aws-7d745544dd-dkm7k and is running in the node 192.168.45.32.

Given that we possess both the host IP and the name of the pod responsible for operating our scaled MobilityDB environment instance, we can leverage the subsequent command to establish a connection with our PostgreSQL database. To validate the successful creation of the Citus and MobilityDB extensions, we can execute our psql client directly within the mobilitydb-aws pod.

```bash

kubectl exec -it  mobilitydb-aws-7d745544dd-dkm7k -- psql -h 192.168.45.32 -U postgres -p 5432 postgres

# Password for user postgres: 
# psql (13.3 (Debian 13.3-1.pgdg100+1))
# SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
# Type "help" for help.

# postgres=# \dx
#                                       List of installed extensions
#     Name    | Version |   Schema   |                             Description                             
# ------------+---------+------------+-------------------------------------------------#--------------------
# citus      | 10.1-1  | pg_catalog | Citus distributed database
#  mobilitydb | 1.0     | public     | Temporal datatypes and functions
# plpgsql    | 1.0     | pg_catalog | PL/pgSQL procedural language
# postgis    | 2.5.5   | public     | PostGIS geometry, geography, and raster spatial types and functions
#(4 rows)

#postgres=# 


```
### Testing MobilityDB
To enhance the capabilities of MobilityDB queries, a single-node Citus setup has been implemented. This configuration establishes shards for distributed tables, thereby augmenting the overall query performance.
To facilitate the simulation of MobilityDB queries, a straightforward dataset derived from AIS (Automatic Identification System) data has been prepared. This dataset has been meticulously curated to enable the emulation of MobilityDB queries. You can access this dataset [here](https://github.com/MobilityDB/MobilityDB-AWS/tree/master/data). You can mount more data in the /mnt/data from host machine to the Cloud in order to test complex analytics queries.  
Also we have prepared the MobilityDB environement in order to use the queries of the AIS workshop. The extension MobilityDB and citus is created, the table aisinput already created and filled with the mobility_dataset.csv. Finally the aisinput is partitioned using Citus distribute table as single node. 


Select some aisinput.
```bash


# postgres=# select t, mmsi, geom from aisinput limit 5 ; 
#           t          |   mmsi    |                        geom                        
# ---------------------+-----------+----------------------------------------------------
#  2018-01-11 00:00:00 | 265797590 | 0101000020E6100000E36F7B82C49E29405FEE93A300EF4B40
#  2018-01-11 00:00:00 | 266205000 | 0101000020E6100000EA08E066F12A25403946B247A8DB4C40
#  2018-01-11 00:00:00 | 219000615 | 0101000020E6100000894160E5D0AA2040D31742CEFBBB4B40
#  2018-01-11 00:00:00 | 219005302 | 0101000020E6100000D447E00F3FEF2840C780ECF5EE794B40
#  2018-01-11 00:00:00 | 565036000 | 0101000020E6100000EAAF5758708F1E40C6F99B5088644C40
# (5 rows)
```

Getting some shards of the AISInput table.
```bash
# postgres=# SELECT shardid, table_name, shard_size FROM citus_shards limit 5 ;
#  shardid | table_name | shard_size 
# ---------+------------+------------
#  102008 | aisinput   |       8192
#  102009 | aisinput   |       8192
#  102010 | aisinput   |       8192
#  102011 | aisinput   |       8192
#  102012 | aisinput   |       8192
#(5 rows)


```

Scaling MobilityDB in EKS Cluster 
------------
As we have a complex MobilityDB queries, we may use the Vertical Autoscaler and the Horizontal Autoscaler provided by AWS services to optimize the cost according to the query needs.

### Vertical Pod Scaling Using the Autoscaler

The vertical scaling that provide AWS it's a mechanism allows us to adjust automatically the pods ressources. This adjustment decrease the cluster cost and can free up cpu and memory to other pods that may need it. The vertical autoscaler analyze the pods demand in order to see if the CPU and memory requirements are appropriate. If adjustments are needed, the vpa-updater relaunches the pods with updated values. 

To deploy the vertical autoscaler, follow these steps:
```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
``` 
deploy the autoscaler pods to your cluster
```bash

./hack/vpa-up.sh
```

Check the vertical autoscaler pods 

```bash
kubectl get pods -n kube-system

# NAME                                       READY   STATUS    RESTARTS   AGE
# aws-node-rx54z                             1/1     Running   0          17d
# aws-node-ttf68                             1/1     Running   0          17d
# coredns-544bb4df6b-8ccvm                   1/1     Running   0          17d
# coredns-544bb4df6b-sbqhz                   1/1     Running   0          17d
# kube-proxy-krz8w                           1/1     Running   0          17d
# kube-proxy-lzm4g                           1/1     Running   0          17d
# metrics-server-9f459d97b-vtd6n             1/1     Running   0          3d11h
# vpa-admission-controller-6cd546c4f-g94vr   1/1     Running   0          38h
# vpa-recommender-6855ff754-f4blx            1/1     Running   0          38h
# vpa-updater-9fd7bfbd5-n9hpn                1/1     Running   0          38h

``` 

Scaling Citus Cluster Using AWS EC2 Instances
------------

### Scaling MobilityDB as Standalone Mode
Before doing this step you need to connect within your AWS EC2 machine known as master node. We have already create and configure one AWS EC2 host master node and some AWS EC2 host worker node.
- You can run the image as standalone using docker run command, Execute this on all cluster's nodes.
```bash
sudo ssh -i YourKeyPairGenerated.pem ubuntu@EC2_Public_IP_Address

docker run --name mobilitydb-aws-standalone -p 5432:5432 -e POSTGRES_PASSWORD=postgres bouzouidja/mobilitydb-aws:latest 

``` 
You can specify the mount volume option in order to fill the mobilityDB dataset from your host machine by adding -v /path/on/host_mobilitydb_data/:/path/inside/container_mobilitydb_data

After running the mobilitydb-aws instance, you can add and scale manually your database using the citus query.

```sql
select * from citus_add_node('new-node', port);
```
Check wether if the new-node is added correctely in the cluster.
```sql
select master_get_active_worker_nodes();
-  master_get_active_worker_nodes
-- --------------------------------
--  (new-node,5432)
-- (1 row)
```
Create MobilityDB table and distribute it on column_dist in order to create shards by hashing the column_dist values. If no nodes added on the cluster than the distribution is seen as single node Citus otherwise is multi nodes Citus.

```sql
CREATE TABLE mobilitydb_table(
column_dist integer,
T timestamp,
Latitude float,
Longitude float,
Geom geometry(Point, 4326)
);

SELECT create_distributed_table('mobilitydb_table', 'column_dist');
```
fill free to fill the table mobilitydb_table before or after the distribution. At this stage you can run MobilityDB queries on the citus cluster.



### Scaling MobilityDB Using Citus Manager
This deployment sets up the Citus manager node, which listens for new containers with the worker role and updates the configuration file shared with the master node. This orchestration facilitates the scaling of MobilityDB using the Citus manager within the established environment.

- In the same repository mobilitydb-aws, run the image as Citus cluster using this following

```bash
docker-compose -p mobilitydb-aws up

# Creating network "citus_default" with the default driver
# Creating citus_worker_1
# Creating citus_master
# Creating citus_config
# Attaching to citus_worker_1, citus_master, citus_config
# worker_1    | The files belonging to this database system will be owned by user "postgres".
# worker_1    | This user must also own the server process.
# ...

```
To scale the Citus cluster and achieve improved performance and capacity, you can initiate the deployment of additional workers by executing the following command:
```bash
docker-compose -p mobilitydb-aws scale worker=5

# Creating and starting 2 ... done
# Creating and starting 3 ... done
# Creating and starting 4 ... done
# Creating and starting 5 ... done

```
By running this command, you're dynamically increasing the number of worker containers, which can lead to improved performance and scalability in your Citus cluster.