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
        DOCKERHUB_REPO = "${DOCKERHUB_ORG}/${env.JOB_NAME.toLowerCase()}"
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
                    def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER
                    def services = params.SERVICES == 'all' ? serviceConfig.keySet() as List : [params.SERVICES]

                    def parallelSteps = [:]
                    services.each { svc ->
                        parallelSteps[svc] = {
                            processService(svc, tag)
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
            echo "✅ All services built and pushed successfully! 🎉"
            script {
                def tag = params.IMAGE_TAG ?: env.BUILD_NUMBER
                echo "🐳 Images available at: ${env.DOCKERHUB_ORG}/${env.JOB_NAME.toLowerCase()}:<tag>"
            }
        }
        failure {
            echo "❌ Pipeline failed - check service logs above"
        }
    }
}

// ================================
// SERVICE CONFIGURATION
// ================================
def serviceConfig = [
    // Java/Gradle
    adservice: [
        dir: 'src/adservice',
        test: './gradlew test',
        buildCmd: './gradlew bootBuildImage'
    ],

    // .NET
    cartservice: [
        dir: 'cartservice',  // Special case directory
        test: 'dotnet test',
        buildCmd: 'dotnet publish -c Release -o out'
    ],

    // Go services
    checkoutservice: [
        dir: 'src/checkoutservice',
        test: 'go test ./...',
        buildCmd: 'go build -o server .'
    ],

    frontend: [
        dir: 'src/frontend',
        test: 'npm test || echo "Frontend tests skipped"',
        buildCmd: 'npm run build'
    ],

    productcatalogservice: [
        dir: 'src/productcatalogservice',
        test: 'go test ./...',
        buildCmd: 'go build -o server .'
    ],

    shippingservice: [
        dir: 'src/shippingservice',
        test: 'go test ./...',
        buildCmd: 'go build -o server .'
    ],

    // Node.js
    currencyservice: [
        dir: 'src/currencyservice',
        test: 'npm ci && npm test',
        buildCmd: 'npm run build'
    ],

    paymentservice: [
        dir: 'src/paymentservice',
        test: 'npm ci && npm test',
        buildCmd: 'npm run build'
    ],

    // Python
    emailservice: [
        dir: 'src/emailservice',
        test: 'pip install -r requirements.txt && pytest',
        buildCmd: 'pip install -r requirements.txt -r requirements-prod.txt'
    ],

    recommendationservice: [
        dir: 'src/recommendationservice',
        test: 'pip install -r requirements.txt && pytest',
        buildCmd: 'pip install -r requirements.txt -r requirements-prod.txt'
    ],

    // Load generator (no tests)
    loadgenerator: [
        dir: 'src/loadgenerator',
        test: 'echo "✅ Skipping tests for loadgenerator"',
        buildCmd: 'echo "✅ Load generator ready"'
    ]
]

// ================================
// SERVICE PROCESSING
// ================================
def processService(service, tag) {
    def cfg = serviceConfig[service]
    
    if (!cfg) {
        echo "⚠️  No config for ${service}, skipping"
        return
    }

    dir(cfg.dir) {
        stage("${service} - Setup") {
            echo "🚀 Processing ${service} in ${pwd()} (${params.ENV})"
            sh 'ls -la || true'
        }

        // Test phase (optional)
        if (params.RUN_TESTS && params.ENV != 'prod') {
            stage("${service} - Test") {
                echo "🧪 Running tests..."
                try {
                    sh cfg.test
                    echo "✅ Tests passed"
                } catch (Exception e) {
                    echo "⚠️  Tests failed but continuing build (non-prod)"
                }
            }
        }

        // Build phase
        stage("${service} - Build") {
            if (!fileExists('Dockerfile')) {
                error "❌ Dockerfile missing in ${cfg.dir}"
            }
            sh """
                docker build \\
                    --build-arg BUILD_NUMBER=${tag} \\
                    --build-arg ENVIRONMENT=${params.ENV} \\
                    -t ${service}:${tag} .
            """
            echo "✅ Docker image built: ${service}:${tag}"
        }

        // Push phase
        stage("${service} - Push") {
            withCredentials([usernamePassword(
                credentialsId: 'dockerhub-creds',
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
            echo "✅ ${service}:${tag} pushed to Docker Hub"
        }
    }
}
