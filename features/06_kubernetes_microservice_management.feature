Feature: Kubernetes Microservice Management
  As a system administrator
  I want to manage tournament microservices in Kubernetes
  So that I can ensure scalable and reliable tournament infrastructure

  Background:
    Given I have access to the Kubernetes cluster
    And the tournament microservices are deployed
    And I have kubectl configured with proper permissions

  Scenario: Deploy tournament microservices
    Given I have a tournament configuration file
    When I apply the Kubernetes deployment:
      | Service           | Replicas | CPU Request | Memory Request |
      | tournament-api    | 3        | 500m        | 1Gi            |
      | elo-service       | 2        | 200m        | 512Mi          |
      | leaderboard-svc   | 2        | 300m        | 768Mi          |
      | review-workflow   | 2        | 250m        | 512Mi          |
      | hash-verification | 2        | 200m        | 512Mi          |
    Then all services should be deployed successfully
    And the pods should be in "Running" state
    And the services should be accessible via internal DNS
    And health checks should pass for all endpoints

  Scenario: Auto-scale tournament services
    Given the tournament is experiencing high traffic
    When the CPU usage exceeds 70% for 5 minutes
    Then the HorizontalPodAutoscaler should scale up the services:
      | Service           | Min Replicas | Max Replicas | Target CPU |
      | tournament-api    | 3            | 10           | 70%        |
      | leaderboard-svc   | 2            | 8            | 70%        |
    And new pods should be created automatically
    And the load should be distributed across all pods
    And the scaling should be logged in the cluster events

  Scenario: Handle service failures and recovery
    Given a tournament service pod has failed
    When the pod enters "CrashLoopBackOff" state
    Then Kubernetes should automatically restart the pod
    And if the pod fails 3 times, it should be marked as failed
    And the service should continue operating with remaining pods
    And an alert should be sent to the operations team
    And the failed pod should be replaced with a new one

  Scenario: Update tournament service configuration
    Given I need to update the ELO service configuration
    When I apply a new ConfigMap with updated settings:
      | Setting           | Value |
      | K_FACTOR         | 40    |
      | INITIAL_ELO      | 1500  |
      | RATING_DECAY     | 0.95  |
    And I restart the elo-service deployment
    Then the new configuration should be applied
    And the service should restart with zero downtime
    And the new settings should be active immediately
    And the old configuration should be preserved as a backup

  Scenario: Monitor service health and metrics
    Given the tournament services are running
    When I check the service metrics
    Then I should see real-time data:
      | Metric           | Service           | Expected Range |
      | Response Time    | tournament-api    | < 200ms        |
      | Error Rate       | All services      | < 1%           |
      | CPU Usage        | All services      | < 80%          |
      | Memory Usage     | All services      | < 85%          |
    And the metrics should be available in Prometheus
    And Grafana dashboards should display the data

  Scenario: Backup and restore tournament data
    Given I need to backup tournament data
    When I trigger a backup operation
    Then the following data should be backed up:
      | Data Type        | Storage Location |
      | Match Results    | S3 Bucket        |
      | ELO Ratings      | Database Snapshot |
      | Leaderboards     | Database Snapshot |
      | Configuration    | Git Repository   |
    And the backup should be encrypted
    And the backup should be verified for integrity
    And I should be able to restore from any backup point

  Scenario: Network policy enforcement
    Given the tournament services are deployed
    When I apply network policies
    Then the services should only communicate as defined:
      | From Service     | To Service       | Protocol | Port |
      | tournament-api   | elo-service      | HTTP     | 8080 |
      | tournament-api   | leaderboard-svc  | HTTP     | 8080 |
      | review-workflow  | hash-verification| HTTP     | 8080 |
    And unauthorized network access should be blocked
    And all network traffic should be logged
    And the policies should be enforced at the pod level

  Scenario: Resource quota management
    Given I have set resource quotas for the tournament namespace
    When the tournament services consume resources
    Then the following limits should be enforced:
      | Resource Type    | Limit per Namespace |
      | CPU             | 8 cores             |
      | Memory          | 16Gi                |
      | Storage         | 100Gi               |
      | Pods            | 50                  |
    And if limits are exceeded, new deployments should be rejected
    And resource usage should be monitored and reported 