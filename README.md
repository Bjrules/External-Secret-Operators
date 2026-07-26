# Production Grade Harshicorp Vault Setup 
Showing the Use of Harshicorp Vaults to handle secrets in kubernetes 

### Set-Up EKS Cluster
***

- [ ] Install AWS CLI
- [ ] Install Terraform
- [ ] Install kubectl
- [ ] Install ekctl and do this `eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster bnj-cluster --approve` because of the version of EKS module 
- [ ] Install Helm
- [ ] Install EKS Using Terraform `terraform init` and `terraform apply –-auto-approve`






`eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster bnj-cluster --approve`

 `aws eks --region us-east-1 update-kubeconfig --name bnj-cluster`

 ```
 eksctl create iamserviceaccount \
  --region us-east-1 \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster bnj-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts

 ```
Install kubenetes signature for aws_ebs_csi_driver , nginx Ingress, and Cert Manager

 ```
 kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.11"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

 ```

---
### Set Up Hashicorp Vault. Prod Style

-[ ] Create Namespace for Vault `kubectl create namespace vault` Note: the name must be `vault`
