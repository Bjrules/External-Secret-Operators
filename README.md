# Production Grade Harshicorp Vault Setup 
Showing the Use of Harshicorp Vaults to handle secrets in kubernetes 

#### Set Up EKS Cluster
***

- [ ] Install AWS CLI
- [ ] Install Terraform
- [ ] Install kubectl
- [ ] Install ekctl and do this `eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster bnj-cluster --approve` because of the version of EKS module 
- [ ] Install Helm
- [ ] Install EKS Using Terraform `terraform init` and `terraform apply –-auto-approve`

#### Saws eks --region us-east-1 update-kubeconfig --name bnj-cluster
---