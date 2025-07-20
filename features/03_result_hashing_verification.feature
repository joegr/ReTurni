Feature: Result Hashing and Verification
  As a tournament system
  I want to hash and verify match results
  So that I can ensure data integrity and prevent tampering

  Background:
    Given the result hashing system is enabled
    And the system uses SHA-256 for hashing
    And all results include timestamps

  Scenario: Hash match result with timestamp
    Given a match between "Alpha Squad" and "Beta Warriors"
    When the match result is submitted:
      | Field           | Value                    |
      | Winner          | "Alpha Squad"            |
      | Loser           | "Beta Warriors"          |
      | Score           | "3-1"                    |
      | Timestamp       | "2024-03-15T14:30:00Z"   |
      | Tournament ID   | "spring-2024-001"        |
    Then the system should generate a hash of the result data
    And the hash should include the timestamp
    And the hash should be stored in the result record
    And the hash should be immutable once created

  Scenario: Verify result integrity using hash
    Given a match result with hash "abc123def456..."
    When I attempt to retrieve the match result
    Then the system should recalculate the hash from the stored data
    And the calculated hash should match the stored hash
    And if the hashes don't match, the system should flag the result as compromised

  Scenario: Detect tampering in result data
    Given a match result with hash "abc123def456..."
    When someone attempts to modify the score from "3-1" to "2-1"
    And the result is retrieved for verification
    Then the recalculated hash should not match the original hash
    And the system should mark the result as "TAMPERED"
    And an alert should be sent to tournament administrators
    And the original result should be preserved in an audit log

  Scenario: Hash verification with multiple data points
    Given a complex match result with multiple data points:
      | Field           | Value                    |
      | Winner          | "Alpha Squad"            |
      | Loser           | "Beta Warriors"          |
      | Score           | "3-1"                    |
      | Game Scores     | ["25-20", "25-18", "20-25", "25-22"] |
      | Duration        | "2h 15m"                 |
      | Timestamp       | "2024-03-15T14:30:00Z"   |
      | Referee         | "John Smith"             |
      | Tournament ID   | "spring-2024-001"        |
    When the result is submitted
    Then all data points should be included in the hash calculation
    And the hash should be unique to this specific result
    And any change to any field should result in a different hash

  Scenario: Handle hash verification in batch operations
    Given multiple match results are submitted in a batch
    When the batch is processed
    Then each result should be individually hashed
    And each hash should be verified independently
    And if any result fails verification, only that result should be flagged
    And the other results should be processed normally

  Scenario: Hash verification with human review workflow
    Given a match result is submitted with hash "abc123def456..."
    When a human reviewer approves the result
    And the approval timestamp is "2024-03-15T15:00:00Z"
    Then the approval should be added to the result record
    And a new hash should be generated including the approval data
    And both the original and approval hashes should be preserved 