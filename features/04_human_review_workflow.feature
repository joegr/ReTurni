Feature: Human Review Workflow
  As a tournament manager
  I want to review and approve match results
  So that I can ensure accuracy and handle disputes

  Background:
    Given I am authenticated as a tournament manager
    And the human review workflow is enabled
    And I have access to the review dashboard

  Scenario: Submit result for human review
    Given a match between "Alpha Squad" and "Beta Warriors" has completed
    When the match result is submitted:
      | Field           | Value                    |
      | Winner          | "Alpha Squad"            |
      | Loser           | "Beta Warriors"          |
      | Score           | "3-1"                    |
      | Timestamp       | "2024-03-15T14:30:00Z"   |
    Then the result should be marked as "Pending Review"
    And the result should appear in the manager's review queue
    And the result should be hashed for integrity verification
    And an email notification should be sent to the manager

  Scenario: Approve a match result
    Given there is a pending result in the review queue
    When I review the match details:
      | Field           | Value                    |
      | Winner          | "Alpha Squad"            |
      | Loser           | "Beta Warriors"          |
      | Score           | "3-1"                    |
      | Submitted By    | "Referee John Smith"     |
    And I click "Approve Result"
    Then the result status should change to "Approved"
    And the ELO ratings should be updated
    And the leaderboard should be refreshed
    And the result should be marked as verified with timestamp
    And a notification should be sent to both teams

  Scenario: Reject a match result
    Given there is a pending result in the review queue
    When I review the match details and find discrepancies
    And I click "Reject Result"
    And I provide a rejection reason "Score discrepancy reported by Beta Warriors"
    Then the result status should change to "Rejected"
    And the rejection reason should be recorded
    And the result should be returned to the submitter for correction
    And both teams should be notified of the rejection
    And the ELO ratings should remain unchanged

  Scenario: Request additional information
    Given there is a pending result in the review queue
    When I review the match details and need more information
    And I click "Request More Info"
    And I specify the required information "Please provide game-by-game scores"
    Then the result should remain in "Pending Review" status
    And a request for additional information should be sent
    And the submitter should be able to provide the requested information
    And the result should be updated with the new information

  Scenario: Handle disputed results
    Given there is a disputed match result
    When "Beta Warriors" submits a dispute with evidence
    And the dispute is reviewed by the manager
    And the manager determines the dispute is valid
    Then the original result should be marked as "Disputed"
    And a new review process should be initiated
    And both teams should be notified of the dispute resolution
    And the final approved result should reflect the correct outcome

  Scenario: Batch review multiple results
    Given there are multiple pending results in the review queue
    When I select multiple results for batch review
    And I approve all selected results
    Then all selected results should be approved simultaneously
    And ELO ratings should be updated for all approved results
    And the leaderboard should be refreshed once
    And batch processing should be more efficient than individual reviews

  Scenario: Review result with video evidence
    Given there is a pending result with video evidence attached
    When I review the match video
    And I can see the actual gameplay and scoring
    And I approve the result based on video evidence
    Then the video evidence should be linked to the approved result
    And the video should be archived for future reference
    And the approval should include a note about video verification 