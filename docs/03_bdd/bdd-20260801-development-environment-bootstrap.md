---
title: "Development Environment Bootstrap Behavior"
doc_type: "bdd"
status: "review"
owner: "coding-agent"
source: "chat"
created: "2026-08-01"
updated: "2026-08-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Development Environment Bootstrap Behavior

Feature: Reproducible local development environment
  SpritesPlayground must verify and repair its pinned local toolchain without unnecessary downloads.

  Background:
    Given Godot is pinned to `4.7.stable.official.5b4e0cb0f`
    And LimboAI is pinned to `1.8.0`
    And Godot AI is pinned to `3.0.7`
    And third-party add-on trees are ignored by Git

  Scenario: Healthy components are skipped
    Given all pinned components are healthy
    When the developer runs `python3 scripts/bootstrap_dev.py`
    Then each component is checked before installation
    And no release archive is downloaded or read
    And the bootstrap reports that the environment is ready

  Scenario: Check mode is read-only
    Given one or more components are missing or damaged
    When the developer runs `python3 scripts/bootstrap_dev.py --check`
    Then the command exits unsuccessfully
    And every evaluated failure is reported
    And no component is installed or modified

  Scenario: A damaged add-on is repaired
    Given an installed add-on fails its version or integrity check
    When the developer runs the default bootstrap
    Then the pinned release archive is obtained or reused
    And its SHA-256 digest is verified
    And the damaged add-on is replaced with a clean pinned installation

  Scenario: Repair can be forced
    Given an add-on appears healthy
    When the developer runs `python3 scripts/bootstrap_dev.py --repair`
    Then the add-on is reinstalled from its pinned archive

  Scenario: Godot version differs from the pin
    Given `godot --version` does not equal `4.7.stable.official.5b4e0cb0f`
    When bootstrap verification runs
    Then the command fails
    And the diagnostic includes the expected and actual versions

  Scenario: Godot AI remains development-only
    Given Godot AI 3.0.7 is installed
    When its health check runs
    Then the registered export plugin is present
    And the plugin removes `autoload/_mcp_game_helper` from exported settings

  Scenario: Healthy Pi packages are not reinstalled
    Given every package in `dependencies/pi_packages.lock.json` is installed at its pinned version or commit
    When the developer runs the default bootstrap
    Then each package is reported ready
    And `pi install` is not invoked

  Scenario: A missing Pi package is installed declaratively
    Given one pinned Pi package is missing
    When the developer runs the default bootstrap
    Then `pi install` is invoked only for that package's pinned source
    And third-party package files are not copied into the repository

  Scenario: Safe agent configuration is synchronized
    Given the project contains agent instructions and subagent model routing
    When the repository is cloned
    Then `AGENTS.md`, `.pi/settings.json`, and project-owned skills are available from Git
    But authentication, tokens, sessions, caches, and third-party package trees remain machine-local
