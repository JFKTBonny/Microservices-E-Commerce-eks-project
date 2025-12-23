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
                sh 'ls -la' // Debug: show repo structure
            }
        }

        stage('Build & Push Microservices') {
            when {
                expression { params.SERVICES != '' }
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
                            stage("Build ${service}") {
                                if (shouldBuildService(service)) {
                                    dir(getServiceDir(service)) {
                                        sh "ls -la" // Debug: show service directory
                                        if (hasValidDockerfile(service)) {
                                            def tag = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
                                            sh """
                                                echo "Building ${service} with tag ${tag}"
                                                docker build -t ${service}:${tag} .
                                            """
                                            stage("Push ${service} to ECR") {
                                                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                                    sh """
                                                        echo "Pushing ${service}:${tag} to ECR"
                                                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                                                        docker tag ${service}:${tag} ${ECR_URL}/${service}:${tag}
                                                        docker push ${ECR_URL}/${service}:${tag}
                                                    """
                                                }
                                            }
                                        } else {
                                            echo "⚠️ No valid Dockerfile found for ${service}, skipping"
                                        }
                                    }
                                } else {
                                    echo "⚠️ Skipping ${service} - no source directory found"
                                }
                            }
                        }
                    }
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
                    script {
                        def tag = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
                        withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                            sh """
                                git checkout master || git checkout -b master
                                git config user.email "${GIT_EMAIL}"
                                git config user.name "${GIT_USER_NAME}"

                                services="adservice cartservice paymentservice checkoutservice currencyservice emailservice frontend productcatalogservice recommendationservice shippingservice"

                                changes_made=false
                                for service in \$services; do
                                    yaml_file="\${service}.yaml"
                                    if [ -f "\$yaml_file" ]; then
                                        sed -i "s#image:.*#image: ${ECR_URL}/\$service:${tag}#g" "\$yaml_file"
                                        if [ \$? -eq 0 ]; then
                                            git add "\$yaml_file"
                                            changes_made=true
                                            echo "Updated image tag in \$yaml_file"
                                        fi
                                    fi
                                done

                                if [ "\$changes_made" = true ]; then
                                    git commit -m "chore(${ENV}): update service images to ${tag}"
                                    git push https://\${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git master || git push https://\${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master
                                else
                                    echo "No changes to commit"
                                fi
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
            sh 'docker system prune -f || true'
        }
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed - check missing files in service directories"
            sh 'ls -laR src/ || true'
            sh 'ls -laR . || true'
        }
    }
}

// Service configuration mapping
def getServiceDir(service) {
    def serviceMap = [
        'adservice': 'src/adservice',
        'cartservice': 'cartservice',  // Special case
        'checkoutservice': 'src/checkoutservice',
        'currencyservice': 'src/currencyservice',
        'emailservice': 'src/emailservice',
        'frontend': 'src/frontend',
        'loadgenerator': 'src/loadgenerator',
        'paymentservice': 'src/paymentservice',
        'productcatalogservice': 'src/productcatalogservice',
        'recommendationservice': 'src/recommendationservice',
        'shippingservice': 'src/shippingservice'
    ]
    return serviceMap[service] ?: "src/${service}"
}

def shouldBuildService(service) {
    def serviceDir = getServiceDir(service)
    return fileExists(serviceDir)
}

def hasValidDockerfile(service) {
    def serviceDir = getServiceDir(service)
    def dockerfileCandidates = ['Dockerfile', 'dockerfile', 'Dockerfile.prod']
    for (df in dockerfileCandidates) {
        if (fileExists("${serviceDir}/${df}")) {
            return true
        }
    }
    return false
}
