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

        stage('Validate Dockerfiles') {
            steps {
                script {
                    def services = ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice']
                    
                    def servicesToCheck = params.SERVICES == 'all' ? services : [params.SERVICES]
                    def validServices = []
                    
                    // Parallel file existence checks
                    def checkTasks = servicesToCheck.collectEntries { service -> 
                        ["check-${service}": {
                            if (fileExists("${service}/Dockerfile")) {
                                validServices << service
                                echo "✅ ${service}: Dockerfile found"
                            } else if (service == 'cartservice' && fileExists("cartservice/src/Dockerfile")) {
                                validServices << service
                                echo "✅ ${service}: src/Dockerfile found"
                            } else {
                                echo "❌ ${service}: No Dockerfile found"
                            }
                        }]
                    }
                    
                    parallel checkTasks
                    
                    if (validServices.isEmpty()) {
                        error "No services with Dockerfiles found to build!"
                    }
                    
                    echo "🚀 Building: ${validServices.join(', ')}"
                    env.VALID_SERVICES = validServices.join(',')
                }
            }
        }

        stage('Build & Push Microservices') {
            steps {
                script {
                    // Single ECR login
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                        """
                    }
                    
                    // Parallel builds for valid services only
                    def services = env.VALID_SERVICES.split(',')
                    def buildTasks = services.collectEntries { service -> 
                        ["${service}": {
                            dir(service) {
                                stage("${service}: Build & Push") {
                                    def buildContext = fileExists('src/Dockerfile') ? 'src' : '.'
                                    sh """
                                        docker build -t ${ECR_URL}/${service}:${TAG} ${buildContext}
                                        docker push ${ECR_URL}/${service}:${TAG}
                                    """
                                    echo "✅ ${service} pushed to ECR: ${ECR_URL}/${service}:${TAG}"
                                }
                            }
                        }]
                    }
                    
                    parallel buildTasks
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
                                    git add "$yaml_file" || true
                                fi
                            done
                            
                            if ! git diff --staged --quiet; then
                                git commit -m "chore(${ENV}): update images to ${TAG} [skip ci]"
                                git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master || true
                                echo "✅ Manifests updated and pushed"
                            else
                                echo "ℹ️ No manifest changes needed"
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
            echo "🎉 SUCCESS: ${params.SERVICES} built and deployed to ${params.ENV}"
        }
        failure {
            echo "💥 FAILED: Check which services need Dockerfiles"
        }
    }
}
