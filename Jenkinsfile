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
                expression { params.SERVICES != '' }
            }
            steps {
                script {
                    def servicesToBuild = params.SERVICES == 'all' ? 
                        ['adservice', 'cartservice', 'paymentservice', 'checkoutservice', 'currencyservice', 'emailservice', 'frontend', 'loadgenerator', 'productcatalogservice', 'recommendationservice', 'shippingservice'] : 
                        [params.SERVICES]

                    def parallelSteps = [:]
                    servicesToBuild.each { service ->
                        parallelSteps["${service}"] = {
                            buildService(service)
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
                                # Clean workspace and ignore temp files
                                git clean -fd || true
                                rm -rf .git/@tmp || true
                                
                                # Force sync with remote master
                                git fetch origin
                                git checkout origin/master -f
                                git reset --hard origin/master
                                
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
                                            echo "✅ Updated image tag in \$yaml_file"
                                        fi
                                    else
                                        echo "⚠️  \$yaml_file not found, skipping"
                                    fi
                                done

                                if [ "\$changes_made" = true ]; then
                                    git commit -m "chore(\${ENV}): update service images to ${tag}" || { echo "Commit failed"; exit 1; }
                                    git push https://\${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:master || { echo "Push failed"; exit 1; }
                                    echo "✅ Successfully updated and pushed manifests"
                                else
                                    echo "ℹ️  No changes to commit"
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
        }
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed"
            sh 'ls -la kubernetes-files/ || true'
        }
    }
}

def buildService(service) {
    def serviceDirs = [
        'adservice': 'src/adservice',
        'cartservice': 'cartservice',
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
    
    def serviceDir = serviceDirs[service] ?: "src/${service}"
    
    if (!fileExists(serviceDir)) {
        echo "⚠️  Directory ${serviceDir} not found, skipping ${service}"
        return
    }
    
    dir(serviceDir) {
        echo "📁 Building ${service} from ${pwd()}"
        sh 'ls -la'
        
        if (hasDockerfile()) {
            def tag = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
            sh """
                docker build -t ${service}:${tag} .
            """
            
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                sh """
                    aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_URL}
                    docker tag ${service}:${tag} ${env.ECR_URL}/${service}:${tag}
                    docker push ${env.ECR_URL}/${service}:${tag}
                """
            }
            echo "✅ ${service}:${tag} built and pushed successfully"
        } else {
            echo "⚠️  No Dockerfile found for ${service}, skipping build"
        }
    }
}

def hasDockerfile() {
    return fileExists('Dockerfile') || fileExists('dockerfile')
}
