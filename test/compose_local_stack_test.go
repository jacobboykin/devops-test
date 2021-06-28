package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/docker"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
)

// A simple smoke test to validate the local deployment
func TestLocalDockerComposeDeployment(t *testing.T) {
	t.Parallel()

	serverPort := 5000
	url := fmt.Sprintf("http://localhost:%d", serverPort)

	dockerOptions := &docker.Options{
		// Directory where docker-compose.yml lives
		WorkingDir: "./",
	}

	// Shut down the Docker container at the end of the test
	defer docker.RunDockerCompose(t, dockerOptions, "down")

	// Run Docker Compose to fire up the app stack. We run it in the background (-d)
	// so it doesn't block this test
	docker.RunDockerCompose(t, dockerOptions, "up", "-d")

	// Check for a `200` response with the expected response body
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		15,
		3*time.Second,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, "jid")
		},
	)

}
