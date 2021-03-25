package main

import (
	"github.com/jenkins-x/jx-helpers/v3/pkg/gitclient/giturl"
	"path/filepath"
	"testing"

	config "github.com/jenkins-x/jx-api/v4/pkg/apis/core/v4beta1"
	"github.com/jenkins-x/jx-secret/pkg/cmd/populate/templatertesting"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

var (
	// generateTestOutput enable to regenerate the expected output
	generateTestOutput = false

	ns = "jx"
)

func TestSecretSchemaTemplatesMavenSettings(t *testing.T) {
	testSecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "jx-boot",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"username": []byte("gitoperatorUsername"),
				"password": []byte("gitoperatorpassword"),
			},
		},

		// some other secrets used for templating the jenkins-maven-settings Secret
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "nexus",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"password": []byte("my-nexus-password"),
			},
		},
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "sonatype",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"username": []byte("my-sonatype-username"),
				"password": []byte("my-sonatype-password"),
			},
		},
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "gpg",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"passphrase": []byte("my-secret-gpg-passphrase"),
			},
		},
	}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "nexus",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "none",
			ObjectName: "jenkins-maven-settings",
			Property:   "settings.xml",
			Format:     "xml",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					Provider:    "docker",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jx3", "jxboot-helmfile-resources", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}

func TestSecretSchemaTemplatesContainerRegistry(t *testing.T) {
	testSecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "jx-boot",
				Namespace: "jx-git-operator",
			},
			Data: map[string][]byte{
				"username": []byte("gitoperatorUsername"),
				"password": []byte("gitoperatorpassword"),
			},
		}}

	myRegistrySecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "container-registry-auth",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"url":      []byte("my-registry"),
				"username": []byte("my-registry-user"),
				"password": []byte("my-registry-pwd"),
			},
		}}

	anotherRegistrySecrets := []runtime.Object{
		&corev1.Secret{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "container-registry-auth",
				Namespace: ns,
			},
			Data: map[string][]byte{
				"url":      []byte("another-registry"),
				"username": []byte("another-registry-user"),
				"password": []byte("another-registry-pwd"),
			},
		}}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "aks",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "aks-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "aks-another-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: anotherRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "aws",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "aws",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "aws-other-git",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "aws",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "eks",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "eks-other-git",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-my-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-my-registry-secret-other-git",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: myRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   "https://git.myserver.com",
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:    "eks-another-registry-secret",
			ObjectName:  "tekton-container-registry-auth",
			Property:    ".dockerconfigjson",
			Format:      "json",
			KubeObjects: anotherRegistrySecrets,
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "my-registry",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "eks",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},

		{
			TestName:   "gke",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "gke",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
		{
			TestName:   "minikube",
			ObjectName: "tekton-container-registry-auth",
			Property:   ".dockerconfigjson",
			Format:     "json",
			Requirements: &config.RequirementsConfig{
				Repository: "nexus",
				Cluster: config.ClusterConfig{
					DestinationConfig: config.DestinationConfig{
						Registry: "",
					},
					GitServer:   giturl.GitHubURL,
					Provider:    "minikube",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jx3", "jxboot-helmfile-resources", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}

func TestSecretSchemaTemplatesBucketRepo(t *testing.T) {
	testSecrets := []runtime.Object{}

	testCases := []templatertesting.TestCase{
		{
			TestName:   "bucketrepo",
			ObjectName: "bucketrepo-config",
			Property:   "config.yaml",
			Format:     "yaml",
			Requirements: &config.RequirementsConfig{
				Repository: "bucketrepo",
				Cluster: config.ClusterConfig{
					Provider:    "minikube",
					ProjectID:   "myproject",
					ClusterName: "mycluster",
				},
			},
		},
	}
	if generateTestOutput {
		for i := range testCases {
			testCases[i].GenerateTestOutput = true
		}
	}
	runner := templatertesting.Runner{
		TestCases:   testCases,
		SchemaFile:  filepath.Join("..", "charts", "jenkins-x", "bucketrepo", "secret-schema.yaml"),
		Namespace:   ns,
		KubeObjects: testSecrets,
	}
	runner.Run(t)
}
