pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: ['all', 'adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice'],
            description: 'Which services to build'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Optional image tag (defaults to BUILD_NUMBER)'
        )
    }

    environment {
        AWS_REGION  = 'us-east-1'
        ECR_ACCOUNT = '163447728448'
        ECR_URL     = "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        TAG         = "${params.IMAGE_TAG ?: env.BUILD_NUMBER}"
        
        GIT_USER_NAME = 'JFKTBonny'
        GIT_EMAIL     = 'jkamkotoyip@yahoo.com'
        GIT_REPO_NAME = 'Microservices-E-Commerce-eks-project'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Microservices') {
            steps {
                script {
                    def allServices = ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice']
                    
                    def servicesToBuild = params.SERVICES == 'all' ? allServices : [params.SERVICES]
                    
                    // Filter services that actually have Dockerfiles
                    def validServices = []
                    servicesToBuild.each { service ->
                        if (fileExists("${service}/Dockerfile") || (service == 'cartservice' && fileExists('cartservice/src/Dockerfile'))) {
                            validServices.add(service)
                        }
                    }
                    
                    echo "Building services: ${validServices.join(', ')}"
                    
                    // Login to ECR once
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                        """
                    }
                    
                    // Build each valid service in parallel
                    def buildSteps = validServices.collectEntries { service -> 
                        [ "${service}": {
                            dir(service) {
                                stage("${service}: Build") {
                                    def buildContext = '.'
                                    if (service == 'cartservice' && fileExists('src/Dockerfile')) {
                                        buildContext = 'src'
                                    }
                                    
                                    sh """
                                        docker build -t ${ECR_URL}/${service}:${TAG} ${buildContext}
                                        docker push ${ECR_URL}/${service}:${TAG}
                                    """
                                }
                            }
                        }]
                    }
                    
                    parallel buildSteps
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
                            git checkout master || git checkout -b update-manifests-${BUILD_NUMBER}
                            git config user.email "${GIT_EMAIL}"
                            git config user.name "${GIT_USER_NAME}"
                            
                            services="adservice cartservice paymentservice checkoutservice currencyservice emailservice frontend productcatalogservice recommendationservice shippingservice"
                            
                            for service in $services; do
                                yaml_file="${service}.yaml"
                                if [ -f "$yaml_file" ]; then
                                    sed -i "s|image:.*|image: ${ECR_URL}/${service}:${TAG}|g" "$yaml_file"
                                    git add "$yaml_file"
                                fi
                            done
                            
                            if git diff --staged --quiet; then
                                echo "No manifest changes to commit"
                            else
                                git commit -m "chore(${ENV}): update ${SERVICES} images to ${TAG} [skip ci]" || true
                                git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master || true
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "✅ Pipeline completed successfully for ${params.SERVICES} in ${params.ENV}"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
