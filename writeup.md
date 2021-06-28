# Heal Test Application - Cloud Deployment Writeup

## Prerequisites

To follow along with the deployment of the local and development environments, you will need:
1. an AWS account with the IAM permissions listed on the [EKS module documentation](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/iam-permissions.md)
1. a configured AWS CLI
1. `wget` (required for the eks terraform module)
1. `kubectl`
1. Docker Desktop 3.4.0 or newer (for use of `docker compose`, see [this article](https://docs.docker.com/compose/cli-command/))
1. Go (required to run the smoke tests)
1. `terraform` (you can use [tfenv](https://github.com/tfutils/tfenv) to install the version appropriate for this repo)

## Local Environment Deployment

The local development environment is powered by Docker Compose. The following command will deploy the stack and tail the logs:

```
$ make local/deploy
```

You can run a quick smoke test with Go and [Terratest](https://terratest.gruntwork.io/) to validate the deployment is functional (note that this will teardown the Docker Compose deployment when it's done):

```
$ make local/smoke 

[ ... ]

PASS
ok      github.com/jacobboykin/devops-test/test 22.373s
```

## Development Environment Deployment

The development environment hosts the application stack on Kubernetes in an AWS EKS cluster. Ideally, the provisioning and testing of the development environment would be performed in a pipeline powered by Jenkins or another automation platform. For the purposes of this assignment, you can deploy the development environment by completing the following steps:

1. To start, we need to deploy the Docker images to DockerHub. Update the `image` field for the `web` and `worker` services in the `docker-compose.yml` to reference a Docker Registry that you have permissions to push images to. In the real world, we'd ideally push these to a private, secure Docker Registry, such as AWS ECR. Run the following to push the images:
    ```
    $ docker compose push
    ```

1. We'll use Terraform to deploy the EKS Cluster and its prerequisite resources. `aws configure` is ran initially to double-check that you're using the right credentials. This takes around 10-15 minutes on average. 
    ```
    $ make dev/deploy

    [ ... ]

    Apply complete! Resources: 51 added, 0 changed, 0 destroyed.

    [ ... ]
    ```
1. After the EKS cluster has been successfully provisioned, run the following command to update your `kubeconfig` to access the cluster using `kubectl`:
    ```
    $ cd terraform/live/dev
    $ aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
    ```
1. Using Kustomize and `kubectl`, deploy the Kubernetes resources that define the application stack:
    ```
    $ make dev/deploy/app

    kubectl apply -k kubernetes/dev
    namespace/heal-devops-app created
    serviceaccount/heal-devops-app-web created
    serviceaccount/heal-devops-app-worker created
    service/heal-devops-app-web created
    service/redis created
    deployment.apps/heal-devops-app-redis created
    deployment.apps/heal-devops-app-web created
    deployment.apps/heal-devops-app-worker created
    ```
1. After a few minutes, the EKS nodes will have downloaded the Dockerhub images and deployed the workloads successfully:
    ```
    $ kubectl get po -n heal-devops-app

    NAME                                     READY   STATUS    RESTARTS   AGE
    heal-devops-app-redis-76fbdb44b8-7nsgb   1/1     Running   0          79s
    heal-devops-app-web-8445b5f9bc-tlb65     1/1     Running   0          78s
    heal-devops-app-worker-77664bd9c-7hh7p   1/1     Running   0          78s
    ```
1. We can validate the application is functional using the Go smoke test:
    ```
    $ make dev/smoke     
    cd test \
                    && go mod tidy \
                    && go test -run TestDevelopmentKubernetesDeployment
    TestDevelopmentKubernetesDeployment 2021-06-28T01:02:51-07:00 retry.go:91: HTTP GET to URL http://fake-elb-address.us-east-2.elb.amazonaws.com
    TestDevelopmentKubernetesDeployment 2021-06-28T01:02:51-07:00 http_helper.go:32: Making an HTTP GET call to URL http://fake-elb-address.us-east-2.elb.amazonaws.com
    PASS
    ok      github.com/jacobboykin/devops-test/test 1.550s
    ```
1. We can also manually validate the functionality using `curl` and `kubectl`:
    ```
    $ curl -v "http://$(kubectl get svc -n heal-devops-app heal-devops-app-web --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    *   Trying 1.1.1.1 ...
    * TCP_NODELAY set
    * Connected to http://fake-elb-address.us-east-2.elb.amazonaws.com (1.1.1.1) port 80 (#0)
    > GET / HTTP/1.1
    > Host: http://fake-elb-address.us-east-2.elb.amazonaws.com
    > User-Agent: curl/7.64.1
    > Accept: */*
    > 
    < HTTP/1.1 200 OK
    < Content-Type: text/html;charset=utf-8
    < X-XSS-Protection: 1; mode=block
    < X-Content-Type-Options: nosniff
    < X-Frame-Options: SAMEORIGIN
    < Content-Length: 34
    < 
    * Connection #0 to host ahttp://fake-elb-address.us-east-2.elb.amazonaws.com left intact
    {"jid":"ee1b4de76c11247dfdacb823"}* Closing connection 0
    ```
1. Tear it all down!
    ```
    $ make dev/teardown
    ```

## Further Notes and Considerations

The Dev environment, of course, needs a lot more love and should be much more prod-like. I'm a big advocate of Gruntwork's Reference Architecture (see below) and their [Production Readiness Checklist](https://gruntwork.io/devops-checklist/), as well as [The Twelve-Factor App](https://12factor.net/). These resources are the main methodologies I'd pull from to continue the iteration of this app's infrastructure into something more robust, scalable, and secure.

### Vault Secret Deliverable

Assuming secure access to a Vault server is available (VPN or private subnet connection, for example), I think that deploying the [Vault Agent Sidecar Injector](https://www.vaultproject.io/docs/platform/k8s/injector) into the EKS cluster would be a great solution for mounting the connection string environment variables, `MONGODB_URI` and `REDIS_URL`. Check out [this article](https://www.vaultproject.io/docs/platform/k8s/injector/examples) for some great examples of how this can be accomplished. This enables a pattern for secure Vault access, and keeps Vault as the source of truth for Secrets management (rather than Terraform's Vault provider or copying secrets into etcd as Kubernetes Secret resources).

### Reference Architecture Mentioned Above

![Reference Architecture](https://gruntwork.io/assets/img/ref-arch/gruntwork-landing-zone-ref-arch.png)