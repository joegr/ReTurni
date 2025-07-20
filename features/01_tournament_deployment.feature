Feature: Tournament Deployment
  As an admin
  I want to deploy and manage tournaments
  So that I can organize competitive events with proper infrastructure

  Background:
    Given I am authenticated as an admin user
    And I have access to the tournament management dashboard

  Scenario: Deploy a new tournament
    Given I am on the tournament creation page
    When I fill in the tournament details:
      | Field           | Value                    |
      | Name            | "Spring Championship 2024" |
      | Start Date      | "2024-03-15"             |
      | End Date        | "2024-04-15"             |
      | Max Teams       | "32"                     |
      | Tournament Type | "Single Elimination"     |
    And I click "Deploy Tournament"
    Then the tournament should be created with status "Deploying"
    And Kubernetes pods should be provisioned for the tournament
    And the tournament should be accessible via the API gateway
    And I should receive a deployment confirmation email

  Scenario: Pause an active tournament
    Given there is an active tournament "Spring Championship 2024"
    When I navigate to the tournament management page
    And I click "Pause Tournament"
    Then the tournament status should change to "Paused"
    And all active matches should be suspended
    And players should see a "Tournament Paused" message
    And the tournament API should return status "paused"

  Scenario: Resume a paused tournament
    Given there is a paused tournament "Spring Championship 2024"
    When I navigate to the tournament management page
    And I click "Resume Tournament"
    Then the tournament status should change to "Active"
    And all suspended matches should resume
    And players should see the tournament as active again
    And the tournament API should return status "active"

  Scenario: Deploy tournament with custom configuration
    Given I am on the tournament creation page
    When I fill in the tournament details:
      | Field           | Value                    |
      | Name            | "Custom Tournament"      |
      | Start Date      | "2024-05-01"             |
      | End Date        | "2024-05-30"             |
      | Max Teams       | "16"                     |
      | Tournament Type | "Round Robin"            |
    And I set the following advanced options:
      | Option                    | Value     |
      | Enable ELO Rating System  | true      |
      | Hash Verification         | true      |
      | Human Review Required     | true      |
      | Auto Scaling Enabled      | true      |
    And I click "Deploy Tournament"
    Then the tournament should be created with all specified configurations
    And the ELO rating system should be initialized
    And result hashing should be enabled
    And human review workflow should be active 