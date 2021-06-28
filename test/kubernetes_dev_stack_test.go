package test

import (
	"fmt"

	"os/exec"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
)

// A simple smoke test to validate the dev kubernetes deployment
func TestDevelopmentKubernetesDeployment(t *testing.T) {
	t.Parallel()

	kubeNamespace := "heal-devops-app"
	kubeSvcName := "heal-devops-app-web"

	// Fetch the hostname of the AWS load balancer for the service.
	endpoint, err := exec.Command(
		"kubectl",
		"get",
		"svc",
		"-n",
		kubeNamespace,
		kubeSvcName,
		"--output",
		"jsonpath={.status.loadBalancer.ingress[0].hostname}",
	).Output()
	if err != nil {
		t.Fatal(err)
	}

	// Check for a `200` response with the expected response body
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		fmt.Sprintf("http://%s", endpoint),
		nil,
		30,
		10*time.Second,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, "jid")
		},
	)
}
