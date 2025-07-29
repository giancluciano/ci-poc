pipeline {
    agent {
        kubernetes {
            yaml """
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: docker
                    image: docker:latest
                    command:
                    - sleep
                    args:
                    - 99d
                    volumeMounts:
                    - mountPath: /var/run/docker.sock
                      name: docker-sock
                  - name: kubectl-helm
                    image: alpine/helm:3.12.1
                    command:
                    - sleep
                    args:
                    - 99d
                  volumes:
                  - name: docker-sock
                    hostPath:
                      path: /var/run/docker.sock
            """
        }
    }
    
    environment {
        IMAGE_NAME = 'flask-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        HELM_RELEASE_NAME = 'flask-app'
        NAMESPACE = 'default'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    script {
                        // Configure Docker to use Minikube's Docker daemon
                        sh '''
                            echo "Building Docker image..."
                            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                            
                            # List images to verify
                            docker images | grep ${IMAGE_NAME}
                        '''
                    }
                }
            }
        }
        
        stage('Test Application') {
            steps {
                container('docker') {
                    script {
                        sh '''
                            echo "Running basic container test..."
                            docker run --rm -d --name flask-test -p 5000:5000 ${IMAGE_NAME}:${IMAGE_TAG}
                            sleep 10
                            
                            # Test if container is running
                            if docker ps | grep flask-test; then
                                echo "Container is running successfully"
                                docker stop flask-test
                            else
                                echo "Container failed to start"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                container('kubectl-helm') {
                    script {
                        sh '''
                            echo "Deploying with Helm..."
                            
                            # Check if release exists
                            if helm list -n ${NAMESPACE} | grep ${HELM_RELEASE_NAME}; then
                                echo "Upgrading existing release..."
                                helm upgrade ${HELM_RELEASE_NAME} ./helm-chart \
                                    --namespace ${NAMESPACE} \
                                    --set image.tag=${IMAGE_TAG} \
                                    --set env.APP_VERSION=${IMAGE_TAG} \
                                    --wait --timeout=300s
                            else
                                echo "Installing new release..."
                                helm install ${HELM_RELEASE_NAME} ./helm-chart \
                                    --namespace ${NAMESPACE} \
                                    --set image.tag=${IMAGE_TAG} \
                                    --set env.APP_VERSION=${IMAGE_TAG} \
                                    --wait --timeout=300s
                            fi
                            
                            # Verify deployment
                            kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=flask-app
                            kubectl get svc -n ${NAMESPACE} -l app.kubernetes.io/name=flask-app
                        '''
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('kubectl-helm') {
                    script {
                        sh '''
                            echo "Verifying deployment..."
                            
                            # Wait for pods to be ready
                            kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flask-app -n ${NAMESPACE} --timeout=300s
                            
                            # Get service URL
                            echo "Application should be accessible at:"
                            kubectl get svc ${HELM_RELEASE_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}'
                            echo ""
                            
                            # Show deployment status
                            helm status ${HELM_RELEASE_NAME} -n ${NAMESPACE}
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed!'
        }
        success {
            echo 'Deployment successful! 🎉'
            echo 'Access your app at: http://$(minikube ip):30080'
        }
        failure {
            echo 'Pipeline failed! Check the logs above.'
        }
    }
}