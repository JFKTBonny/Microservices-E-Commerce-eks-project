pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: [
                'all', 
                'adservice', 
                'cartservice', 
                'paymentservice', 
                'checkoutservice', 
                'currencyservice', 
                'emailservice', 
                'frontend', 
                'loadgenerator', 
                'productcatalogservice', 
                'recommendationservice', 
                'shippingservice'
            ],
            description: 'Which services to build'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: "${BUILD_NUMBER}",
            description: 'Optional image tag (defaults to the build number)'
        )
        choice(
            name: 'MAX_PARALLEL',
            choices: ['1', '2', '3', '4'],
            description: 'Maximum number of parallel builds'
        )
    }

    environment {
        AWS_REGION  = "us-east-1"
        ECR_ACCOUNT = "163447728448"
        ECR_URL     = "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        GIT_USER_NAME = "JFKTBonny"
        GIT_EMAIL     = "jkamkotoyip@yahoo.com"
        GIT_REPO_NAME = "Microservices-E-Commerce-eks-project"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Microservices') {
            when {
                expression { params.SERVICES == 'all' || params.SERVICES in ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice'] }
            }
            steps {
                script {
                    def servicesToBuild = []
                    if (params.SERVICES == 'all') {
                        servicesToBuild = ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice']
                    } else {
                        servicesToBuild = [params.SERVICES]
                    }

                    def parallelSteps = [:]
                    servicesToBuild.each { service ->
                        parallelSteps["${service}"] = {
                            if (checkDockerfileExists(service)) {
                                stage("${service} - Build Image") {
                                    def dockerfilePath = getDockerfilePath(service)
                                    def tag = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
                                    sh """
                                        echo "Building ${service} with tag ${tag}"
                                        docker build -f ${dockerfilePath} -t ${service}:${tag} .
                                    """
                                }
                                stage("${service} - Push to ECR") {
                                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                        def tag = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
                                        sh """
                                            echo "Logging in to ECR and pushing ${service}:${tag}"
                                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                                            docker tag ${service}:${tag} ${ECR_URL}/${service}:${tag}
                                            docker push ${ECR_URL}/${service}:${tag}
                                        """
                                    }
                                }
                            } else {
                                echo "⚠️ Dockerfile not found for ${service}, skipping build."
                            }
                        }
                    }
                    // Limit parallel execution
                    def maxParallel = params.MAX_PARALLEL.toInteger()
                    parallel(parallelSteps)
                }
            }
        }

        stage('Update Kubernetes Manifests') {
            when {
                expression { params.SERVICES != 'loadgenerator' }
            }
            steps {
                dir('kubernetes-files') {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            git checkout master
                            git config user.email "${GIT_EMAIL}"
                            git config user.name "${GIT_USER_NAME}"

                            TAG="${IMAGE_TAG:-$BUILD_NUMBER}"
                            services="adservice cartservice paymentservice checkoutservice currencyservice emailservice frontend productcatalogservice recommendationservice shippingservice"

                            for service in $services; do
                                yaml_file="${service}.yaml"
                                if [ -f "$yaml_file" ]; then
                                    sed -i "s#image:.*#image: ${ECR_URL}/${service}:${TAG}#g" "$yaml_file"
                                    git add "$yaml_file"
                                fi
                            done

                            if git diff --staged --quiet; then
                                echo "No changes to commit"
                            else
                                git commit -m "chore(${ENV}): update service images to ${TAG}"
                                git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git master
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed"
        }
        cleanup {
            sh 'docker image prune -f || true'
        }
    }
}

// Helper functions
def getDockerfilePath(service) {
    return service == 'cartservice' ? 'cartservice/src/Dockerfile' : "src/${service}/Dockerfile"
}

def checkDockerfileExists(service) {
    def dockerfilePath = getDockerfilePath(service)
    return fileExists(dockerfilePath)
}
