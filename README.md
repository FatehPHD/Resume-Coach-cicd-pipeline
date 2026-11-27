# Resume Coach – CI/CD Pipeline

ENSF 519 (Principles of DevOps), Fall 2026, final project for **Group 9**: Fateh Ali Bukhari and Muhammad Zain.

A commit to `main` starts a chain of 7 Jenkins jobs. They build the Resume Coach (RCC) web app, test it with Selenium, push the Docker image to Docker Hub, create an AWS server with Terraform, set the server up with Ansible, run the app as a container, and deploy it to Kubernetes.

```
 git push (main)
      │  GitHub webhook
      ▼
 J1 Build ─▶ J2 Selenium ─▶ J3 Docker push ─▶ J4 Terraform ─▶ J5 Ansible setup ─▶ J6 Run container ─▶ J7 Kubernetes
 docker      16 UI tests     Docker Hub        AWS EC2           Docker+Minikube      port 80              3 pods, NodePort 30080
 build       on :3000        fatehphd/…        app server        on app server
```

Each job starts the next one only if it **succeeds**, so a failing Selenium test stops the image from reaching Docker Hub or the server.

## The app

**RCC – AI Resume and Career Coach**: upload a resume, score it against a job description, see the missing skills, and practise with an AI interviewer.

- `frontend/`: React 18 single-page app. This is what the pipeline builds and deploys.
- `backend/`: Flask API with PostgreSQL. It isn't containerized by this pipeline; the frontend calls the hosted backend on Render (`REACT_APP_API_BASE`).

## Pipeline stages

All jobs are Jenkins **freestyle** jobs that check out this repo (`*/main`). They're chained with *Build other projects* post-build actions that trigger only on success.

| Job | Required stage | What it runs |
|---|---|---|
| **J1-Dev-Build** | GitHub webhook trigger, Build | Triggered by a **GitHub push** (`GitHubPushTrigger`). Runs `docker build -t fatehphd/web-project:latest .`, a multi-stage build where `node:18-alpine` builds the React app and `nginx:alpine` serves it. |
| **J2-QA-Selenium** | Automated testing | Starts the new image as `web-test` on `localhost:3000`, waits for it to respond, creates a Python venv from `selenium_tests/requirements.txt`, and runs every `logged_out_scripts/test_*.py` under `xvfb-run` (real Chrome, virtual display). It skips 2 scripts that call the production backend. Any failure fails the job, and the test container is always removed afterwards. |
| **J3-Ops-DockerPush** | Docker image build and push | `docker push fatehphd/web-project:latest`. Runs only if J2 passed. |
| **J4-Ops-Terraform** | Server deployment | `terraform init` and `terraform apply -auto-approve` in `terraform/`, which creates or updates the app server (EC2 t3.small, 20 GB, ca-central-1) and its security group. Writes the server's public IP to the Ansible inventory at `/var/lib/jenkins/final-project/inventory` (group `[app]`, user `ubuntu`). |
| **J5-Ops-Ansible** | Server configuration | `ansible/setup-server.yml`: waits for SSH and cloud-init, then installs Docker, kubectl, Minikube, crictl, CNI plugins and containerd, and starts Minikube (`--driver=none`), following the course's D2L Minikube steps. Waits until the node is Ready. |
| **J6-Ops-RunContainer** | Container execution | `ansible/run-container.yml`: pulls `fatehphd/web-project:latest` and runs it as container `web-project` on port 80, replacing the previous one (`--restart unless-stopped`). |
| **J7-Ops-Kubernetes** | Container orchestration | `ansible/deploy-automation.yml` copies `kubernetes/deploy-kubernetes-app.sh` to the server and runs it. It creates or updates the `web-project` deployment, exposes it as a NodePort service on **30080**, scales to **3 replicas**, waits for the rollout, and prints pods, deployments and services. |

J5–J7 connect to the app server with the Jenkins credential **`ec2-ssh-key`** (SSH private key, bound as `$SSH_KEY`).

## Where things run

| Component | Where |
|---|---|
| Jenkins | EC2 `Resume-Coach-cicd-jenkins` (ca-central-1), port 8080 |
| Docker image | Docker Hub `fatehphd/web-project:latest` |
| App server | EC2 `Resume-Coach-cicd-app-server`, created by Terraform (key pair `Resume-Coach-cicd-key`, security group `Resume-Coach-cicd-app-sg`) |
| App as a container | `http://<app-server-ip>/` (port 80) |
| App on Kubernetes | `http://<app-server-ip>:30080/` (Minikube NodePort, 3 pods) |

The app server's IP comes from Terraform's output and is printed in J4's console log.

## Repository layout

```
Dockerfile, nginx.conf, .dockerignore   # image build (J1)
frontend/                               # React app that gets built
backend/                                # Flask API (not deployed by this pipeline)
selenium_tests/                         # Selenium WebDriver scripts (J2) – see selenium_tests/README.md
terraform/main.tf                       # app server + security group (J4)
ansible/setup-server.yml                # Docker + Minikube install (J5)
ansible/run-container.yml               # docker run on port 80 (J6)
ansible/deploy-automation.yml           # runs the Kubernetes script on the server (J7)
kubernetes/deploy-kubernetes-app.sh     # deployment, NodePort 30080, 3 replicas (J7)
```

## Running the pipeline

1. Commit and push to `main`. The GitHub webhook starts **J1**, and the rest follow on their own.
2. Watch the chain in Jenkins (`http://<jenkins-ip>:8080`). Each job's console log shows the evidence for its stage. J7's log ends with the pods, deployment and service.
3. Open the app at `http://<app-server-ip>/` (container) and `http://<app-server-ip>:30080/` (Kubernetes).

A full run takes about 1–2 minutes. On later runs Terraform reuses the existing server, and the Ansible setup skips anything already installed.

## Notes

- **Secrets aren't stored in this repo.** `.env` files, `*.pem` keys and Terraform state are in `.gitignore`. The SSH key is a Jenkins credential. Docker Hub and AWS access are configured on the Jenkins server.
- Security groups allow all traffic from anywhere, as in the course's lab setup.
- **Stop or destroy the EC2 instances when you're not using them, to avoid AWS charges.** A stop/start gives the Jenkins server a new public IP, so the GitHub webhook URL has to be updated afterwards.
