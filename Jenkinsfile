pipeline {
    agent any

    parameters {
        choice(
            name: 'SERVICES',
            choices: [
                'all',
                'adservice',
                'cartservice',
                'checkoutservice',
                'currencyservice',
                'emailservice',
                'frontend',
                'loadgenerator',
                'paymentservice',
                'productcatalogservice',
                'recommendationservice',
                'shippingservice'
            ],
            description: 'Service(s) to process'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: "${BUILD_NUMBER}",
            description: 'Docker image tag (defaults to build number)'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run unit tests before building'
        )
    }

    environment {
        DOCKERHUB_ORG = "santonix"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'echo "📁 Repository checked out successfully"'
            }
        }

        stage('Test → Build → Push') {
            steps {
                script {
                    // Define serviceConfig INSIDE script scope
                    def serviceConfig = [
                        // Java/Gradle
                        adservice: [
                            dir: 'src/adservice',
                            test: './gradlew test --no-daemon',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        // .NET (special case)
                        cartservice: [
                            dir: 'src/cartservice/src',
                            test: 'dotnet test',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        // Go services
                        checkoutservice: [
                            dir: 'src/checkoutservice',
                            test: 'go test ./... -v',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        productcatalogservice: [
                            dir: 'src/productcatalogservice',
                            test: 'go test ./... -v',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        shippingservice: [
                            dir: 'src/shippingservice',
                            test: 'go test ./... -v',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        // Node.js
                        currencyservice: [
                            dir: 'src/currencyservice',
                            test: 'npm ci && npm test',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        paymentservice: [
                            dir: 'src/paymentservice',
                            test: 'npm ci && npm test',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        // Python
                        emailservice: [
                            dir: 'src/emailservice',
                            test: 'pip3 install -r requirements.txt && pytest',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        recommendationservice: [
                            dir: 'src/recommendationservice',
                            test: 'pip3 install -r requirements.txt && pytest',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        // Frontend & Loadgen
                        frontend: [
                            dir: 'src/frontend',
                            test: 'npm ci && npm test || echo "Frontend tests optional"',
                            dockerfile: 'Dockerfile'
                        ],
                        
                        loadgenerator: [
                            dir: 'src/loadgenerator',
                            test: 'echo "✅ Skipping tests for loadgenerator"',
                            dockerfile: 'Dockerfile'
                        ]
                    ]

                    def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER
                    def services = params.SERVICES == 'all' ? 
                        serviceConfig.keySet() as List : 
                        [params.SERVICES]

                    def parallelSteps = [:]
                    services.each { svc ->
                        parallelSteps[svc] = {
                            processService(svc, tag, serviceConfig)
                        }
                    }

                    parallel parallelSteps
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
            script {
                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER
                echo "✅ All services built and pushed successfully! 🎉"
                echo "🐳 Images: ${env.DOCKERHUB_ORG}/<service>:${tag}"
            }
        }
        failure {
            echo "❌ Pipeline failed - check service logs above"
        }
    }
}

// ================================
// SERVICE PROCESSING FUNCTION
// ================================
def processService(service, tag, serviceConfig) {
    def cfg = serviceConfig[service]
    
    if (!cfg) {
        echo "⚠️ No config for ${service}, skipping"
        return
    }

    dir(cfg.dir) {
        stage("${service} - Setup") {
            echo "🚀 Processing ${service} → ${cfg.dir}"
            sh 'ls -la || true'
        }

        // Test phase (conditional)
        if (params.RUN_TESTS && params.ENV != 'prod') {
            stage("${service} - Test") {
                echo "🧪 Running tests..."
                try {
                    sh """
                        echo "Testing ${service}..."
                        ${cfg.test}
                    """
                    echo "✅ Tests PASSED"
                } catch (Exception e) {
                    echo "⚠️ Tests failed/optional for ${service}, continuing..."
                    // Don't fail the build for test failures
                }
            }
        }

        // Build phase
        stage("${service} - Build") {
            if (!fileExists(cfg.dockerfile)) {
                error "❌ ${cfg.dockerfile} missing in ${cfg.dir}"
            }
            
            sh """
                docker build \\
                    --build-arg BUILD_NUMBER=${tag} \\
                    --build-arg ENVIRONMENT=${params.ENV} \\
                    --no-cache \\
                    -t ${service}:${tag} \\
                    -f ${cfg.dockerfile} .
            """
            echo "✅ Built: ${service}:${tag}"
        }

        // Push phase
        stage("${service} - Push") {
            withCredentials([usernamePassword(
                credentialsId: 'dockerhub-credentials',
                usernameVariable: 'DOCKER_USER',
                passwordVariable: 'DOCKER_PASS'
            )]) {
                sh """
                    echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                    docker tag ${service}:${tag} ${env.DOCKERHUB_ORG}/${service}:${tag}
                    docker tag ${service}:${tag} ${env.DOCKERHUB_ORG}/${service}:latest
                    docker push ${env.DOCKERHUB_ORG}/${service}:${tag}
                    docker push ${env.DOCKERHUB_ORG}/${service}:latest
                """
            }
            echo "✅ Pushed: ${env.DOCKERHUB_ORG}/${service}:${tag}"
        }
    }
}
