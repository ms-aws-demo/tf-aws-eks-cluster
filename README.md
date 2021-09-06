# Provision an EKS Cluster

This repo is a companion repo to the [Provision an EKS Cluster learn guide](https://learn.hashicorp.com/terraform/kubernetes/provision-eks-cluster), containing
Terraform configuration files to provision an EKS cluster on AWS.

^^^ Don't re-invent the wheel if you don't have to, right? ^^^

##### Intro #####

This project is intended to:

-Stand up an EKS cluster and other basic network infrastructure (VPC, subnets, etc)
-Deploy basic Nginx workloads to EKS using Helm
-Create associated IAM roles
    -EKS admins with the ability to manage EKS infrastructure
    -EKS developers with the ability to deploy workloads, but not manage the underlying infrastructure
-Stand up an AWS Elasticsearch domain
-Forward EKS container logs to ES using Fluentd

What it DOESN'T do:

-Allow access to Kibana (would require a proxy and/or workstation IP whitelisting and/or Cognito setup)
-Make any particular distinction between subnets as far as use case (I arbitrarily assigned the Nginx ELB to the us-east-2a subnet). Presumably, one would assign different security groups to different subnets and reserve them for particular purposes--perhaps EKS cluster in one, Elasticsearch in another, and/or associate them with separate AZs.
-Allow external access to load-balancers from outside the VPC.

##### Bootstrapping Requirements #####

In order to bootstrap the Terraform-managed infrastructure, I created a global admin IAM user 'ms-admin-user', followed by an IAM user with only those permissions required for running this project (EKS/EC2/ES/IAM/etc).

I also created another user outside of Terraform, 'cyderes-user', with those same permissions. This is so that this user can be used evaluate this project without being dependent on its outputs. However, in a real-world setting, I would instead prescribe the use of the 'EKS_Admin" and 'EKS_Developer' roles to be assumed by non-admin users.

This project uses S3 as the backend for Terraform state, which required that an S3 bucket be created manually. I'm not exactly sure if there's a way to use Terraform to create the bucket that you also use for the state file, but seems dicey to me.

##### Commands #####

# Running Terraform Locally

Run 'terraform apply' once to create the EKS cluster, then:


```
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

Run Terraform a second time to finish with the Helm deployments, since Helm requires your local kubeconfig to be updated in order to run. It's possible to include this as a provisioner local-exec, but I generally would prefer not to go messing around with someone's local configs without their explicit consent.

# Github Workflow

Or, just let Github do the work.

Once it's set up.

# Accessing nginx

```
kubectl -n nginx-sites port-forward svc/nginx 8443:80
```

...and check http://localhost:8443

##### Security Considerations #####

# Roles

I have only two roles managed by this Terraform project, 'EKS_Admin' and 'EKS_Developer'. The intention is that the Admin role can be delegated to individuals with the responsibility of managing the EKS infrastructure, while the Developer role has read-only access to the infrastructure, but has the ability to deploy workloads to the cluster. Note that both these roles are granted access to THIS cluster only--their policy is resource-limited to the ARN of this cluster.

Similarly, I put Admins in the 'system:masters' group within the Kubernetes aws-auth ConfigMap, but put Developers in the 'system:nodes' group. This is a gross oversimplification of the division of responsibilities (and indeed, best practice is not to use the 'system:masters' group at all, and 'system:nodes' is deprecated), but being limited on time meant skipping further customization of access. With more time, I'd probably also add custom role definitions for the cluster, limit Developers to certain namespaces, etc.

Conceivably, one could create and dole out access keys/secrets for these accounts to the appropriate individuals, which would allow them to perform their jobs, but only to resources within their team's jurisdiction.

Also, MFA should be included as a best-practice, but also would have things slowed down for this demo.

# Access to ES/Kibana

Kibana wasn't explicitly part of the challenge here, but ideally one would want to create a role specifically for being able to access it--or perhaps include ES permissions within the roles already defined here, whatever makes the most sense for the organization. I didn't go too far down that rabbit hole since the 'right' way to handle AWS-managed Kibana access is to use Cognito or some other authenticator--which is a whole other can of worms, and considering I've never used the AWS-managed Elasticsearch stack before, didn't prioritize it here. (I verified that Kibana worked by temporarily whitelisting my own IP in the access policy.)

I considered setting up the Nginx service in EKS as a proxy to Kibana, but again--time constraints and scope creep.

For Elasticsearch, it seemed sufficient to just allow traffic from anywhere within the VPC CIDR block, although in a real-world setting this should probably be more limited to more specific subnets and/or security groups.

It was unfortunate that, after all was said and done, it turns out that the AWS-managed Elasticsearch *isn't supported by Fluentd!* The error I ran into was:

"The client noticed that the server is not a supported distribution of Elasticsearch."

Further digging yielded:

https://github.com/elastic/elasticsearch-py/issues/1666
https://wptavern.com/elastic-hits-back-at-opensearch-making-client-libraries-incompatible-with-amazon-led-open-source-fork

I don't know if Fluentd's libraries are affected by this, but might be worth looking into. Didn't realize this was such a recent event.

There are dozens of ways to work around this, certainly. I could deploy a Logstash instance within EKS itself instead (and have it output to AWS ES, which I assume would work), use a proxy for AWS ES, use a different log aggregator altogether...but again, time is not a limitless quantity here. In principle, I would think this setup *should* work with an 'official' Elasticsearch version.

I have commented out the 'values' section of the Fluentd Helm chart resource in helm.tf so that Terraform doesn't time out trying to set it up (the pods never reach ready status as a result of being unable to write to ES). You can enable it to see for yourself, although this can risk Terraform becoming confused about whether or not the Helm release actually exists, depending on if the Terraform operation is interrupted.

# ELB

I chose not to make the Nginx load-balancer available externally since it's just for test purposes right now (and only displays the welcome page), and I'd rather not risk subjecting this demo account to outside traffic. It's available within the VPC only. You can also access it via port forwarding, and verify that the load balancer exists in the EC2 section of the AWS console.

# Terraform/Github Deployments

Unfortunately, I didn't get to spend as much time on the CI/CD part of the project. Presumably, one would use the Github action for Terraform Cloud workflows. I use the S3 backend at my current job, so I didn't think to set this up using the Terraform backend instead (the more you know...). It doesn't look too difficult, though. I left the option commented out should I want to try it out. For our demo purposes, though, it would be slightly more of a hassle at this point to require Terraform Cloud authentication to use that state file, rather than just the AWS user I provided.

In any case, I'm sure there's all sorts of fun stuff we could do with webhooks and triggers here. For example, let's say our Nginx deployment pulls containers from another Github repository, one only worked on by developers. We could set this up so commits to the main branch on *that* project trigger a Terraform workflow execution on *this* project to pull the latest container image from that repo and update the deployment.

##### Final Thoughts #####

This project was a good learning experience. Honestly, there are lots of little bits I picked up along the way that I'm going to use to tighten up our architecture at my current job. I wish I could have more time to solve every roadblock and curiosity that came up, but at some point working on this is going to displace *actual* work.

So here's what I put together. Not entirely satisfied with the final result, but...

“If you aren’t embarrassed, you shipped too late.”