build:
	docker build -t poridhi/custom-runner:v1.1 .

push:
	docker push poridhi/custom-runner:v1.1

image:
	docker save my-runner:latest -o my-runner.tar
	sudo k3s ctr images import my-runner.tar

namespace:
	kubectl create ns host-runner

secrets:
	kubectl -n host-runner create secret generic github-secret \
		--from-literal=GITHUB_OWNER=Raihan-009 \
		--from-literal=GITHUB_REPOSITORY=self-hosted-runner \
		--from-literal=GITHUB_PERSONAL_TOKEN=""

deploy:
	kubectl -n host-runner apply -f runner.yml

pod:
	kubectl get pods -n host-runner

delete:
	kubectl delete deploy github-runner -n host-runner